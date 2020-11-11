// SPDX-License-Identifier: GPL-2.0

/*
 * Amazon Nitro Secure Module driver.
 *
 * Copyright 2019-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms and conditions of the GNU General Public License,
 * version 2, as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 */

#include <linux/file.h>
#include <linux/fs.h>
#include <linux/interrupt.h>
#include <linux/miscdevice.h>
#include <linux/module.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/uaccess.h>
#include <linux/uio.h>
#include <linux/virtio.h>
#include <linux/virtio_config.h>
#include <linux/wait.h>

/* Register this as a misc driver */
#define NSM_DEV_MINOR         147
#define NSM_DEV_NAME          "nsm"
#define NSM_DEV_DATA_OFFSET   0x100
#define NSM_IOCTL_MAGIC       0x0A
#define NSM_IO_REQUEST        _IOWR(NSM_IOCTL_MAGIC, 0, struct nsm_message)
#define NSM_REQUEST_MAX_SIZE  0x1000
#define NSM_RESPONSE_MAX_SIZE 0x3000

/* Timeout for NSM virtqueue respose in milliseconds. */
#define NSM_DEFAULT_TIMEOUT_MSECS (120000) /* 2 minutes */

/* The name of the NSM device virtqueue */
const char *NSM_VQ_NAME = "nsm.vq.0";

/* NSM device ID */
static const struct virtio_device_id nsm_id_table[] = {
	{ 33, VIRTIO_DEV_ANY_ID },
	{ 0 },
};

/* NSM message from user-space */
struct nsm_message {
	/* Request from user */
	struct iovec request;
	/* Response to user */
	struct iovec response;
};

/* Copy of NSM message in kernel-space */
struct nsm_kernel_message {
	/* Copy of user request in kernel memory */
	struct kvec request;
	/* Copy of user response in kernel memory */
	struct kvec response;
};

/* Virtio MMIO device definition */
struct virtio_mmio_device {
	struct virtio_device vdev;
	struct platform_device *pdev;

	void __iomem *base;
	unsigned long version;

	/* a list of queues so we can dispatch IRQs */
	spinlock_t lock;
	struct list_head virtqueues;
};

/* Virtqueue list entry */
struct virtio_mmio_vq_info {
	/* The actual virtqueue */
	struct virtqueue *vq;

	/* The list node for the virtqueues list */
	struct list_head node;
};

static struct virtio_device *nsm_dev;
static struct mutex nsm_lock;
static wait_queue_head_t nsm_waitqueue;
static bool nsm_device_notified;

/* Get the virtqueue */
static struct virtqueue *nsm_get_vq(struct virtio_device *vdev)
{
	struct virtio_mmio_device *vm_dev =
		container_of(vdev, struct virtio_mmio_device, vdev);
	struct virtio_mmio_vq_info *info;

	list_for_each_entry(info, &vm_dev->virtqueues, node)
		return info->vq;

	return NULL;
}

/* Copy an entire message from user-space to kernel-space */
static int message_copy_from_user(struct nsm_kernel_message *dst,
	struct nsm_message *src)
{
	struct nsm_message shallow_copy;

	if (!src || !dst)
		return -EINVAL;

	/* The destination's request and response buffers should be NULL. */
	if (dst->request.iov_base || dst->response.iov_base)
		return -EINVAL;

	/* First, make a shallow copy to be able to read the inner pointers */
	if (copy_from_user(&shallow_copy, src, sizeof(shallow_copy)) != 0)
		return -EINVAL;

	/* Verify the user input size. */
	if (shallow_copy.request.iov_len > NSM_REQUEST_MAX_SIZE)
		return -EMSGSIZE;

	/* Allocate kernel memory for the user request */
	dst->request.iov_len = shallow_copy.request.iov_len;
	dst->request.iov_base = kmalloc(dst->request.iov_len, GFP_KERNEL);
	if (!dst->request.iov_base)
		return -ENOMEM;

	/* Copy the request content */
	if (copy_from_user(dst->request.iov_base,
		shallow_copy.request.iov_base, dst->request.iov_len) != 0) {
		kfree(dst->request.iov_base);
		return -EFAULT;
	}

	/* Allocate kernel memory for the response, up to a fixed limit */
	dst->response.iov_len = shallow_copy.response.iov_len;
	if (dst->response.iov_len > NSM_RESPONSE_MAX_SIZE)
		dst->response.iov_len = NSM_RESPONSE_MAX_SIZE;

	dst->response.iov_base = kmalloc(dst->response.iov_len, GFP_KERNEL);
	if (!dst->response.iov_base) {
		kfree(dst->request.iov_base);
		return -ENOMEM;
	}

	return 0;
}

/* Copy a message back to user-space */
static int message_copy_to_user(struct nsm_message *user_msg,
	struct nsm_kernel_message *kern_msg)
{
	struct nsm_message shallow_copy;

	if (!kern_msg || !user_msg)
		return -EINVAL;

	/*
	 * First, do a shallow copy of the user-space message. This is needed in
	 * order to get the request block data, which we do not need to copy but
	 * must preserve in the message sent back to user-space.
	 */
	if (copy_from_user(&shallow_copy, user_msg, sizeof(shallow_copy)) != 0)
		return -EINVAL;

	/* Do not exceed the capacity of the user-provided response buffer */
	shallow_copy.response.iov_len = kern_msg->response.iov_len;

	/* Only the response content must be copied back to user-space */
	if (copy_to_user(shallow_copy.response.iov_base,
		kern_msg->response.iov_base,
		shallow_copy.response.iov_len) != 0)
		return -EINVAL;

	if (copy_to_user(user_msg, &shallow_copy, sizeof(shallow_copy)) != 0)
		return -EFAULT;

	return 0;
}

/* Delete a message stored in kernel-space */
static void message_delete(struct nsm_kernel_message *message)
{
	if (!message)
		return;

	kfree(message->request.iov_base);
	kfree(message->response.iov_base);
	message->request.iov_base = message->response.iov_base = NULL;
}

/* Virtqueue interrupt handler */
static void nsm_vq_callback(struct virtqueue *vq)
{
	/* TODO: Handle spurious callbacks. */
	nsm_device_notified = true;
	wake_up(&nsm_waitqueue);
}

/* Forward a message to the NSM device and wait for the response from it */
static int nsm_communicate_with_device(struct nsm_kernel_message *message)
{
	struct virtqueue *vq = NULL;
	struct scatterlist sg_in, sg_out;
	unsigned int len;
	void *queue_buf;
	bool kicked;
	int rc;

	if (!message)
		return -EINVAL;

	if (!nsm_dev)
		return -ENXIO;

	vq = nsm_get_vq(nsm_dev);
	if (!vq)
		return -ENXIO;

	/* Verify if buffer memory is valid. */
	if (!virt_addr_valid(message->request.iov_base) ||
		!virt_addr_valid(((u8 *)message->request.iov_base) +
			message->request.iov_len - 1) ||
		!virt_addr_valid(message->response.iov_base) ||
		!virt_addr_valid(((u8 *)message->response.iov_base) +
			message->response.iov_len - 1))
		return -EINVAL;

	/* Initialize scatter-gather lists with request and response buffers. */
	sg_init_one(&sg_out, message->request.iov_base,
		message->request.iov_len);
	sg_init_one(&sg_in, message->response.iov_base,
		message->response.iov_len);

	/* Add the request buffer (read by the device). */
	rc = virtqueue_add_outbuf(vq, &sg_out, 1, message->request.iov_base,
		GFP_KERNEL);
	if (rc)
		return rc;

	/* Add the response buffer (written by the device). */
	rc = virtqueue_add_inbuf(vq, &sg_in, 1, message->response.iov_base,
		GFP_KERNEL);
	if (rc)
		goto cleanup;

	nsm_device_notified = false;
	kicked = virtqueue_kick(vq);
	if (!kicked) {
		/* Cannot kick the virtqueue. */
		rc = -EIO;
		goto cleanup;
	}

	/* If the kick succeeded, wait for the device's response. */
	rc = wait_event_timeout(nsm_waitqueue,
		nsm_device_notified == true,
		msecs_to_jiffies(NSM_DEFAULT_TIMEOUT_MSECS));
	if (!rc) {
		rc = -ETIMEDOUT;
		goto cleanup;
	}

	queue_buf = virtqueue_get_buf(vq, &len);
	if (!queue_buf || (queue_buf != message->request.iov_base)) {
		pr_err("NSM device received wrong request buffer.");
		rc = -ENODATA;
		goto cleanup;
	}

	queue_buf = virtqueue_get_buf(vq, &len);
	if (!queue_buf || (queue_buf != message->response.iov_base)) {
		pr_err("NSM device received wrong response buffer.");
		rc = -ENODATA;
		goto cleanup;
	}

	/* Make sure the response length doesn't exceed the buffer capacity. */
	if (len < message->response.iov_len)
		message->response.iov_len = len;

	return 0;

cleanup:
	/* Clean the virtqueue. */
	while (virtqueue_get_buf(vq, &len) != NULL)
		;

	return rc;
}

static long nsm_dev_ioctl(struct file *file, unsigned int cmd,
	unsigned long arg)
{
	struct nsm_kernel_message message;
	int status = 0;

	if (cmd != NSM_IO_REQUEST)
		return -EINVAL;

	/* The kernel message structure must be cleared */
	memset(&message, 0, sizeof(message));

	/* Copy the message from user-space to kernel-space */
	status = message_copy_from_user(&message, (struct nsm_message *)arg);
	if (status != 0)
		return status;

	/* Communicate with the NSM device */
	mutex_lock(&nsm_lock);
	status = nsm_communicate_with_device(&message);
	mutex_unlock(&nsm_lock);

	if (status != 0) {
		message_delete(&message);
		return status;
	}

	/* Copy the response back to user-space */
	status = message_copy_to_user((struct nsm_message *)arg, &message);

	/* At this point, everything succeeded, so clean up and finish. */
	message_delete(&message);

	return status;
}

static int nsm_dev_file_open(struct inode *node, struct file *file)
{
	pr_debug("NSM device file opened.\n");
	return 0;
}

static int nsm_dev_file_close(struct inode *inode, struct file *file)
{
	pr_debug("NSM device file closed.\n");
	return 0;
}

static int nsm_device_init_vq(struct virtio_device *vdev)
{
	struct virtqueue *vq = virtio_find_single_vq(vdev,
		nsm_vq_callback, NSM_VQ_NAME);
	if (IS_ERR(vq))
		return PTR_ERR(vq);

	return 0;
}

/* Update the current NSM device to a new one */
static int nsm_device_update(struct virtio_device *vdev)
{
	int rc;

	/* Do nothing if the device does not change. */
	if (nsm_dev == vdev)
		return 0;

	/* Clear the old device, if any. */
	if (nsm_dev) {
		nsm_dev->config->del_vqs(vdev);
		nsm_dev = NULL;
	}

	/* Initialize the new device, if any. */
	if (vdev) {
		rc = nsm_device_init_vq(vdev);
		if (rc) {
			pr_err("NSM device queue failed to initialize: %d.\n", rc);
			return rc;
		}

		nsm_dev = vdev;
	}

	return 0;
}

/* Handler for probing the NSM device */
static int nsm_device_probe(struct virtio_device *vdev)
{
	int rc = nsm_device_update(vdev);

	if (rc) {
		pr_err("NSM device probing failed: %d.", rc);
		return rc;
	}

	pr_debug("NSM device has been probed.\n");
	return 0;
}

/* Handler for removing the NSM device */
static void nsm_device_remove(struct virtio_device *vdev)
{
	int rc;

	if (vdev != nsm_dev) {
		pr_err("Invalid NSM device to remove.\n");
		return;
	}

	rc = nsm_device_update(NULL);
	if (rc)
		pr_err("NSM device could not be removed: %d.", rc);
	else
		pr_debug("NSM device has been removed.\n");
}

/* Handler for changing the configuration of the NSM device */
static void nsm_device_cfg_changed(struct virtio_device *vdev)
{
	int rc = nsm_device_update(vdev);

	if (rc)
		pr_err("NSM device configuration change failed: %d.\n", rc);
	else
		pr_debug("NSM device configuration has been changed.\n");
}

/* NSM device configuration structure */
static struct virtio_driver virtio_nsm_driver = {
	.feature_table             = 0,
	.feature_table_size        = 0,
	.feature_table_legacy      = 0,
	.feature_table_size_legacy = 0,
	.driver.name               = KBUILD_MODNAME,
	.driver.owner              = THIS_MODULE,
	.id_table                  = nsm_id_table,
	.probe                     = nsm_device_probe,
	.remove                    = nsm_device_remove,
	.config_changed            = nsm_device_cfg_changed
};

/* Supported driver operations */
static const struct file_operations nsm_dev_fops = {
	.open = nsm_dev_file_open,
	.release = nsm_dev_file_close,
	.unlocked_ioctl = nsm_dev_ioctl,
};

/* Driver configuration */
static struct miscdevice nsm_driver_miscdevice = {
	.minor	= NSM_DEV_MINOR,
	.name	= NSM_DEV_NAME,
	.fops	= &nsm_dev_fops,
	.mode	= 0666
};

static int __init nsm_driver_init(void)
{
	int rc;

	mutex_init(&nsm_lock);
	init_waitqueue_head(&nsm_waitqueue);

	rc = misc_register(&nsm_driver_miscdevice);

	if (rc)
		pr_err("NSM driver initialization error: %d.\n", rc);
	else
		pr_debug("NSM driver version = 10.%d.\n",
			NSM_DEV_MINOR);

	nsm_dev = NULL;
	rc = register_virtio_driver(&virtio_nsm_driver);
	if (rc) {
		pr_err("NSM device initialization error: %d.\n", rc);
		misc_deregister(&nsm_driver_miscdevice);
	} else
		pr_debug("NSM device ID = %X.\n",
			virtio_nsm_driver.id_table[0].device);

	return rc;
}

static void __exit nsm_driver_exit(void)
{
	unregister_virtio_driver(&virtio_nsm_driver);
	misc_deregister(&nsm_driver_miscdevice);
	mutex_destroy(&nsm_lock);
	pr_debug("NSM driver exited.\n");
}

module_init(nsm_driver_init);
module_exit(nsm_driver_exit);

MODULE_DEVICE_TABLE(virtio, nsm_id_table);
MODULE_DESCRIPTION("Virtio NSM driver");
MODULE_LICENSE("GPL");

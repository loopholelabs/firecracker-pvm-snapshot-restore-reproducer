#!/bin/bash

OUT_DIR="blueprint"
PACKAGE_DIR="out/package"

KERNEL_IMAGE="vmlinux"
ROOTFS_IMAGE="rootfs.ext4"
MEMORY_FILE="memory.bin"
STATE_FILE="state.bin"

FIRECRACKER_BINARY="./firecracker"
FIRECRACKER_SOCKET="firecracker.socket"

start_firecracker() {
    echo "Starting Firecracker API server..."

    rm -f ${FIRECRACKER_SOCKET}

    ${FIRECRACKER_BINARY} --api-sock ${FIRECRACKER_SOCKET}
}

stop_firecracker() {
    echo "Stopping Firecracker API server..."

    pkill -f -9 ${FIRECRACKER_BINARY}
    rm -f ${FIRECRACKER_SOCKET}
}

create_snapshot() {
    echo "Creating a snapshot..."

    mkdir -p ${PACKAGE_DIR}

    rm -f vsock.sock

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/boot-source" \
        -H "Content-Type: application/json" \
        -d "{\"kernel_image_path\":\"${OUT_DIR}/${KERNEL_IMAGE}\",\"boot_args\":\"console=ttyS0 panic=1 pci=off modules=ext4 rootfstype=ext4 root=/dev/vda i8042.noaux i8042.nomux i8042.nopnp i8042.dumbkbd rootflags=rw printk.devkmsg=on printk_ratelimit=0 printk_ratelimit_burst=0\"}"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/drives/disk" \
        -H "Content-Type: application/json" \
        -d "{\"drive_id\":\"disk\",\"path_on_host\":\"${OUT_DIR}/${ROOTFS_IMAGE}\",\"is_root_device\":false,\"is_read_only\":false}"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/machine-config" \
        -H "Content-Type: application/json" \
        -d "{\"vcpu_count\":1,\"mem_size_mib\":1024,\"cpu_template\":\"None\"}"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/vsock" \
        -H "Content-Type: application/json" \
        -d "{\"guest_cid\":3,\"uds_path\":\"vsock.sock\"}"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/actions" \
        -H "Content-Type: application/json" \
        -d "{\"action_type\":\"InstanceStart\"}"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PATCH "http://localhost/vm" \
        -H "Content-Type: application/json" \
        -d "{\"state\":\"Paused\"}"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/snapshot/create" \
        -H "Content-Type: application/json" \
        -d "{\"snapshot_type\":\"Full\",\"snapshot_path\":\"${PACKAGE_DIR}/${STATE_FILE}\",\"mem_file_path\":\"${PACKAGE_DIR}/${MEMORY_FILE}\"}"

    echo "Snapshot created successfully."
}

resume_vm() {
    echo "Resuming VM from snapshot..."

    rm -f vsock.sock

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/snapshot/load" \
        -H "Content-Type: application/json" \
        -d "{\"snapshot_path\":\"${PACKAGE_DIR}/${STATE_FILE}\",\"mem_backend\":{\"backend_path\":\"${PACKAGE_DIR}/${MEMORY_FILE}\",\"backend_type\":\"File\"},\"enable_diff_snapshots\":false,\"resume_vm\":true}"

    echo "VM resumed successfully."
}

suspend_vm() {
    echo "Suspending VM..."

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PATCH "http://localhost/vm" \
        -H "Content-Type: application/json" \
        -d "{\"state\":\"Paused\"}"

    MEM_FILE_PATH="${PACKAGE_DIR}/memory.bin"
    STATE_FILE_PATH="${PACKAGE_DIR}/state.bin"

    curl --unix-socket ${FIRECRACKER_SOCKET} -X PUT "http://localhost/snapshot/create" \
        -H "Content-Type: application/json" \
        -d "{\"snapshot_type\":\"Full\",\"snapshot_path\":\"${STATE_FILE_PATH}\",\"mem_file_path\":\"${MEM_FILE_PATH}\"}"

    echo "VM suspended and snapshot created successfully."
}

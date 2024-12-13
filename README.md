# Firecracker PVM Snapshot/Restore Reproducer

This repository contains reproduction steups for setting up [Firecracker](https://github.com/loopholelabs/firecracker) and the [PVM](https://github.com/loopholelabs/linux-pvm-ci) Linux Kernel module to run a VM.

## General Steps

### Setup PVM

You must be using a RHEL-based OS (like Fedora) to install a pre-build linux kernel:

```bash
dnf config-manager --add-repo 'https://loopholelabs.github.io/linux-pvm-ci/fedora/baremetal/repodata/linux-pvm-ci.repo' # Or, if you're on Fedora Linux 41+, use `sudo dnf config-manager addrepo --from-repofile 'https://loopholelabs.github.io/linux-pvm-ci/fedora/baremetal/repodata/linux-pvm-ci.repo'`
sudo dnf install -y kernel-6.7.12_pvm_host_fedora_baremetal-1.x86_64
```

Next, setup the installed kernel to be used in future boots:

```bash
sudo grubby --set-default /boot/vmlinuz-6.7.12-pvm-host-fedora-baremetal
sudo grubby --copy-default --args="pti=off nokaslr lapic=notscdeadline" --update-kernel /boot/vmlinuz-6.7.12-pvm-host-fedora-baremetal
sudo dracut --force --kver 6.7.12-pvm-host-fedora-baremetal
```

And make sure any existing KVM modules do not get loaded:

```bash
sudo tee /etc/modprobe.d/kvm-intel-amd-blacklist.conf <<EOF
blacklist kvm-intel
blacklist kvm-amd
EOF
echo "kvm-pvm" | sudo tee /etc/modules-load.d/kvm-pvm.conf
```

Finally, reboot:

```bash
sudo reboot
```

And make sure the new kernel is being used:

```bash
lsmod | grep pvm # Check if PVM is available
```

If you'd like to build the kernel from source, you can do so as follows:

```bash
git clone https://github.com/loopholelabs/linux-pvm-ci
cd linux-pvm-ci

make clone
make "copy/fedora/baremetal"
make "patch/fedora/baremetal"
make "configure/fedora/baremetal"

make -j$(nproc) "build/fedora/baremetal"
```

### Setup Firecracker

On a host with KVM available (via PVM or otherwise) you can now run Firecracker:

```bash
git clone https://github.com/loopholelabs/firecracker-pvm-snapshot-restore-reproducer
cd firecracker-pvm-snapshot-restore-reproducer

tar --zstd -xvf ./assets.tar.zst
```

Now, start the firecracker process:

```shell
# Terminal 1
source ./control.sh
start_firecracker
```

Next, create a VM and snapshot it:
# Terminal 2
source ./control.sh
create_snapshot
stop_firecracker
```

Now, attempt to resume the snapshot you just created:

```shell
# Terminal 1
start_firecracker

# Terminal 2
resume_vm
```

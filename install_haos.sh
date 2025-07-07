#!/bin/bash

# ================================================================
# Home Assistant OS auto-install script for Proxmox VE (with EFI disk)
# Author: ChatGPT (for Elton)
# Description:
#   - Create an empty VM with custom VMID
#   - Download HAOS image and import disk
#   - Add EFI disk (efidisk0)
#   - Configure hardware and boot order
#   - Stop and cleanup on any error
#   - Overwrite existing downloaded files if present
# ================================================================

set -e  # Stop script on any error

PCT=$(which pct)
QM=$(which qm)

if [ -z "$PCT" ] || [ -z "$QM" ]; then
    echo "❌ This script must be run on the Proxmox host (not inside a container or VM)."
    exit 1
fi

while true; do
    read -p "Please enter your desired VMID (e.g., 105): " VMID
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        echo "⚠️ VMID must be a number."
        continue
    fi
    if qm status $VMID &>/dev/null; then
        echo "⚠️ VMID $VMID already exists in Proxmox. Please choose another."
    else
        echo "✅ VMID $VMID is available."
        break
    fi
done

VM_NAME="HomeAssistantOS"
CPU_SOCKETS=1
CPU_CORES=4
MEMORY=8192

cleanup() {
    echo "⚠️ Error occurred. Cleaning up..."
    if qm status $VMID &>/dev/null; then
        echo "Removing VM $VMID..."
        qm destroy $VMID --purge || true
    fi
    rm -f /tmp/haos_ova-15.2.qcow2 /tmp/haos_ova-15.2.raw /tmp/haos_ova-15.2.qcow2.xz
    exit 1
}

trap cleanup ERR

echo "🚀 Creating VM $VMID ($VM_NAME)..."
qm create $VMID --name $VM_NAME --memory $MEMORY --sockets $CPU_SOCKETS --cores $CPU_CORES --cpu host --bios ovmf --ostype l26 --scsihw virtio-scsi-pci --net0 virtio,bridge=vmbr0

echo "➕ Adding EFI disk..."
qm set $VMID --efidisk0 local-lvm:0,efitype=4m,format=raw

echo "🌐 Downloading Home Assistant OS image..."
cd /tmp
rm -f haos_ova-15.2.qcow2.xz haos_ova-15.2.qcow2 haos_ova-15.2.raw
wget -O haos_ova-15.2.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz

echo "📦 Extracting image..."
unxz haos_ova-15.2.qcow2.xz

echo "🔄 Converting qcow2 to raw..."
qemu-img convert -f qcow2 -O raw haos_ova-15.2.qcow2 haos_ova-15.2.raw

STORAGE="local-lvm"
if ! pvesm status | grep -q $STORAGE; then
    STORAGE=$(pvesm status | awk '/active/ && /lvm/ {print $1; exit}')
    if [ -z "$STORAGE" ]; then
        echo "❌ Cannot detect valid LVM storage (local-lvm). Please specify manually."
        exit 1
    else
        echo "✅ Using detected storage: $STORAGE"
    fi
fi

echo "💾 Importing disk to $STORAGE..."
qm importdisk $VMID haos_ova-15.2.raw $STORAGE

echo "🔗 Attaching imported disk..."
UNUSED_DISK=$(qm config $VMID | grep 'unused' | awk -F ':' '{print $1}')
if [ -z "$UNUSED_DISK" ]; then
    echo "❌ Could not find imported disk as unused. Please check manually."
    exit 1
fi

qm set $VMID --scsi0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=scsi0

echo "🧹 Cleaning up temporary files..."
rm -f /tmp/haos_ova-15.2.qcow2 /tmp/haos_ova-15.2.raw /tmp/haos_ova-15.2.qcow2.xz

echo "✅ Home Assistant OS VM $VMID created successfully with EFI disk!"
echo "You can now start the VM in Proxmox GUI or run: qm start $VMID"

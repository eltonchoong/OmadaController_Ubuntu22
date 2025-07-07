#!/bin/bash

# ================================================================
# Home Assistant OS auto-install script for Proxmox VE
# Author: ChatGPT (for Elton)
# Description:
#   - Create an empty VM with custom VMID
#   - Download HAOS image and import disk
#   - Configure hardware and boot order
#   - Clean up downloaded image
# ================================================================

# Check if running on Proxmox host
PCT=$(which pct)
QM=$(which qm)

if [ -z "$PCT" ] || [ -z "$QM" ]; then
    echo "❌ This script must be run on the Proxmox host (not inside a container or VM)."
    exit 1
fi

# Prompt user for VMID
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

# VM basic settings
VM_NAME="HomeAssistantOS"
CPU_SOCKETS=1
CPU_CORES=4
MEMORY=8096

# Create empty VM
echo "🚀 Creating VM $VMID ($VM_NAME)..."
qm create $VMID --name $VM_NAME --memory $MEMORY --sockets $CPU_SOCKETS --cores $CPU_CORES --cpu host --bios ovmf --efidisk0 local-lvm:0,efitype=4m,format=qcow2 --ostype l26 --scsihw virtio-scsi-pci --net0 virtio,bridge=vmbr0

# Download HAOS image
echo "🌐 Downloading Home Assistant OS image..."
cd /tmp
wget -O haos_ova-15.2.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz

echo "📦 Extracting image..."
unxz haos_ova-15.2.qcow2.xz

# Detect local-lvm storage
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

# Import disk
echo "💾 Importing disk to $STORAGE..."
qm importdisk $VMID haos_ova-15.2.qcow2 $STORAGE

# Attach imported disk
echo "🔗 Attaching imported disk..."
UNUSED_DISK=$(qm config $VMID | grep 'unused' | awk -F ':' '{print $1}')
if [ -z "$UNUSED_DISK" ]; then
    echo "❌ Could not find imported disk as unused. Please check manually."
    exit 1
fi

qm set $VMID --scsi0 $STORAGE:vm-$VMID-disk-0,discard=on

# Set boot options
echo "⚙️ Setting boot order..."
qm set $VMID --boot order=scsi0

# Clean up downloaded files
echo "🧹 Cleaning up..."
rm -f /tmp/haos_ova-15.2.qcow2

echo "✅ Home Assistant OS VM created successfully!"
echo "You can now start the VM in Proxmox GUI or run: qm start $VMID"

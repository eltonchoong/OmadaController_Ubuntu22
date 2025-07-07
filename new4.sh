#!/bin/bash

# ================================================================
# Home Assistant OS auto-install script for Proxmox VE (styled exactly like ArcLoader)
# Author: ChatGPT (for Elton)
# Description:
#   - Create an empty VM with custom VMID
#   - Download HAOS qcow2 image and import disk directly
#   - Configure hardware, EFI disk, boot order
#   - Fully preserves ArcLoader header and prompts
# ================================================================

export LANG=en_US.UTF-8

# Colors
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
X='\033[0m'

CONSOLE='\033[0;100m\033[1;37m'
INFO='\033[0;44m\033[1;37m'
WARN='\033[0;43m\033[1;30m'
NOTOK='\033[0;41m\033[1;37m'
OK='\033[0;42m\033[1;30m'
DISK='\033[0;45m\033[1;37m'
TAB='\t'

# Emojis
START="🚀"
INFO_EMOJI="ℹ️"
OK_EMOJI="✅"
WARN_EMOJI="⚠️"
NOTOK_EMOJI="❌"
DISK_EMOJI="💽"

# Functions
line() {
    echo -e "\033[0;90m──────────────────────────────────────────────\033[0m"
}

create_header() {
    clear
    echo -e "\033[0;96m+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\033[0m"
    echo -e "             \033[1;37m$1\033[0m"
    echo -e "\033[0;96m+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++\033[0m"
}

continue_script() {
    read -n 1 -s -r -p $'Press any key to continue...\n'
}

pve_storages() {
    STORAGES=$(pvesm status -content images | awk 'NR>1 {print $1}')
}

# Header
clear
create_header "HAOS-Installer"

echo -e "${CONSOLE}Home Assistant OS ${C}default settings${X}"
line
echo -e "${C}CPU: 1 socket x 4 cores | Mem: 8192MB | NIC: vmbr0 | Storage: selectable${X}"
echo -e "${Y}> can be changed after creation <${X}"
line
echo -e "${C}Disk will be attached as scsi0. EFI disk added as efidisk0.${X}"
line
echo ""
echo -e "${INFO_EMOJI}${Y} Run script now? (y/Y)${X}"
read -p "" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${NOTOK}${R}Script cancelled by user.${X}"
    exit 0
fi

# Storage selection
pve_storages

if [ -z "$STORAGES" ]; then
    echo -e "${NOTOK}${R}No storage locations found that support disk images.${X}"
    exit 1
fi
line
echo -e "${DISK}${C}Please select target Storage for HAOS disk:${X}"
select STORAGE in $STORAGES; do
    if [ -n "$STORAGE" ]; then
        echo ""
        echo -e "${C}You selected:${X} $STORAGE"
        line
        break
    else
        echo -e "${R}Invalid selection. Please try again.${X}"
    fi
done

while true; do
    read -p "$(echo -e "${Y}Enter VMID (e.g., 105): ${X}")" VMID
    if ! [[ "$VMID" =~ ^[0-9]+$ ]]; then
        echo -e "${WARN}${R}VMID must be a number.${X}"
        continue
    fi
    if qm status $VMID &>/dev/null; then
        echo -e "${WARN}${R}VMID $VMID already exists. Choose another.${X}"
    else
        echo -e "${OK}${G}VMID $VMID is available.${X}"
        break
    fi
done

VM_NAME="HomeAssistantOS"
CPU_SOCKETS=1
CPU_CORES=4
MEMORY=8192

cleanup() {
    echo -e "${WARN}${Y}Error occurred. Cleaning up...${X}"
    if qm status $VMID &>/dev/null; then
        echo -e "${Y}Removing VM $VMID...${X}"
        qm destroy $VMID --purge || true
    fi
    rm -f /tmp/haos_ova-15.2.qcow2 /tmp/haos_ova-15.2.qcow2.xz
    exit 1
}

trap cleanup ERR

echo -e "${INFO}${C}Creating VM ${X}($VM_NAME)..."
qm create $VMID --name $VM_NAME --memory $MEMORY --sockets $CPU_SOCKETS --cores $CPU_CORES --cpu host --bios ovmf --ostype l26 --scsihw virtio-scsi-pci --net0 virtio,bridge=vmbr0

echo -e "${INFO}${C}Adding EFI disk...${X}"
qm set $VMID --efidisk0 $STORAGE:0,efitype=4m,format=raw

echo -e "${INFO}${C}Downloading Home Assistant OS image...${X}"
cd /tmp
rm -f haos_ova-15.2.qcow2.xz haos_ova-15.2.qcow2
wget -O haos_ova-15.2.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz

echo -e "${INFO}${C}Extracting image...${X}"
unxz haos_ova-15.2.qcow2.xz

echo -e "${INFO}${C}Importing qcow2 disk to storage $STORAGE...${X}"
qm importdisk $VMID haos_ova-15.2.qcow2 $STORAGE

UNUSED_DISK=$(qm config $VMID | grep 'unused' | awk -F ':' '{print $1}')
if [ -z "$UNUSED_DISK" ]; then
    echo -e "${NOTOK}${R}Could not find imported disk. Check manually.${X}"
    exit 1
fi

echo -e "${INFO}${C}Attaching disk as scsi0...${X}"
qm set $VMID --scsi0 $STORAGE:vm-${VMID}-disk-1,discard=on,iothread=1
qm set $VMID --boot order=scsi0
qm set $VMID --bootdisk scsi0
qm set $VMID --onboot 1

echo -e "${INFO}${C}Cleaning up temporary files...${X}"
rm -f /tmp/haos_ova-15.2.qcow2 /tmp/haos_ova-15.2.qcow2.xz

line
echo -e "${OK}${G}VM $VM_NAME (ID: $VMID) successfully created!${X}"
echo -e "${OK}${G}EFI disk: efidisk0 on $STORAGE${X}"
echo -e "${OK}${G}Main disk: scsi0 on $STORAGE${X}"
line

echo ""
echo -e "${INFO}${Y}You can now start the VM from GUI or run:${X} qm start $VMID"

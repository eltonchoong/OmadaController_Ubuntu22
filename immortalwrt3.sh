#!/bin/bash

# ================================================================
# ImmortalWRT auto-install script for Proxmox VE
# Author: ChatGPT (for Elton)
# Description:
#   - Create an empty VM with custom VMID
#   - Download ImmortalWRT img.gz image and import disk directly
#   - Configure hardware, BIOS (SeaBIOS), boot order
#   - Interactive prompts with colors & emojis
# ================================================================

export LANG=en_US.UTF-8

BK='\033[0;30m'
R='\033[0;31m'
G='\033[0;32m'
Y='\033[0;33m'
C='\033[0;36m'
W='\033[0;37m'
X='\033[0m'

TAB="  "
INFO="${TAB}ℹ️${TAB}${X}"
START="${TAB}▶️${TAB}${X}"
OK="${TAB}✅${TAB}${X}"
NOTOK="${TAB}❌${TAB}${X}"
WARN="${TAB}⚠️${TAB}${X}"
DISK="${TAB}💾${TAB}${X}"
CONSOLE="${TAB}📟${TAB}${X}"

create_header() {
    local title="$1"
    local total_width=60
    local title_length=${#title}
    local padding_needed=$(( total_width - title_length - 2 ))
    local left_padding=$(( padding_needed / 2 ))
    local right_padding=$(( padding_needed - left_padding ))
    local plus_line_top_bottom=$(printf "+%.0s" $(seq 1 $total_width))
    local left_plus=$(printf "+%.0s" $(seq 1 $left_padding))
    local right_plus=$(printf "+%.0s" $(seq 1 $right_padding))
    echo ""
    echo -e "${C}${plus_line_top_bottom}${X}"
    echo -e "${C}${left_plus}${X} ${title} ${C}${right_plus}${X}"
    echo -e "${C}${plus_line_top_bottom}${X}"
    echo ""
}

line() {
    printf '%*s\n' 60 '' | tr ' ' '-'
}

continue_script() {
    echo -e "${START}${Y}Run script now? (y/Y)${X}"
    read -n 1 run_script
    echo ""
    if [[ "$run_script" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${OK}${G}Running...${X}"
        echo ""
        echo ""
    else
        echo ""
        echo -e "${NOTOK}${R}Stopping...${X}"
        echo ""
        echo ""
        exit 1
    fi
}

clear
create_header "ImmortalWRT-Installer"

echo -e "${CONSOLE}ImmortalWRT ${C}default settings${X}"
line
echo -e "${C}CPU: 1 socket x 4 cores | Mem: 4096MB | NIC: vmbr0 | Storage: selectable${X}"
echo -e "${Y}> can be changed after creation <${X}"
line
echo -e "${C}Disk will be attached as scsi0.${X}"
line
echo ""
continue_script

pve_storages=$(pvesm status -content images | awk 'NR>1 {print $1}')

if [ -z "$pve_storages" ]; then
    echo -e "${NOTOK}${R}No storage locations found that support disk images.${X}"
    exit 1
fi
line
echo -e "${DISK}${C}Please select target Storage for ImmortalWRT disk:${X}"
select STORAGE in $pve_storages; do
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
    read -p "$(echo -e "${Y}Enter VMID (e.g., 106): ${X}")" VMID
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

VM_NAME="ImmortalWRT"
CPU_SOCKETS=1
CPU_CORES=4
MEMORY=4096

cleanup() {
    echo -e "${WARN}${Y}Error occurred. Cleaning up...${X}"
    if qm status $VMID &>/dev/null; then
        echo -e "${Y}Removing VM $VMID...${X}"
        qm destroy $VMID --purge || true
    fi
    rm -f /tmp/immortalwrt-24.10.1.img /tmp/immortalwrt-24.10.1.img.gz
    exit 1
}

trap cleanup ERR

echo -e "${INFO}${C}Creating VM ${X}($VM_NAME)..."
qm create $VMID --name $VM_NAME --memory $MEMORY --sockets $CPU_SOCKETS --cores $CPU_CORES --cpu host --bios seabios --ostype l26 --scsihw virtio-scsi-pci

echo -e "${INFO}${C}Downloading ImmortalWRT image...${X}"
cd /tmp
rm -f immortalwrt-24.10.1.img.gz immortalwrt-24.10.1.img
wget -O immortalwrt-24.10.1.img.gz https://github.com/eltonchoong/AutoBuildImmortalWrt/releases/download/Autobuild-x86-64/immortalwrt-24.10.1-x86-64-generic-squashfs-combined-efi.img.gz

echo -e "${INFO}${C}Extracting image...${X}"
gunzip immortalwrt-24.10.1.img.gz 2>&1 | grep -v 'trailing garbage ignored' || true

echo -e "${INFO}${C}Importing disk to storage $STORAGE...${X}"
qm importdisk $VMID immortalwrt-24.10.1.img $STORAGE

UNUSED_DISK=$(qm config $VMID | grep 'unused' | awk -F ':' '{print $1}')
if [ -z "$UNUSED_DISK" ]; then
    echo -e "${NOTOK}${R}Could not find imported disk. Check manually.${X}"
    exit 1
fi

echo -e "${INFO}${C}Attaching disk as scsi0...${X}"
qm set $VMID --scsi0 $STORAGE:vm-${VMID}-disk-0,discard=on,iothread=1
qm set $VMID --boot order=scsi0
qm set $VMID --bootdisk scsi0
qm set $VMID --onboot 1

echo -e "${INFO}${C}Cleaning up temporary files...${X}"
rm -f /tmp/immortalwrt-24.10.1.img /tmp/immortalwrt-24.10.1.img.gz

line
echo -e "${OK}${G}VM $VM_NAME (ID: $VMID) successfully created!${X}"
echo -e "${OK}${G}Main disk: scsi0 on $STORAGE${X}"
line

echo ""
echo -e "${INFO}${Y}You can now start the VM from GUI or run:${X} qm start $VMID"

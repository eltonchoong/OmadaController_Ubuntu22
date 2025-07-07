# ================================================================
# Home Assistant OS auto-install script for Proxmox VE 
# Author: ChatGPT (for Elton)
# Description:
#   - Create an empty VM with custom VMID
#   - Download HAOS qcow2 image and import disk directly
#   - Configure hardware, EFI disk, boot order
#   - Interactive prompts with colors & emojis
# ================================================================

export LANG=en_US.UTF-8

# Colors
BK='\033[0;30m'  # Black
R='\033[0;31m'  # Red
G='\033[0;32m'  # Green
Y='\033[0;33m'  # Yellow
B='\033[0;34m'  # Blue
M='\033[0;35m'  # Magenta
C='\033[0;36m'  # Cyan
W='\033[0;37m'  # White

# Background-Colors
BG_R='\033[41m'
BG_G='\033[42m'
BG_Y='\033[43m'
BG_B='\033[44m'
BG_M='\033[45m'
BG_C='\033[46m'
BG_W='\033[47m'

# Reset-Color
X='\033[0m'

# Emoji
TAB="  "
INFO="${TAB}ℹ️${TAB}${X}"
START="${TAB}▶️${TAB}${X}"
OK="${TAB}✅${TAB}${X}"
NOTOK="${TAB}❌${TAB}${X}"
WARN="${TAB}⚠️${TAB}${X}"
DISK="${TAB}💾${TAB}${X}"
CONSOLE="${TAB}📟${TAB}${X}"
ROBOT="${TAB}🤖${TAB}${X}"
TOOL="${TAB}🛠️${TAB}${X}"


# Function Header
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

# Function seperating line
#	line() {
#		local cols
#		cols=$(tput cols) 
#
#		printf '%*s\n' "$cols" '' | tr ' ' '-'
#	}
	line() {
		printf '%*s\n' 60 '' | tr ' ' '-'
	}

# Function Continue Script
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



# Function to check run as root
	run_as_root() {
		if [[ $EUID -ne 0 ]]; then
			echo "${WARN}${R}This script must be run as root!${X}"
			exit 1
		fi
	}


# Function Spinner
	show_spinner() {
	    local pid=$1
	    local delay=0.1
	    local spinstr='|/-\'

	    tput civis
		printf "\n"

	    while ps -p $pid &> /dev/null; do
		local temp=${spinstr#?}
		printf "\r[ %c ] ${C}Loading...${X}" "$spinstr"
		spinstr=$temp${spinstr%"$temp"}
		sleep $delay
		printf "\b\b\b\b\b\b"
	    done
	    tput cnorm
	}


# Clear screen and header
clear
create_header "HAOS-Installer"

# Info
echo -e "${CONSOLE}Home Assistant OS ${C}default settings${X}"
line
echo -e "${C}CPU: 1 socket x 4 cores | Mem: 8192MB | NIC: vmbr0 | Storage: selectable${X}"
echo -e "${Y}> can be changed after creation <${X}"
line
echo -e "${C}Disk will be attached as scsi0. EFI disk added as efidisk0.${X}"
line
echo ""
continue_script

# Show available storages
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

# VMID input
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

# Set VM parameters
VM_NAME="HomeAssistantOS"
CPU_SOCKETS=1
CPU_CORES=4
MEMORY=8192

# Clean up function
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

# Create VM
echo -e "${INFO}${C}Creating VM ${X}($VM_NAME)..."
qm create $VMID --name $VM_NAME --memory $MEMORY --sockets $CPU_SOCKETS --cores $CPU_CORES --cpu host --bios ovmf --ostype l26 --scsihw virtio-scsi-pci --net0 virtio,bridge=vmbr0

# Add EFI disk
echo -e "${INFO}${C}Adding EFI disk...${X}"
qm set $VMID --efidisk0 $STORAGE:0,efitype=4m,format=raw

# Download HAOS image
echo -e "${INFO}${C}Downloading Home Assistant OS image...${X}"
cd /tmp
rm -f haos_ova-15.2.qcow2.xz haos_ova-15.2.qcow2
wget -O haos_ova-15.2.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/15.2/haos_ova-15.2.qcow2.xz

# Extract qcow2
echo -e "${INFO}${C}Extracting image...${X}"
unxz haos_ova-15.2.qcow2.xz

# Import qcow2 disk directly
echo -e "${INFO}${C}Importing qcow2 disk to storage $STORAGE...${X}"
qm importdisk $VMID haos_ova-15.2.qcow2 $STORAGE

# Find imported disk
UNUSED_DISK=$(qm config $VMID | grep 'unused' | awk -F ':' '{print $1}')
if [ -z "$UNUSED_DISK" ]; then
    echo -e "${NOTOK}${R}Could not find imported disk. Check manually.${X}"
    exit 1
fi

# Attach disk
echo -e "${INFO}${C}Attaching disk as scsi0...${X}"
qm set $VMID --scsi0 $STORAGE:vm-${VMID}-disk-1,discard=on,iothread=1
qm set $VMID --boot order=scsi0
qm set $VMID --bootdisk scsi0
qm set $VMID --onboot 1

# Clean up temp files
echo -e "${INFO}${C}Cleaning up temporary files...${X}"
rm -f /tmp/haos_ova-15.2.qcow2 /tmp/haos_ova-15.2.qcow2.xz

# Success message
line
echo -e "${OK}${G}VM $VM_NAME (ID: $VMID) successfully created!${X}"
echo -e "${OK}${G}EFI disk: efidisk0 on $STORAGE${X}"
echo -e "${OK}${G}Main disk: scsi0 on $STORAGE${X}"
line

echo ""
echo -e "${INFO}${Y}You can now start the VM from GUI or run:${X} qm start $VMID"
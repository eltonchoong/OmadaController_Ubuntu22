#!/bin/bash

# Exit if error
set -e

echo "============================="
echo "🌀 Update system & install ifupdown"
echo "============================="
sudo apt update
sudo apt install -y ifupdown

echo "============================="
echo "🧹 Remove netplan"
echo "============================="
sudo apt purge -y netplan.io

echo "============================="
echo "🔎 Detect active interface"
echo "============================="
# Find first non-loopback, non-virtual interface
INTERFACE=$(ip -o link show | awk -F': ' '/state UP/ && $2 != "lo" {print $2; exit}')

if [ -z "$INTERFACE" ]; then
    echo "❌ No active network interface found. Exiting."
    exit 1
fi

echo "✅ Detected interface: $INTERFACE"

echo "============================="
echo "⚙️ Write /etc/network/interfaces"
echo "============================="
sudo bash -c "cat > /etc/network/interfaces" <<EOF
# network interfaces
auto lo
iface lo inet loopback

auto $INTERFACE
iface $INTERFACE inet dhcp
        #address 10.10.0.2
        #netmask 255.255.255.0
        #gateway 10.10.0.1
        #dns-nameservers 10.10.10.10
EOF

echo "============================="
echo "🔄 Restart networking"
echo "============================="
sudo systemctl restart networking

echo "✅ Network configuration updated! Now using ifupdown and DHCP on $INTERFACE"

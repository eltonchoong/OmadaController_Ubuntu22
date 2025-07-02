#!/bin/bash
# ------------------------------
# ✅ 完全禁用 netplan & cloud-init 网络
# ✅ 切换 /etc/network/interfaces
# ✅ 清理残留配置，防止重启后 DHCP
# ------------------------------

echo "============================"
echo "Disable cloud-init network config..."
echo "============================"
mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

echo "============================"
echo "Clean cloud-init state..."
echo "============================"
cloud-init clean --logs
rm -rf /var/lib/cloud/*

echo "============================"
echo "Removing netplan config files..."
echo "============================"
rm -rf /etc/netplan/*.yaml

echo "============================"
echo "Removing systemd network files..."
echo "============================"
rm -f /etc/systemd/network/*.network
rm -f /run/systemd/network/*.network

echo "============================"
echo "Clearing /etc/network/interfaces.d/ ..."
echo "============================"
rm -f /etc/network/interfaces.d/*

echo "============================"
echo "Stop and disable systemd-networkd ..."
echo "============================"
systemctl stop systemd-networkd
systemctl disable systemd-networkd

echo "============================"
echo "Stop and disable NetworkManager ..."
echo "============================"
systemctl stop NetworkManager 2>/dev/null
systemctl disable NetworkManager 2>/dev/null
apt purge network-manager -y

echo "============================"
echo "Install ifupdown ..."
echo "============================"
apt update
apt install ifupdown -y

echo "============================"
echo "Writing /etc/network/interfaces ..."
echo "============================"
cat <<EOF >/etc/network/interfaces
auto lo
iface lo inet loopback

auto eno1
iface eno1 inet static
    address 10.10.0.2
    netmask 255.255.255.0
    gateway 10.10.0.1
    dns-nameservers 10.10.10.10 1.1.1.1
EOF

echo "============================"
echo "Releasing DHCP lease and flushing IP addresses ..."
echo "============================"
dhclient -r eno1 || true
ip addr flush dev eno1
ip route flush dev eno1

echo "============================"
echo "Restarting networking service ..."
echo "============================"
systemctl restart networking

echo "============================"
echo "Checking final IP and route ..."
echo "============================"
ip addr show eno1
ip route

echo "============================"
echo "✔️ All done! System will reboot in 5 seconds ..."
echo "============================"
sleep 5
reboot

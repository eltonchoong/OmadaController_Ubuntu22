#!/bin/bash
# -------------------------
# 完整关闭 netplan，停用 systemd-networkd
# 改为使用 /etc/network/interfaces
# 清理旧 DHCP 和多余 IP
# 最后自动 reboot
# -------------------------

echo "============================"
echo "Rewriting /etc/network/interfaces ..."
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
echo "Removing netplan config files ..."
echo "============================"

rm -rf /etc/netplan/*.yaml

echo "============================"
echo "Stopping and disabling systemd-networkd ..."
echo "============================"

systemctl stop systemd-networkd
systemctl disable systemd-networkd

echo "============================"
echo "Stopping and disabling NetworkManager (if exists) ..."
echo "============================"

systemctl stop NetworkManager 2>/dev/null
systemctl disable NetworkManager 2>/dev/null

echo "============================"
echo "Releasing DHCP lease and flushing IP addresses ..."
echo "============================"

dhclient -r eno1
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
echo "✔️ Configuration complete. System will reboot now ..."
echo "============================"

sleep 5
reboot

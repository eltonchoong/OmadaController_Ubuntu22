#!/bin/bash
# -----------------------------------------
# ✅ 完全禁用 netplan & cloud-init 网络
# ✅ 切换到 /etc/network/interfaces 静态配置
# ✅ 清理所有残留配置，防止重启后被 DHCP 覆盖
# ✅ 中文备注版，结束后自动删除脚本文件
# -----------------------------------------

echo "============================"
echo "安装 ifupdown（一定要最先装）..."
echo "============================"
apt update
apt install ifupdown -y

echo "============================"
echo "禁用 cloud-init 网络配置 ..."
echo "============================"
mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg

echo "============================"
echo "清理 cloud-init 状态缓存 ..."
echo "============================"
cloud-init clean --logs
rm -rf /var/lib/cloud/*

echo "============================"
echo "删除 netplan 配置文件 ..."
echo "============================"
rm -rf /etc/netplan/*.yaml

echo "============================"
echo "删除 systemd 网络残留文件 ..."
echo "============================"
rm -f /etc/systemd/network/*.network
rm -f /run/systemd/network/*.network

echo "============================"
echo "清理 /etc/network/interfaces.d/ ..."
echo "============================"
rm -f /etc/network/interfaces.d/*

echo "============================"
echo "停止并禁用 systemd-networkd ..."
echo "============================"
systemctl stop systemd-networkd
systemctl disable systemd-networkd

echo "============================"
echo "停止并禁用 NetworkManager ..."
echo "============================"
systemctl stop NetworkManager 2>/dev/null
systemctl disable NetworkManager 2>/dev/null
apt purge network-manager -y

echo "============================"
echo "写入 /etc/network/interfaces 配置 ..."
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
echo "释放 DHCP 租约并清空 IP 地址 ..."
echo "============================"
dhclient -r eno1 || true
ip addr flush dev eno1
ip route flush dev eno1

echo "============================"
echo "重启 networking 服务 ..."
echo "============================"
systemctl restart networking

echo "============================"
echo "检查最终 IP 地址与路由 ..."
echo "============================"
ip addr show eno1
ip route

echo "============================"
echo "✔️ 所有步骤完成！5 秒后自动重启 ..."
echo "============================"
sleep 5

echo "============================"
echo "删除当前脚本文件 ..."
echo "============================"
rm -- "$0"

reboot

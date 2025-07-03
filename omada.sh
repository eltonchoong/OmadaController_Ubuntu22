#!/bin/bash

set -e

# 防止交互式弹窗
export DEBIAN_FRONTEND=noninteractive
echo '* libraries/restart-without-asking boolean true' | sudo debconf-set-selections

if [ "$EUID" -ne 0 ]; then
  echo "⚠️ Please run as root or use sudo."
  exit 1
fi

echo "========================="
echo "🌏 Set timezone to Asia/Kuala_Lumpur (GMT+8)"
echo "========================="
timedatectl set-timezone Asia/Kuala_Lumpur

echo "========================="
echo "🚀 Update system"
echo "========================="
apt-get update && apt-get upgrade -y

echo "========================="
echo "💻 Install Java & resources"
echo "========================="
apt-get install curl gnupg jsvc openjdk-17-jdk -y

echo "========================="
echo "🔧 Install dependencies for JSVC"
echo "========================="
apt install autoconf make gcc -y

echo "========================="
echo "⬇️ Download and extract JSVC source code"
echo "========================="
wget https://archive.apache.org/dist/commons/daemon/source/commons-daemon-1.2.4-src.tar.gz
tar zxvf commons-daemon-1.2.4-src.tar.gz
cd commons-daemon-1.2.4-src/src/native/unix || { echo "❌ Directory not found! Exiting."; exit 1; }

echo "========================="
echo "⚙️ Compile and install JSVC"
echo "========================="
sh support/buildconf.sh
./configure --with-java=/usr/lib/jvm/java-17-openjdk-amd64
make

echo "========================="
echo "🔗 Create soft link for jsvc"
echo "========================="
rm /usr/bin/jsvc 2>/dev/null || true
ln -s "$(pwd)/jsvc" /usr/bin/jsvc

cd /root
rm -f commons-daemon-1.2.4-src.tar.gz

echo "========================="
echo "⬇️ Install MongoDB v4.4 dependencies"
echo "========================="
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb
dpkg -i libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb
rm -f libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb

echo "========================="
echo "🔑 Add MongoDB v4.4 repo and install"
echo "========================="
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-4.4.list
apt-get update
apt install -y mongodb-org

echo "========================="
echo "⬇️ Download and install Omada SDN Controller v5.15.24.18"
echo "========================="
wget https://download.tplinkcloud.com/firmware/omada_v5.15.24.18_linux_x64_20250630184434_1751420683276.deb
dpkg -i omada_v5.15.24.18_linux_x64_20250630184434_1751420683276.deb

echo "========================="
echo "🧹 Clean up files"
echo "========================="
rm -f omada_v5.15.24.18_linux_x64_20250630184434_1751420683276.deb
rm -rf ./commons-daemon-1.2.4-src

echo "========================="
echo "删除当前脚本文件 ..."
echo "========================="
rm -- "$0"

# 获取本机第一个IP地址
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "========================="
echo "✅ All done! Omada SDN installed successfully!"
echo "========================="
echo "🌐 Now you can access Omada at: http://$SERVER_IP:8088"

#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "========================="
echo "🚀 Update system"
echo "========================="
sudo apt-get update && sudo apt-get upgrade -y

echo "========================="
echo "💻 Install Java & resources"
echo "========================="
sudo apt-get install curl gnupg jsvc openjdk-17-jdk -y

echo "========================="
echo "🔧 Install dependencies for JSVC"
echo "========================="
sudo apt install autoconf make gcc -y

echo "========================="
echo "⬇️ Download and extract JSVC source code"
echo "========================="
wget https://archive.apache.org/dist/commons/daemon/source/commons-daemon-1.2.4-src.tar.gz
tar zxvf commons-daemon-1.2.4-src.tar.gz
cd commons-daemon-1.2.4-src/src/native/unix

echo "========================="
echo "⚙️ Compile and install JSVC"
echo "========================="
sh support/buildconf.sh
./configure --with-java=/usr/lib/jvm/java-17-openjdk-amd64
make

echo "========================="
echo "🔗 Create soft link for jsvc"
echo "========================="
sudo rm /usr/bin/jsvc 2>/dev/null || true
sudo ln -s /root/commons-daemon-1.2.4-src/src/native/unix/jsvc /usr/bin/jsvc

echo "========================="
echo "⬇️ Install MongoDB v4.4 dependencies"
echo "========================="
wget http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb
sudo dpkg -i libssl1.1_1.1.1-1ubuntu2.1~18.04.23_amd64.deb

echo "========================="
echo "🔑 Add MongoDB v4.4 repo and install"
echo "========================="
wget -qO - https://www.mongodb.org/static/pgp/server-4.4.asc | sudo apt-key add -
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt install -y mongodb-org

echo "========================="
echo "⬇️ Download and install Omada SDN Controller v5.15.24.18"
echo "========================="
wget https://download.tplinkcloud.com/firmware/omada_v5.15.24.18_linux_x64_20250630184434_1751420683276.deb
sudo dpkg -i omada_v5.15.24.18_linux_x64_20250630184434_1751420683276.deb

echo "========================="
echo "✅ All done! Omada SDN installed successfully!"
echo "========================="

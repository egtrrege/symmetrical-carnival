#!/bin/bash

set -e

echo "==== Windows 10 VPS Installer ===="

function install_win() {

echo "[+] Installing dependencies..."
apt update
apt install -y qemu-kvm libvirt-daemon-system virtinst novnc websockify curl wget

systemctl enable --now libvirtd

echo "[+] Downloading Windows ISO (official source via script)..."
wget -O win10.iso https://dl.bobpony.com/windows/10/en-us_windows_10_22h2_x64.iso

echo "[+] Creating VM..."
virt-install \
--name win10 \
--ram 16384 \
--vcpus 6 \
--disk path=/var/lib/libvirt/images/win10.qcow2,size=80 \
--os-variant win10 \
--cdrom $(pwd)/win10.iso \
--network network=default \
--graphics vnc,listen=0.0.0.0 \
--noautoconsole

echo "[+] Starting noVNC..."
websockify --web=/usr/share/novnc/ 6080 localhost:5900 &

echo "[+] Installing Cloudflare Tunnel..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared

./cloudflared tunnel --url http://localhost:6080 &

echo "====================================="
echo "Access your Windows install via the Cloudflare URL above"
echo "====================================="
}

function uninstall_all() {
echo "[!] Removing everything..."

virsh destroy win10 || true
virsh undefine win10 || true
rm -f /var/lib/libvirt/images/win10.qcow2
rm -f win10.iso

pkill websockify || true
pkill cloudflared || true

apt purge -y qemu-kvm libvirt-daemon-system virtinst novnc websockify
apt autoremove -y

echo "[+] Fully removed."
}

echo "Choose option:"
echo "1) Install Windows 10"
echo "2) Uninstall everything"

read -p "Enter choice: " choice

if [ "$choice" == "1" ]; then
install_win
elif [ "$choice" == "2" ]; then
uninstall_all
else
echo "Invalid option"
fi

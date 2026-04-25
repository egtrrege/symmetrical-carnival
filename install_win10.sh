#!/bin/bash
set -e

VM_NAME="win10"
DISK_PATH="/var/lib/libvirt/images/win10.qcow2"
ISO_PATH="$(pwd)/win10.iso"
VNC_PORT=5900
NOVNC_PORT=6080

echo "======================================"
echo "  Windows 10 KVM VPS Installer (FIXED)"
echo "======================================"

install_win() {

echo "[1/10] Installing dependencies..."
apt update
apt install -y qemu-kvm libvirt-daemon-system virtinst novnc websockify curl wget ovmf

systemctl enable --now libvirtd

echo "[2/10] Cleaning old VM..."
virsh destroy $VM_NAME || true
virsh undefine $VM_NAME || true
rm -f $DISK_PATH

echo "[3/10] Downloading Windows ISO..."
wget -O win10.iso https://dl.bobpony.com/windows/10/en-us_windows_10_22h2_x64.iso

echo "[4/10] Creating disk..."
qemu-img create -f qcow2 $DISK_PATH 80G

echo "[5/10] Creating VM (UEFI + VirtIO optimized)..."
virt-install \
--name $VM_NAME \
--ram 16384 \
--vcpus 6 \
--disk path=$DISK_PATH,bus=virtio \
--os-variant win10 \
--boot uefi \
--cdrom $ISO_PATH \
--network network=default,model=virtio \
--graphics vnc,listen=0.0.0.0,port=$VNC_PORT \
--noautoconsole

echo "[6/10] Starting noVNC..."
websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT > novnc.log 2>&1 &

sleep 2

echo "[7/10] Starting Cloudflare Tunnel (temporary)..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared

echo "[8/10] Launching tunnel..."
./cloudflared tunnel --no-autoupdate --url http://localhost:$NOVNC_PORT > tunnel.log 2>&1 &

echo "[9/10] Waiting for access link..."
sleep 5

echo "[10/10] DONE!"
echo "--------------------------------------"
echo "Open Cloudflare URL from logs above"
echo "or check tunnel.log"
echo "--------------------------------------"

echo "VM Status:"
virsh list --all

}

uninstall_all() {

echo "[!] FULL CLEAN STARTING..."

virsh destroy $VM_NAME || true
virsh undefine $VM_NAME || true

rm -f $DISK_PATH
rm -f win10.iso

pkill websockify || true
pkill cloudflared || true

apt purge -y qemu-kvm libvirt-daemon-system virtinst novnc websockify ovmf
apt autoremove -y

echo "[✓] FULL CLEAN DONE"
}

echo ""
echo "Choose option:"
echo "1) Install Windows 10 (FULL AUTO FIXED)"
echo "2) Uninstall everything"

read -p "Enter choice: " choice

if [ "$choice" == "1" ]; then
install_win
elif [ "$choice" == "2" ]; then
uninstall_all
else
echo "Invalid option"
fi

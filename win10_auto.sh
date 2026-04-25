#!/bin/bash

set +e

VM="win10"
DISK="/var/lib/libvirt/images/win10.qcow2"
ISO="win10.iso"
RAM=16384
CPU=6
VNC_PORT=5900
WEB_PORT=6080

echo "==== WINDOWS 10 AUTO INSTALL (FIXED VERSION) ===="

install() {

echo "[1] Installing dependencies..."
apt update -y
apt install -y qemu-kvm libvirt-daemon-system virtinst novnc websockify curl wget ovmf aria2

systemctl enable --now libvirtd

echo "[2] Cleaning old VM..."
virsh destroy $VM 2>/dev/null
virsh undefine $VM 2>/dev/null
rm -f $DISK $ISO

echo "[3] Creating disk..."
qemu-img create -f qcow2 $DISK 80G

echo "[4] Download ISO (multi-source fallback)..."

URLS=(
"https://archive.org/download/windows-10-22h2-english-x64/Win10_22H2_English_x64.iso"
"https://software-download.microsoft.com/db/Win10_22H2_English_x64.iso"
)

for url in "${URLS[@]}"; do
echo "[TRY] $url"
wget --user-agent="Mozilla/5.0" -O $ISO "$url"

if [ -f "$ISO" ] && [ $(stat -c%s "$ISO") -gt 1000000000 ]; then
echo "[OK] ISO downloaded"
break
else
echo "[FAIL] next source..."
rm -f $ISO
fi
done

if [ ! -f "$ISO" ]; then
echo "[ERROR] ISO download failed"
exit 1
fi

echo "[5] Creating VM..."
virt-install \
--name $VM \
--ram $RAM \
--vcpus $CPU \
--disk path=$DISK,bus=virtio \
--os-variant win10 \
--boot uefi \
--cdrom $ISO \
--network network=default,model=virtio \
--graphics vnc,listen=0.0.0.0,port=$VNC_PORT \
--noautoconsole

echo "[6] Starting noVNC..."
websockify --web=/usr/share/novnc/ $WEB_PORT localhost:$VNC_PORT > novnc.log 2>&1 &

sleep 3

echo "[7] Cloudflare Tunnel starting..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared

./cloudflared tunnel --no-autoupdate --url http://localhost:$WEB_PORT > tunnel.log 2>&1 &

sleep 5

echo "====================================="
echo "DONE"
echo "Check tunnel.log for your URL"
echo "====================================="
}

uninstall() {
echo "[!] Cleaning system..."

virsh destroy $VM 2>/dev/null
virsh undefine $VM 2>/dev/null

rm -f $DISK $ISO

pkill websockify 2>/dev/null
pkill cloudflared 2>/dev/null

apt purge -y qemu-kvm libvirt-daemon-system virtinst novnc websockify ovmf
apt autoremove -y

echo "[OK] Fully removed"
}

echo "1) Install Windows 10"
echo "2) Uninstall"
read -p "Choice: " c

if [ "$c" == "1" ]; then
install
else
uninstall
fi

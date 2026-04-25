#!/bin/bash

VM="win10"
DISK="/var/lib/libvirt/images/win10.qcow2"
ISO="win10.iso"
RAM=16384
CPU=6
VNC_PORT=5900
WEB_PORT=6080

echo "====================================="
echo "  WINDOWS 10 AUTO KVM INSTALLER PRO  "
echo "====================================="

# -----------------------------
# SAFE INSTALL MODE
# -----------------------------
install() {

set +e

echo "[1/12] Installing dependencies..."
apt update -y
apt install -y qemu-kvm libvirt-daemon-system virtinst novnc websockify curl wget ovmf aria2

systemctl enable --now libvirtd

echo "[2/12] Cleaning old VM..."
virsh destroy $VM 2>/dev/null
virsh undefine $VM 2>/dev/null
rm -f $DISK $ISO

echo "[3/12] Creating disk..."
qemu-img create -f qcow2 $DISK 80G

echo "[4/12] Downloading Windows ISO (multi-source fallback)..."

download_iso() {

URLS=(
"https://archive.org/download/windows-10-22h2-english-x64/Win10_22H2_English_x64.iso"
"https://software-download.microsoft.com/db/Win10_22H2_English_x64.iso"
"https://mirror.rackspace.com/Windows10.iso"
)

for url in "${URLS[@]}"; do
echo "[TRY] $url"

wget --user-agent="Mozilla/5.0" -O $ISO "$url"

if [ -f "$ISO" ] && [ $(stat -c%s "$ISO") -gt 1000000000 ]; then
echo "[OK] ISO downloaded successfully"
return 0
else
echo "[FAIL] trying next source..."
rm -f $ISO
fi

done

echo "[ERROR] All ISO sources failed!"
exit 1
}

download_iso

echo "[5/12] Creating VM (UEFI + VirtIO)..."

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

echo "[6/12] Starting noVNC..."
websockify --web=/usr/share/novnc/ $WEB_PORT localhost:$VNC_PORT > novnc.log 2>&1 &

sleep 2

echo "[7/12] Starting Cloudflare Tunnel (temporary)..."
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared

./cloudflared tunnel --no-autoupdate --url http://localhost:$WEB_PORT > tunnel.log 2>&1 &

sleep 5

echo "[8/12] VM Status:"
virsh list --all

echo "[9/12] Access Info:"
echo "Check tunnel.log for Cloudflare URL"
echo "or run: cat tunnel.log"

echo "[10/12] Setup complete!"
echo "====================================="
}

# -----------------------------
# UNINSTALL MODE
# -----------------------------
uninstall() {

echo "[!] FULL CLEAN STARTING..."

virsh destroy $VM 2>/dev/null
virsh undefine $VM 2>/dev/null

rm -f $DISK $ISO

pkill websockify 2>/dev/null
pkill cloudflared 2>/dev/null

apt purge -y qemu-kvm libvirt-daemon-system virtinst novnc websockify ovmf
apt autoremove -y

echo "[✔] FULL CLEAN COMPLETE"
}

# -----------------------------
# MENU
# -----------------------------
echo ""
echo "1) Install Windows 10 (AUTO PRO)"
echo "2) Uninstall Everything"
echo ""
read -p "Select: " opt

if [ "$opt" == "1" ]; then
install
elif [ "$opt" == "2" ]; then
uninstall
else
echo "Invalid option"
fi

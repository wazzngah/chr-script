#!/bin/bash

# Fungsi untuk menampilkan animasi loading
loading_animation() {
    local duration=$1
    local step=0
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    while [ $step -lt $duration ]; do
        for (( i=0; i<${#chars}; i++ )); do
            printf "\r[%s] $2" "${chars:$i:1}"
            sleep 0.1
        done
        step=$((step+1))
    done
    printf "\r[✔] $2\n"
}

# Memastikan skrip dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    echo "Jalankan script ini sebagai root."
    exit 1
fi

# Variabel konfigurasi
CHR_VERSION="7.11.2" # Ubah versi sesuai kebutuhan
DISK_SIZE="1G"
PORT_ETH="eth0" # Port ethernet untuk koneksi
CHR_IMAGE_URL="https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip"
IMAGE_NAME="chr-$CHR_VERSION.img"
DISK_NAME="chr-disk.img"

# Tampilkan informasi
clear
echo "==============================="
echo "   MikroTik CHR Installer"
echo "==============================="
echo "Versi CHR: $CHR_VERSION"
echo "Ukuran Disk: $DISK_SIZE"
echo "Ethernet: $PORT_ETH"
echo "==============================="

# Step 1: Unduh file CHR
loading_animation 5 "Mengunduh file CHR versi $CHR_VERSION..."
wget -q $CHR_IMAGE_URL -O $IMAGE_NAME.zip
if [ $? -ne 0 ]; then
    echo "[✖] Gagal mengunduh CHR. Periksa koneksi internet Anda."
    exit 1
fi

# Step 2: Ekstrak file CHR
loading_animation 5 "Menyiapkan file CHR..."
unzip -o $IMAGE_NAME.zip
if [ $? -ne 0 ]; then
    echo "[✖] Gagal mengekstrak file CHR."
    exit 1
fi

# Step 3: Membuat disk virtual
loading_animation 3 "Membuat disk virtual sebesar $DISK_SIZE..."
qemu-img create -f qcow2 $DISK_NAME $DISK_SIZE

# Step 4: Instal CHR ke disk virtual
loading_animation 5 "Menginstal CHR ke disk virtual..."
qemu-system-x86_64 -drive file=$DISK_NAME,if=virtio -drive file=$IMAGE_NAME,if=virtio -nographic -serial telnet:127.0.0.1:5555,server,nowait -boot d -m 256 -netdev user,id=net0,hostfwd=tcp::2222-:22 -device e1000,netdev=net0 -enable-kvm

# Step 5: Konfigurasi DHCP client
loading_animation 3 "Mengonfigurasi auto DHCP client di $PORT_ETH..."
cat << EOF > dhcp-client.rsc
/interface ethernet set $PORT_ETH name=ether1
/ip dhcp-client add interface=ether1
EOF
echo "Konfigurasi DHCP client selesai."

# Step 6: Membersihkan file sementara
loading_animation 2 "Membersihkan file sementara..."
rm -f $IMAGE_NAME.zip $IMAGE_NAME

# Delay dan reboot
echo "Instalasi selesai. Rebooting dalam 5 detik..."
sleep 5
reboot

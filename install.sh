#!/bin/bash

# Fungsi untuk menampilkan animasi loading dengan progres
progress_bar() {
    local progress=0
    local total=$1
    local step=$((100 / total))
    echo -n "["
    while [ $progress -le 100 ]; do
        local filled=$((progress / step))
        local empty=$((total - filled))
        printf "\r["
        printf "%0.s#" $(seq 1 $filled)
        printf "%0.s-" $(seq 1 $empty)
        printf "] %d%%" $progress
        sleep 0.1
        progress=$((progress + step))
    done
    echo -e "\r[########################################] 100%"
}

# Fungsi untuk menampilkan informasi hardware dan partisi
display_system_info() {
    echo "====================================="
    echo "   Detail Sistem VPS Anda:"
    echo "====================================="
    echo "Prosesor:"
    lscpu | grep "Model name" | sed 's/Model name:\s*//'
    echo "-------------------------------------"
    echo "RAM Total:"
    free -h | grep Mem | awk '{print $2}'
    echo "-------------------------------------"
    echo "Disk:"
    lsblk | grep disk
    echo "-------------------------------------"
    echo "Partisi:"
    lsblk | grep part
    echo "====================================="
}

# Memastikan skrip dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    echo "Jalankan script ini sebagai root."
    exit 1
fi

# Variabel konfigurasi
CHR_VERSION="7.11.2" # Ubah versi sesuai kebutuhan
DISK_SIZE="1G"
CHR_IMAGE_URL="https://download.mikrotik.com/routeros/$CHR_VERSION/chr-$CHR_VERSION.img.zip"
IMAGE_NAME="chr-$CHR_VERSION.img"
DISK_NAME="chr-disk.img"

# Deteksi port ethernet otomatis
PORT_ETH=$(ip link show | awk -F': ' '/^[0-9]+: e/{print $2; exit}')
if [ -z "$PORT_ETH" ]; then
    echo "Tidak dapat mendeteksi port ethernet. Pastikan sistem Anda memiliki port ethernet aktif."
    exit 1
fi

# Tampilkan informasi
clear
echo "==============================="
echo "   MikroTik CHR Installer"
echo "==============================="
echo "Versi CHR: $CHR_VERSION"
echo "Ukuran Disk: $DISK_SIZE"
echo "Ethernet: $PORT_ETH"
display_system_info
echo "==============================="

# Step 1: Unduh file CHR
echo "Mengunduh file CHR versi $CHR_VERSION..."
progress_bar 50
wget -q $CHR_IMAGE_URL -O $IMAGE_NAME.zip
if [ $? -ne 0 ]; then
    echo "[✖] Gagal mengunduh CHR. Periksa koneksi internet Anda."
    exit 1
fi

# Step 2: Ekstrak file CHR
echo "Menyiapkan file CHR..."
progress_bar 30
unzip -o $IMAGE_NAME.zip
if [ $? -ne 0 ]; then
    echo "[✖] Gagal mengekstrak file CHR."
    exit 1
fi

# Step 3: Membuat disk virtual
echo "Membuat disk virtual sebesar $DISK_SIZE..."
progress_bar 20
qemu-img create -f qcow2 $DISK_NAME $DISK_SIZE

# Step 4: Instal CHR ke disk virtual
echo "Menginstal CHR ke disk virtual..."
progress_bar 40
qemu-system-x86_64 -drive file=$DISK_NAME,if=virtio -drive file=$IMAGE_NAME,if=virtio -nographic -serial telnet:127.0.0.1:5555,server,nowait -boot d -m 256 -netdev user,id=net0,hostfwd=tcp::2222-:22 -device e1000,netdev=net0 -enable-kvm

# Step 5: Konfigurasi DHCP client
echo "Mengonfigurasi auto DHCP client di $PORT_ETH..."
cat << EOF > dhcp-client.rsc
/interface ethernet set $PORT_ETH name=ether1
/ip dhcp-client add interface=ether1
EOF
echo "Konfigurasi DHCP client selesai."

# Step 6: Membersihkan file sementara
echo "Membersihkan file sementara..."
progress_bar 10
rm -f $IMAGE_NAME.zip $IMAGE_NAME

# Delay dan reboot
echo "Instalasi selesai. Rebooting dalam 5 detik..."
sleep 5
reboot

```
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ██████╗ ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗            ║
║   ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔══██╗████╗  ██║            ║
║   ██████╔╝██████╔╝ ╚████╔╝ ███████║██╔██╗ ██║            ║
║   ██╔══██╗██╔══██╗  ╚██╔╝  ██╔══██║██║╚██╗██║            ║
║   ██████╔╝██║  ██║   ██║   ██║  ██║██║ ╚████║            ║
║   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝            ║
║                                                          ║
║         PARALEL SPACE - Version 1.0                      ║
╚══════════════════════════════════════════════════════════╝
```


---

## 📋 Ikhtisar

Framework bug bounty yang komprehensif dan modular dirancang untuk peneliti keamanan profesional. Framework ini menyediakan alat yang tersinkronisasi untuk manajemen target, pengintaian (reconnaissance), dan penilaian kerentanan otomatis.

### 🎯 Fitur Utama

- **🔄 Sepenuhnya Tersinkronisasi**: Konfigurasi berbasis lingkungan antar semua alat
- **🏗️ Arsitektur Modular**: Pemisahan yang jelas tanpa duplikasi kode
- **🛡️ Fokus Keamanan**: Pemuatan lingkungan yang aman, tanpa risiko eval(), penanganan kesalahan tingkat enterprise
- **📊 Siap Produksi**: Pencatatan terpusat, mekanisme trap, dan dokumentasi komprehensif
- **🚀 Dapat Diperluas**: Mudah menambahkan alat baru dan mengintegrasikan dengan alur kerja yang ada

---

## 🛠️ Alat yang Tersedia

### 1. **target.sh** - Alat Manajemen Target
- **Tujuan**: Membuat dan mengelola lingkungan target bug bounty
- **Fitur**:
  - Pembuatan struktur direktori otomatis
  - Pembuatan berkas lingkungan (.env)
  - Aktivasi/deaktivasi target
  - Dokumentasi komprehensif (README.md, notes.txt)
  - Validasi direktori target (cegah root/home)
  - Dukungan CLI flags (--force, --silent, --help, --version)
- **Versi**: 2.2 (Siap Produksi)

### 2. **recon.sh** - Alat Pengintaian (Reconnaissance)
- **Tujuan**: Enumerasi subdomain otomatis dan pengintaian
- **Fitur**:
  - Enumerasi pasif (subfinder, assetfinder, chaos-client)
  - Brute force aktif (shuffledns, puredns)
  - Pemeriksaan subdomain live (httpx)
  - Pemilihan mode cerdas (passive/active/auto)
  - Pembatasan laju (rate limiting) DNS
  - Output JSON opsional
  - Optimasi performa (cache file counts)
- **Versi**: 2.2 (Siap Produksi)

### 🔮 Alat Masa Depan (Segera Hadir)
- **scan.sh** - Orkestrator Pemindaian Kerentanan
- **report.sh** - Pembuatan Laporan Otomatis
- **monitor.sh** - Pemantauan & Peringatan Target
- **exploit.sh** - Manajemen Bukti Konsep (PoC)

---

## 📦 Instalasi

### Prasyarat

```bash
# Alat yang Diperlukan
go install -u github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -u github.com/tomnomnom/assetfinder@latest
go install -u github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -u github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
go install -u github.com/projectdiscovery/puredns/v2/cmd/puredns@latest

# Alat Opsional
go install -u github.com/projectdiscovery/chaos-client/cmd/chaos@latest
go install -u github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -u github.com/ffuf/ffuf@latest

# Wordlist & Sumber Daya
sudo apt update && sudo apt install -y seclists
```

### Penyiapan

```bash
# Klon repositori
git clone https://github.com/Brynnnn12/tools-hunting.git
cd tools-hunting

# Buat script dapat dieksekusi
chmod +x *.sh

# Opsional: Tambahkan ke PATH
echo 'export PATH="$PWD:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

---

## 🚀 Mulai Cepat

### 1. Buat Target Baru

```bash
# Buat lingkungan target untuk example.com
./target.sh new example.com
```

**Output:**
```
✅ Target dibuat: example.com
📂 Lokasi: /home/user/bugbounty/targets/example.com
```

### 2. Arahkan ke Direktori Target

```bash
cd /home/user/bugbounty/targets/example.com
```

### 3. Muat Lingkungan

```bash
source .env
```

**Variabel Lingkungan Dimuat:**
- `TARGET=example.com`
- `BASE_DIR=/home/user/bugbounty/targets/example.com`
- `RECON_DIR=${BASE_DIR}/recon`
- `SCANS_DIR=${BASE_DIR}/scans`
- `LOGS_DIR=${BASE_DIR}/logs`

### 4. Jalankan Pengintaian

```bash
# Jalankan dari direktori target
../recon.sh

# Atau tentukan opsi
../recon.sh --mode full --rate 100
```

### 5. Lihat Hasil

```bash
# Periksa subdomain yang ditemukan
cat recon/all_subdomains.txt
cat recon/live_subdomains.txt

# Lihat log eksekusi
cat logs/recon.log
```

---

## 📁 Struktur Direktori

```
bugbounty/
├── targets/                    # Lingkungan target (dibuat oleh target.sh)
│   └── example.com/
│       ├── recon/              # Hasil enumerasi
│       │   ├── passive_subdomains.txt
│       │   ├── active_subdomains.txt
│       │   ├── all_subdomains.txt
│       │   └── live_subdomains.txt
│       ├── scans/              # Hasil pemindaian alat
│       ├── screenshots/        # Bukti PoC
│       ├── reports/            # Laporan & draft
│       ├── logs/               # Log eksekusi
│       │   └── recon.log
│       ├── .env                # Variabel lingkungan (chmod 600)
│       ├── notes.txt           # Dokumentasi
│       ├── README.md           # Dok khusus target
│       └── status.txt          # Status target
├── tools-hunting/              # Akar framework
│   ├── target.sh               # Manajemen target
│   ├── recon.sh                # Pengintaian
│   ├── README.md               # Berkas ini
│   └── [future_tools.sh]       # Akan datang
└── .config/
    └── recon/                  # Sumber daya bersama
        ├── resolvers.txt       # DNS resolver
        └── wordlist.txt        # Wordlist subdomain
```

---

## 🎮 Panduan Penggunaan

### Perintah target.sh

```bash
# Buat target baru
./target.sh new <domain>

# Daftar semua target
./target.sh list

# Aktifkan target
./target.sh activate <domain>

# Nonaktifkan target
./target.sh deactivate <domain>

# Hapus target (tidak dapat dikembalikan)
./target.sh delete <domain>

# Tampilkan bantuan
./target.sh --help

# Tampilkan versi
./target.sh --version

# Buat dengan flag force (lewati prompt)
./target.sh new <domain> --force
```

### Opsi recon.sh

```bash
# Penggunaan dasar (mode auto)
./recon.sh

# Hanya enumerasi pasif
./recon.sh --mode passive

# Enumerasi penuh (pasif + aktif)
./recon.sh --mode full

# Batas laju kustom
./recon.sh --rate 200

# Mode senyap (tanpa warna)
./recon.sh --silent

# Output JSON
./recon.sh --json

# Bantuan
./recon.sh --help

# Versi
./recon.sh --version
```

### Konfigurasi Lingkungan

Edit `.env` di direktori target untuk menyesuaikan:

```bash
# Pengaturan pengintaian
export RATE_LIMIT=100          # Batas laju kueri DNS
export MODE="auto"             # auto/passive/full
export TOOL_VERSION="1.0"

# Kunci API (simpan dengan aman!)
export CHAOS_KEY="your_key_here"
export SHODAN_KEY="your_key_here"

# Jalur sumber daya
export RESOURCE_DIR="${HOME}/.config/recon"
```

---

## 🔧 Konfigurasi

### Konfigurasi Global

```bash
# Atur penulis default
export AUTHOR="Nama Anda"

# Direktori target kustom
export TARGETS_DIR="/path/to/targets"

# Versi alat
export TOOL_VERSION="1.0"

# Direktori sumber daya
export RESOURCE_DIR="${HOME}/.config/recon"
```

### Konfigurasi Khusus Alat

Setiap alat membaca dari berkas `.env` target untuk konfigurasi yang tersinkronisasi.

---

## 📈 Berkas Output

### Hasil Pengintaian
- `recon/all_subdomains.txt` - Semua subdomain unik yang ditemukan
- `recon/live_subdomains.txt` - Subdomain live dengan detail HTTP
- `recon/passive_subdomains.txt` - Hasil enumerasi pasif
- `recon/active_subdomains.txt` - Hasil brute force aktif

### Log & Pemantauan
- `logs/recon.log` - Log eksekusi terperinci dengan stempel waktu
- `logs/setup.log` - Log pembuatan target (global)

### Dokumentasi
- `notes.txt` - Catatan manual dan temuan
- `README.md` - Dokumentasi khusus target
- `reports/` - Draft laporan dan writeup
- `screenshots/` - Bukti PoC visual

---

## 🛠️ Alat yang Terintegrasi

### Alat Inti
- **Subfinder** - Enumerasi subdomain pasif
- **Assetfinder** - Penemuan aset
- **Chaos Client** - Dataset chaos ProjectDiscovery
- **Shuffledns** - Brute force subdomain aktif
- **Puredns** - Resolusi DNS dengan filter wildcard
- **Httpx** - Probing HTTP dan pemeriksaan status

### Integrasi Masa Depan
- **Nuclei** - Pemindaian kerentanan
- **Nmap** - Pemindaian port
- **FFUF** - Fuzzing direktori
- **SQLMap** - Pengujian injeksi SQL
- **Dirbuster** - Enumerasi direktori

---

## 🔐 Fitur Keamanan

- **Pemuatan Lingkungan Aman**: Tidak ada penggunaan eval(), parsing berbasis sed
- **Validasi Masukan**: Sanitasi domain dan validasi
- **Penanganan Kesalahan**: Penanganan kesalahan komprehensif dengan nomor baris
- **Manajemen Kunci API Aman**: Manajemen kunci berbasis lingkungan
- **Log Audit**: Semua tindakan dicatat dengan stempel waktu
- **Izin File**: .env dilindungi dengan chmod 600 (pengguna saja baca/tulis)
- **Parsing Whitelist**: Hanya membaca variabel yang diketahui (tidak ada injeksi)

---

## 🚨 Troubleshooting

### Masalah Umum

**Error "Tool not found":**
```bash
# Instal alat yang hilang
go install -u github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

**Permission denied (Izin ditolak):**
```bash
chmod +x *.sh
```

**Lingkungan tidak dimuat:**
```bash
# Pastikan Anda berada di direktori target
cd /path/to/target
source .env
```

**Masalah pembatasan laju:**
```bash
# Kurangi batas laju di .env
export RATE_LIMIT=25
```

### Mode Debug

Aktifkan pencatatan verbose:
```bash
export DEBUG=true
./recon.sh
```

### Cek Alat

```bash
# Verifikasi alat dipasang dengan benar
which subfinder
which assetfinder
which httpx
which puredns
```

---

## 🤝 Berkontribusi

### Menambahkan Alat Baru

1. **Ikuti Pola Framework:**
   - Gunakan `.env` untuk konfigurasi
   - Terapkan pencatatan terpusat
   - Tambahkan penanganan kesalahan trap
   - Buat dokumentasi komprehensif

2. **Standar Kode:**
   - Mode strict Bash: `set -euo pipefail`
   - Fungsi modular
   - Kode warna konsisten
   - Pendekatan security-first

3. **Dokumentasi:**
   - Perbarui README.md ini
   - Tambahkan bantuan khusus alat
   - Sertakan contoh penggunaan

### Alur Kerja Pengembangan

```bash
# Buat cabang fitur
git checkout -b feature/new-tool

# Uji secara menyeluruh
./new_tool.sh --help

# Perbarui dokumentasi
vim README.md

# Komit perubahan
git commit -am "Add new_tool.sh"

# Push dan buat PR
git push origin feature/new-tool
```

---

## 📈 Roadmap

### Versi 1.0 (SAAT INI) ✅
- [x] Optimasi performa (cache file counts)
- [x] Output JSON opsional
- [x] Validasi target directory (cegah root/home)
- [x] CLI flags lengkap (--force, --silent, --help, --version)
- [x] Printf conversion (kompatibel macOS/Linux/WSL)
- [x] Mktemp untuk operasi file (portabilitas)

### Versi 1.1 (Direncanakan)
- [ ] scan.sh - Orkestrator pemindaian kerentanan
- [ ] Pembuatan laporan otomatis
- [ ] Integrasi Slack/Discord
- [ ] Progress bar yang ditingkatkan

### Versi 3.0 (Visi Jangka Panjang)
- [ ] Antarmuka web
- [ ] Kampanye multi-target
- [ ] Analytics lanjutan
- [ ] Dashboard real-time

### Fitur Komunitas
- [ ] Sistem plugin
- [ ] Manajemen wordlist kustom
- [ ] Sistem template untuk laporan

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah Lisensi MIT - lihat berkas LICENSE untuk detail.

---

## 🙏 Penghargaan

- **ProjectDiscovery** - Untuk alat keamanan yang luar biasa
- **Tomnomnom** - Assetfinder dan utilitas lainnya
- **OWASP** - Komunitas riset keamanan
- **Bug Bounty Hunters** - Untuk inspirasi dan umpan balik
- **Komunitas Open Source** - Untuk kontribusi berkelanjutan

---

## 📞 Dukungan

- **Issues (Masalah)**: [GitHub Issues](https://github.com/Brynnnn12/tools-hunting/issues)
- **Diskusi**: [GitHub Discussions](https://github.com/Brynnnn12/tools-hunting/discussions)
- **Dokumentasi**: README ini dan bantuan khusus alat
- **Email**: Hubungi melalui GitHub

---

## 📅 Catatan Rilis

### v1.0 (Siap Produksi)
- ✅ Optimasi performa lengkap
- ✅ Kompatibilitas cross-platform terjamin
- ✅ CLI lengkap dengan bantuan built-in
- ✅ Output JSON untuk automasi
- ✅ Validasi keamanan yang ditingkatkan

### v0.9 (Beta)
- ✅ Konfigurasi berbasis .env
- ✅ Pencatatan terpusat
- ✅ Mode multi-enumeration

---

**Selamat Berburu! 🐛🔍**

*Dibuat dengan ❤️ oleh BRYNNNN12*
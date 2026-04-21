# RECON Tool - Enumerasi Subdomain & Reconnaissance

[![Bash](https://img.shields.io/badge/Bash-4.0%2B-blue.svg)](https://www.gnu.org/software/bash/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

Script Bash yang powerful dan otomatis untuk enumerasi subdomain dan reconnaissance secara komprehensif menggunakan berbagai teknik passive dan active.

## 🎯 Fitur

- **Enumerasi Passive Multi-Sumber**: Menggabungkan hasil dari subfinder, assetfinder, dan chaos-client
- **Brute Force Active**: Menggunakan shuffledns dengan wordlist yang dapat dikustomisasi
- **Permutasi Pintar**: Menghasilkan dan menguji permutasi subdomain menggunakan altdns
- **Resolusi DNS & Filtering**: Memvalidasi subdomain dan memfilter hasil wildcard
- **Pengecekan Subdomain Live**: Menguji ketersediaan HTTP/HTTPS dengan httpx
- **Auto-Detection**: Otomatis mendeteksi binary altdns di lokasi umum
- **Resume Capability**: Dapat melanjutkan scan yang terinterupsi
- **Konfigurasi Environment**: Sepenuhnya dapat dikonfigurasi via file .env
- **Progress Tracking**: Progress bar real-time dan logging detail
- **Production Ready**: Error handling yang robust dan mekanisme retry

## 🛠️ Tools yang Digunakan

- [subfinder](https://github.com/projectdiscovery/subfinder) - Enumerasi subdomain passive
- [assetfinder](https://github.com/tomnomnom/assetfinder) - Penemuan subdomain berbasis asset
- [chaos-client](https://github.com/projectdiscovery/chaos-client) - Enumerasi dataset Chaos
- [shuffledns](https://github.com/projectdiscovery/shuffledns) - Brute force active
- [altdns](https://github.com/infosec-au/altdns) - Permutasi subdomain
- [puredns](https://github.com/d3mondev/puredns) - Resolusi DNS dan filtering wildcard
- [httpx](https://github.com/projectdiscovery/httpx) - Pengecekan subdomain live

## 📋 Persyaratan

- **Bash 4.0+**
- **Go 1.19+** (untuk menginstall tools)
- **Python 3.x** (untuk altdns)
- **curl** (untuk mendownload resolvers)

## 🚀 Instalasi

### 1. Clone Repository
```bash
git clone https://github.com/yourusername/recon-tool.git
cd recon-tool
```

### 2. Install Tools yang Dibutuhkan
```bash
# Install tools Go
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/chaos-client/cmd/chaos@latest
go install github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest
go install github.com/d3mondev/puredns/v2@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest

# Install tools Python
pip install altdns
```

### 3. Jadikan Script Executable
```bash
chmod +x recon.sh
```

## ⚙️ Konfigurasi

### Environment Variables (.env)

Buat file `.env` di direktori yang sama dengan script:

```bash
# Chaos API Key untuk chaos-client
CHAOS_KEY=your_actual_api_key_here

# Variabel konfigurasi (opsional, akan menggunakan default jika tidak diset)
RATE_LIMIT=50                    # Batas rate query DNS
MODE=auto                        # Mode scan: auto/passive/full
TOOL_VERSION=1.0                 # Versi tool
LOG_DIR=logs                     # Nama direktori log
RESOURCE_DIR=$HOME/.config/recon # Direktori untuk file shared (resolvers.txt, wordlist.txt)
ALT_DNS_PATH=                    # Path custom ke binary altdns (kosongkan untuk auto-detection)
```

### File Shared

Script otomatis mengelola file shared di `~/.config/recon/`:
- `resolvers.txt` - DNS resolvers (auto-download)
- `wordlist.txt` - Wordlist default untuk brute force

## 📖 Cara Penggunaan

### Penggunaan Dasar
```bash
./recon.sh example.com
```

### Penggunaan Lanjutan
```bash
# Mode passive saja
./recon.sh --domain example.com --mode passive

# Scan penuh dengan direktori output custom
./recon.sh --domain example.com --mode full --output hasil_scan_saya

# Rate limit tinggi untuk scanning lebih cepat
./recon.sh --domain example.com --rate 100

# Path altdns custom
./recon.sh --domain example.com --altdns-path /path/to/altdns

# Mode silent (tanpa output berwarna)
./recon.sh --domain example.com --silent
```

### Opsi Command Line

| Opsi | Deskripsi | Default |
|------|-----------|---------|
| `--domain <domain>` | Domain target (wajib) | - |
| `--output <dir>` | Direktori output | auto-generated |
| `--rate <number>` | Batas rate query DNS | 50 |
| `--mode <mode>` | Mode scan (auto/passive/full) | auto |
| `--altdns-path <path>` | Path custom binary altdns | auto-detect |
| `--silent` | Mode silent (tanpa warna) | false |
| `--help, -h` | Tampilkan pesan bantuan | - |
| `--version` | Tampilkan versi | - |

### Mode Scan

- **auto**: Otomatis memilih antara passive dan full berdasarkan hasil passive
- **passive**: Hanya enumerasi passive (aman, tanpa active scanning)
- **full**: Scan lengkap termasuk active brute force dan permutasi

## 📁 Struktur Output

```
recon_example.com/
├── passive/
│   ├── subfinder.txt           # hasil subfinder
│   ├── assetfinder.txt         # hasil assetfinder
│   ├── chaos.txt              # hasil chaos-client
│   ├── passive_all.txt        # gabungan hasil passive
│   └── resolved.txt           # subdomain yang tervalidasi
├── active/
│   ├── brute_temp.txt         # hasil brute force mentah
│   └── brute_resolved.txt     # hasil brute force tervalidasi
├── permutation/
│   ├── custom_words.txt       # wordlist custom dari hasil passive
│   ├── final_wordlist.txt     # wordlist gabungan
│   ├── permutasi_temp.txt     # hasil permutasi mentah
│   ├── permutasi_final.txt    # hasil permutasi final
│   ├── permutasi_clean.txt    # permutasi terfilter
│   └── permutasi_resolved.txt # permutasi tervalidasi
├── final/
│   ├── all_subdomains.txt     # semua subdomain unik
│   └── live_subdomains.txt    # subdomain live dengan info HTTP
└── logs/
    └── recon.log              # log eksekusi detail
```

## 📊 Contoh Output

```
════════════════════════════════════════════════════════════
🎯 TARGET DOMAIN: example.com
📁 OUTPUT DIRECTORY: recon_example.com
════════════════════════════════════════════════════════════

🕵️  PASSIVE ENUMERATION (Mencari subdomain dari sumber publik)...
   🔍 Menjalankan subfinder...
      ✅ subfinder menemukan 45 subdomain
   🔍 Menjalankan assetfinder...
      ✅ assetfinder menemukan 23 subdomain
   🔍 Menjalankan chaos-client...
      ✅ chaos-client menemukan 12 subdomain

   📊 TOTAL PASSIVE UNIQUE: 67 subdomain

✅ AUTO mode: Hasil passive cukup, tetap PASSIVE mode

🔍 RESOLVE & WILDCARD FILTERING (Memfilter subdomain palsu)...
   🧹 Menjalankan puredns untuk filtering wildcard...
      ✅ Subdomain valid: 62

📦 MENGGABUNGKAN SEMUA HASIL...
   📊 FINAL SUBDOMAIN COUNT: 62

🌐 MENGECEK SUBDOMAIN LIVE (HTTP/HTTPS)...
   🚀 Menjalankan httpx untuk cek live...
      ✅ Subdomain live: 58

════════════════════════════════════════════════════════════
📋 RINGKASAN HASIL RECONNAISSANCE
════════════════════════════════════════════════════════════

   📊 STATISTIK:
      ├── Passive enumeration : 67 subdomain
      ├── Active brute force  : 0 subdomain
      ├── Permutasi           : 0 subdomain
      ├── TOTAL UNIQUE        : 62 subdomain
      └── LIVE SUBDOMAIN      : 58 subdomain

   ⏱️  WAKTU EKSEKUSI: 2 menit 34 detik
```

## 🔧 Troubleshooting

### Masalah Umum

1. **Tools tidak ditemukan**
   ```bash
   # Cek apakah tools sudah terinstall
   which subfinder assetfinder chaos shuffledns puredns httpx altdns
   ```

2. **Permission denied**
   ```bash
   chmod +x recon.sh
   ```

3. **altdns tidak ditemukan**
   ```bash
   # Install altdns
   pip install altdns

   # Atau tentukan path custom
   ./recon.sh --domain example.com --altdns-path /path/to/altdns
   ```

4. **CHAOS_KEY tidak diset**
   ```bash
   # Tambahkan ke file .env
   echo "CHAOS_KEY=your_api_key_here" >> .env
   ```

### Mode Debug

Aktifkan logging detail dengan mengecek file `logs/recon.log` di direktori output.

## 🤝 Contributing

1. Fork repository
2. Buat feature branch (`git checkout -b feature/fitur-hebat`)
3. Commit perubahan Anda (`git commit -m 'Tambah fitur hebat'`)
4. Push ke branch (`git push origin feature/fitur-hebat`)
5. Buka Pull Request

## 📄 Lisensi

Project ini dilisensikan di bawah MIT License - lihat file [LICENSE](LICENSE) untuk detail.

## ⚠️ Disclaimer

Tools ini untuk tujuan pendidikan dan penelitian keamanan etis saja. Pengguna bertanggung jawab untuk mematuhi hukum dan regulasi yang berlaku. Penulis tidak bertanggung jawab atas penyalahgunaan atau aktivitas ilegal.

## 🙏 Acknowledgments

- [ProjectDiscovery](https://github.com/projectdiscovery) untuk tools keamanan yang excellent
- [Tom Hudson](https://github.com/tomnomnom) untuk assetfinder
- [Infosec AU](https://github.com/infosec-au) untuk altdns
- Semua kontributor dan komunitas penelitian keamanan

---

**Dibuat dengan ❤️ oleh BRYNNNN12**
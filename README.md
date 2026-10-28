# Termux AI Tools 🚀

Kumpulan skrip instalasi, auto-updater, backup/restore pengaturan, dan paket DEBIAN (.deb) untuk menjalankan **OpenCode v1**, **OpenCode v2**, dan **Antigravity CLI (agy)** di lingkungan **Termux (Android)** menggunakan runtime **glibc**.

---

## ⚡ Instalasi Cepat (One-Liner)

Jalankan perintah ini di terminal Termux Anda:

```bash
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash
```

Perintah di atas akan menampilkan menu interaktif lengkap:
1. **Install / Update OpenCode v1** (versi upstream `v1.19.4`)
2. **Install / Update OpenCode v2** (versi upstream `v2.2.0` glibc + patchelf)
3. **Install / Update Antigravity CLI** (`agy v1.3.5` build stabil dengan memory patch)
4. **Install / Update Semua Tools**
5. **Cek Status & Versi Terpasang**
6. **Wizard Setup Provider & API Key (config.sh)**
7. **Manajemen Sesi & Optimasi DB Storage (session.sh)**
8. **Diagnostik & Health Check Lingkungan (Doctor)**
9. **Export (Backup) Pengaturan & Token ke Arsip (.tar.gz)**
10. **Restore Pengaturan dari File Backup**
11. **Manajemen Background Web Service (service.sh)**
12. **Pasang Shortcut Cepat (Perintah 'ai', widget, aliases)**
13. **Uninstall Tools (Hapus biner / data)**
14. **Keluar**

---

## 🛠️ Instalasi Langsung via Argumen

Jika ingin langsung memasang atau memperbarui salah satu tool tanpa melalui menu interaktif:

```bash
# Pasang / Update OpenCode v1
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- opencode

# Pasang / Update OpenCode v2
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- opencode-v2

# Pasang / Update Antigravity CLI saja
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- agy

# Pasang / Update Semua Sekaligus
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- all
```

---

## 🔄 Pembaruan (Update Checker)

Skrip `update.sh` secara otomatis membandingkan versi yang terpasang di Termux Anda dengan rilis resmi terbaru di GitHub / npm:

```bash
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/update.sh | bash
```

Atau jika repo sudah di-clone secara lokal:
```bash
./update.sh
```

Contoh tampilan output:
```text
Rilis Terbaru di GitHub Upstream (anomalyco/opencode):
  • v2.2.0
  • v1.19.4
  • v1.19.3
  • v1.19.2

Ringkasan Status di Termux Anda:
Software           | Terpasang        | Upstream         | Status    
----------------------------------------------------------------------
OpenCode v1        | 1.19.4           | 1.19.4           | Up-to-date
OpenCode v2        | 2.2.0            | 2.2.0            | Up-to-date
Antigravity CLI    | 1.3.5            | 1.4.8            | Stabil (1.3.5)
----------------------------------------------------------------------
```

---

## 🩺 Diagnostik & Health Doctor (`doctor.sh`)

Periksa kondisi kesehatan sistem Termux, status dynamic linker `glibc`, sertifikat TLS, risiko Android OOM Killer, ketersediaan RAM/Swap, dan integritas autentikasi:

```bash
# Jalankan langsung dari web:
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- doctor

# Atau secara lokal:
./doctor.sh

# Perbaikan otomatis masalah yang ditemukan:
./doctor.sh --fix
```

Contoh keluaran diagnostik:
```text
==================================================
    🩺 Termux AI Tools - System & Health Doctor    
==================================================

1. Sistem & Arsitektur:
  [✔ PASS] Arsitektur CPU: aarch64 (ARM64)
  [✔ PASS] Kernel Linux: 4.14.190
  [✔ PASS] Ruang Penyimpanan: 15 GB bebas

2. Lingkungan glibc & Dynamic Linker:
  [✔ PASS] glibc dynamic loader: /data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1
  [✔ PASS] glibc core libraries: libc.so.6 terdeteksi
  [✔ PASS] Dependensi binary: clang, curl, tar, python, patchelf

3. Jaringan & Sertifikat TLS/SSL:
  [✔ PASS] TLS/SSL Certificate: /data/data/com.termux/files/usr/etc/tls/cert.pem (196K)
  [✔ PASS] Koneksi HTTPS ke GitHub API & npm: Normal (200/OK)

4. Analisis Memori RAM & Swap (OOM Prevention):
  [✔ PASS] RAM Tersedia: 3.4 GB / 7.5 GB (Sangat aman untuk LLM agent)
  [✔ PASS] Swap / zRAM: 2.1 GB bebas / 4.0 GB

5. Status & Integritas Biner AI Tools:
  [✔ PASS] OpenCode v1: Terpasang (v1.19.4)
  [✔ PASS] OpenCode v2: Terpasang (opencode v2.2.0)
  [✔ PASS] Antigravity CLI (agy): Terpasang (v1.3.5)

6. Status Kredensial & Autentikasi:
  [✔ PASS] OpenCode Auth: Terkonfigurasi (Provider: google)
  [✔ PASS] Antigravity OAuth Token: Tersedia & aman (chmod 600)

Skor Kesehatan : 100%
🎉 SEMUA SISTEM NORMAL! Lingkungan Termux AI Tools 100% prima.
```

---

## 🚀 Quick Launcher & Android Shortcuts (`setup-shortcuts.sh`)

Sistem peluncur cepat terintegrasi untuk kenyamanan penggunaan AI coding agent di perangkat Android:

```bash
# Pasang perintah 'ai', alias shell, dan widget Termux:
./setup-shortcuts.sh

# Atau langsung dari web:
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/setup-shortcuts.sh | bash
```

### Fitur yang Disediakan:
1. **Perintah Global `ai`**:
   - `ai` : Buka menu interaktif peluncur AI.
   - `ai oc [args...]` : Jalankan OpenCode v1 secara langsung.
   - `ai oc2 [args...]` : Jalankan OpenCode v2 secara langsung.
   - `ai agy [args...]` : Jalankan Antigravity CLI secara langsung.
   - `ai web` : Jalankan OpenCode Web UI mode di browser.
   - `ai doc` : Jalankan diagnostik kesehatan sistem (Doctor).
   - `ai up` : Cek dan update ke rilis GitHub terbaru.
   - `ai backup` : Export / backup pengaturan dan token.
   - `ai restore` : Restore pengaturan dari berkas backup.
2. **Shell Aliases (`.bashrc` / `.zshrc`)**:
   - `oc` : Shortcut instan untuk `opencode` (v1).
   - `oc2`: Shortcut instan untuk `opencode-v2` (v2).
   - `aidoc`: Shortcut instan untuk `doctor.sh`.
   - `aiup`: Shortcut instan untuk `update.sh`.
3. **Termux:Widget Shortcuts (`~/.shortcuts/`)**:
   - Jika Anda memasang aplikasi **Termux:Widget** dari F-Droid, shortcut berikut otomatis siap digunakan di homescreen HP:
     - `AI-Menu.sh` (Peluncur AI satu ketukan)
     - `AI-Web.sh` (Buka Web Server & Browser sekali ketuk)
     - `OpenCode.sh` (Buka OpenCode 1 langsung)
     - `OpenCode-v2.sh` (Buka OpenCode 2 langsung)
     - `Antigravity-CLI.sh` (Buka AGY langsung)
     - `AI-Doctor.sh` (Cek kesehatan sistem)

---

## 🌐 Background Web Service Manager (`service.sh`)

Jalankan OpenCode Web / Serve di latar belakang (daemon) dan buka antarmuka Web UI di browser Android (Chrome / default) secara otomatis:

```bash
# Menampilkan menu interaktif Web Service Manager:
./service.sh

# Menjalankan OpenCode v2 Web Service & otomatis buka browser:
./service.sh start v2

# Menjalankan OpenCode v1 Web Service & otomatis buka browser:
./service.sh start v1

# Memeriksa status dan pemakaian memori server:
./service.sh status

# Melihat log server secara real-time:
./service.sh logs v2 -f

# Membuka kembali halaman Web UI di browser Android:
./service.sh open v2

# Menghentikan layanan:
./service.sh stop v2
./service.sh stop all
```

Contoh tampilan status:
```text
=== Status Background Web Services ===

Layanan         | Status                 | PID      | Port   | URL                      
------------------------------------------------------------------------------------
opencode-v1     | STOPPED                | -        | -      | -                        
opencode-v2     | RUNNING (140MB RAM)    | 24064    | 4097   | http://127.0.0.1:4097    
------------------------------------------------------------------------------------
```


---

## 🔑 Wizard Setup API Key & Provider (`config.sh`)

Kelola API key penyedia AI dan model default dengan mudah, aman, dan interaktif:

```bash
# Menjalankan Interactive Config Wizard:
config.sh
# Atau:
ai config
# Atau:
aiconfig
```

### Kemampuan & Perintah CLI Cepat:

| Perintah | Deskripsi |
| :--- | :--- |
| `config.sh list` (atau `aiconfig`) | Menampilkan tabel status provider aktif, masked API key, dan model aktif |
| `config.sh set <provider> [key]` | Menyimpan / memperbarui API key ke `~/.local/share/opencode/auth.json` |
| `config.sh get <provider>` | Menampilkan masked API key untuk provider tertentu |
| `config.sh model [model_id]` | Menampilkan atau mengatur default model di `~/.config/opencode/opencode.jsonc` |
| `config.sh test [provider]` | Menguji validitas koneksi & API key secara langsung via HTTP (HTTP 200 OK) |
| `config.sh sync-env` | Mengekspor API keys ke `~/.termux_ai_env` (bisa di-source oleh `~/.bashrc`) |
| `config.sh remove <provider>` | Menghapus kredensial provider dari sistem |

### Provider yang Didukung Secara Langsung:
- 🌐 **Google Gemini** (`google`): `google/gemini-2.5-flash`, `google/gemini-2.5-pro`
- 🧠 **Anthropic Claude** (`anthropic`): `anthropic/claude-3-7-sonnet`, `anthropic/claude-3-5-sonnet`
- ⚡ **OpenAI** (`openai`): `openai/gpt-4.5-preview`, `openai/gpt-4o`, `openai/o3-mini`
- 🐋 **DeepSeek** (`deepseek`): `deepseek/deepseek-chat`, `deepseek/deepseek-reasoner`
- 🔀 **OpenRouter** (`openrouter`): `openrouter/auto`, ratusan model lewat satu API key
- 🚀 **Groq** (`groq`): `groq/llama-3.3-70b-versatile`, inferensi ultra-cepat
- 🌪️ **Mistral AI** (`mistral`): `mistral/mistral-large-latest`, `mistral/codestral-latest`
- 🤖 **xAI (Grok)** (`xai`): `xai/grok-2-latest`, `xai/grok-beta`
- ⚙️ **Custom Provider**: Masukkan provider atau base URL kustom pilihan Anda.

### Contoh Tampilan Status:
```text
======================================================================
              DAFTAR PROVIDER & STATUS API KEY TERPASANG              
======================================================================
🎯 Model Aktif (opencode.jsonc): google/gemini-2.5-flash

PROVIDER         NAMA                 STATUS       API KEY (MASKED)    
----------------------------------------------------------------------
google           Google Gemini        [ AKTIF ]    AIzaSyAT...3g4k     
anthropic        Anthropic Claude     [ BELUM ]    -                   
openai           OpenAI               [ BELUM ]    -                   
deepseek         DeepSeek             [ BELUM ]    -                   
openrouter       OpenRouter           [ BELUM ]    -                   
groq             Groq                 [ BELUM ]    -                   
mistral          Mistral AI           [ BELUM ]    -                   
xai              xAI (Grok)           [ BELUM ]    -                   
----------------------------------------------------------------------
```

### Keamanan & Privasi:
- Input API key menggunakan mode silent input (`read -s`) sehingga tidak tercatat di history bash.
- Output terminal otomatis dimasking (`AIzaSy...3g4k`), tidak pernah menampilkan plain text key.
- File `auth.json` dan `~/.termux_ai_env` otomatis diberi hak akses `chmod 600` (hanya bisa dibaca oleh pemilik akun).
- Backup otomatis (`auth.json.bak` & `opencode.jsonc.bak`) dibuat setiap kali konfigurasi diubah.

---

## 🔄 Session & Context Manager (`session.sh`)

Kelola riwayat percakapan, cari topik lama, ekspor sesi ke catatan Markdown (.md), dan bebaskan **ratusan MB hingga Gigabyte memori internal HP** dengan pembersihan log serta SQLite `VACUUM`:

```bash
# Buka menu interaktif Session Manager:
session.sh
# Atau via launcher cepat:
ai session
# Atau alias:
aisess
```

### Kemampuan & Perintah CLI Cepat:

| Perintah | Deskripsi |
| :--- | :--- |
| `session.sh status` (atau `aisession`) | Menampilkan analisis pemakaian memori database, sesi tersimpan, dan potensi dead space |
| `session.sh list [limit]` | Menampilkan daftar sesi percakapan terbaru (OpenCode & Antigravity) |
| `session.sh search <kata_kunci>` | Mencari sesi berdasarkan kata kunci pada judul percakapan, prompt, atau ID |
| `session.sh info <id_sesi>` | Menampilkan metadata lengkap sesi (model, jumlah pesan, parts, token, biaya) |
| `session.sh export <id_sesi>` | Mengekspor sesi percakapan ke file dokumen Markdown (`.md`) dan disalin ke Download HP |
| `session.sh clean` | Membersihkan berkas log debug dan temporary snapshot/output (`~50 MB+`) |
| `session.sh vacuum` | Menjalankan SQLite `VACUUM` untuk mengompresi DB dan mengembalikan storage ke Android (`1 GB+`) |
| `session.sh prune --days <N>` | Menghapus sesi lama yang lebih tua dari N hari dan otomatis menjalankan VACUUM |
| `session.sh prune --keep <N>` | Menyisakan N sesi percakapan terbaru dan menghapus sisanya secara aman |
| `session.sh resume <id_sesi>` | Melanjutkan percakapan lama secara langsung di OpenCode |

### Contoh Tampilan Analisis Storage:
```text
======================================================================
           ANALISIS PENYIMPANAN SESI & KONTEKS AI (STORAGE)           
======================================================================
1. OpenCode Storage:
  • Database Utama (opencode.db) : 338.0 MB (151 sesi, 12756 pesan)
  • SQLite WAL Temporary Cache   : 11.6 MB
  • Log & Riwayat Debug          : 20.7 MB
  • Tool Output & Snapshot Cache : 8.8 MB
  • Ruang Kosong (Dead Pages)    : 1007.7 MB (Bisa dibebaskan dengan VACUUM)

2. Antigravity CLI (agy) Storage:
  • File Sesi Percakapan (.db/.pb): 310.6 MB (43 ringkasan)
  • Brain Context & Scratchpad   : 176.0 MB
  • Log Riwayat Eksekusi         : 20.7 MB
----------------------------------------------------------------------
📁 Total Penggunaan Storage AI   : 1.86 GB
✨ Potensi Pembebasan Ruang Disk : ~1.03 GB
   (Pembersihan Log/Cache: 50.2 MB + SQLite VACUUM: 1007.7 MB)
======================================================================
```

---

## 💾 Export & Restore Pengaturan (Backup Settings)

Simpan token OAuth, API keys, konfigurasi model, dan custom skills/plugins Anda sebelum ganti HP atau membersihkan Termux:

### 1. Export (Backup) Pengaturan
```bash
# Jalankan langsung dari web:
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- export

# Atau secara lokal:
./backup.sh export
```
File backup (misal `termux-ai-backup-YYYYMMDD_HHMMSS.tar.gz`) akan dibuat di folder saat ini dan secara otomatis disalinkan ke direktori internal `/sdcard/Download/` agar aman jika Termux di-reinstall.

Yang diamankan:
- `OpenCode`: `~/.config/opencode/`, `~/opencode.jsonc`, dan riwayat sesi.
- `Antigravity CLI`: `~/.gemini/settings.json`, token OAuth login (`antigravity-oauth-token`), custom skills, hooks, dan plugin data.

### 2. Restore Pengaturan dari Backup
```bash
# Jalankan menu restore:
./backup.sh restore

# Atau sebutkan nama file backup secara langsung:
./backup.sh restore /sdcard/Download/termux-ai-backup-20261027_103000.tar.gz
```

---

## 🗑️ Uninstall Tools

Hapus biner wrapper dan file library dari sistem:

```bash
# Jalankan menu uninstaller:
./uninstall.sh

# Atau hapus tool tertentu:
./uninstall.sh opencode      # Hapus OpenCode v1
./uninstall.sh opencode-v2   # Hapus OpenCode v2
./uninstall.sh agy           # Hapus Antigravity CLI
./uninstall.sh all           # Hapus semua tools

# Tambahkan flag --purge jika ingin membersihkan folder konfigurasi/data user juga:
./uninstall.sh all --purge
```

---

## 📦 Paket DEBIAN (.deb)

Repositori ini menyertakan struktur paket DEBIAN (`control`, `postinst`, `preinst`, `postrm`) yang kompatibel dengan APT / DPKG Termux:

- `packages/opencode/DEBIAN/` (Target versi: `1.19.4`)
- `packages/opencode-v2/DEBIAN/` (Target versi: `2.2.0`)
- `packages/antigravity-cli/DEBIAN/` (Target versi: `1.3.5`)

### Cara Build Paket .deb Sendiri:
```bash
git clone https://github.com/ngewa/termux-ai-tools.git
cd termux-ai-tools
bash build-deb.sh
```
File `.deb` hasil kompilasi akan tersimpan di folder `dist/`:
- `dist/opencode_1.19.4_all.deb`
- `dist/opencode-v2_2.2.0_all.deb`
- `dist/antigravity-cli_1.3.5_all.deb`

Untuk menginstall paket hasil build:
```bash
dpkg -i dist/opencode_1.19.4_all.deb
dpkg -i dist/opencode-v2_2.2.0_all.deb
dpkg -i dist/antigravity-cli_1.3.5_all.deb
```

---

## 🤖 GitHub Actions CI/CD & Auto-Release

Repositori ini dilengkapi alur kerja otomatisasi **GitHub Actions** (`.github/workflows/build-deb.yml`):

1. **Auto-Build Setiap Push**:
   - Memvalidasi dan membangun semua paket `.deb` secara otomatis di lingkungan cloud Ubuntu Linux.
   - Mengunggah berkas `.deb` dan `SHA256SUMS.txt` sebagai build artifacts (disimpan selama 30 hari).
2. **Auto-Release ke GitHub Releases**:
   - Setiap kali tag versi baru di-push (misal `git tag v2.2.0 && git push origin v2.2.0`), GitHub Actions akan otomatis membuat entri **GitHub Release** baru.
   - Seluruh file `.deb` dan checksum akan dilampirkan langsung pada rilis tersebut sehingga pengguna dapat mengunduhnya secara langsung tanpa perlu build lokal.
3. **Trigger Rilis Manual (Workflow Dispatch)**:
   - Anda dapat memicu pembuatan rilis secara instan langsung dari terminal menggunakan GitHub CLI:
     ```bash
     gh workflow run build-deb.yml -f create_release=true -f release_tag=v2.2.0
     ```


---

## 🔍 Detail Teknis & Arsitektur

1. **Glibc Wrapper Loader**:
   - OpenCode v1, v2, dan Antigravity CLI didistribusikan sebagai biner Linux glibc ARM64.
   - Karena Android/Termux menggunakan Bionic libc, skrip ini mengompilasi wrapper C ringan (`clang -O2`) yang memanggil glibc dynamic linker (`ld-linux-aarch64.so.1`) secara transparan.

2. **OpenCode 2 patchelf Interpreter**:
   - OpenCode 2 mengemas biner Node/Bun Linux ARM64 melalui npm registry (`@opencode/cli-linux-arm64`).
   - Binary dipatch menggunakan `patchelf --set-interpreter "$LOADER"` agar dapat langsung mengeksekusi dependensi glibc Termux secara andal.

3. **Patching Memori ARM64 untuk Antigravity CLI**:
   - Go runtime ARM64 versi Linux memiliki ekspektasi alokasi ruang alamat memori virtual 48-bit yang berbeda dengan alokasi kernel Android.
   - Pada `install-agy.sh` dan paket DEBIAN `antigravity-cli`, diterapkan patching instruksi ARM64 (rewriting pola opcode dan `immr`/`imms`) sehingga binary aman dari crash `Segmentation Fault`.
   - Versi `1.3.5` dipertahankan sebagai versi default yang stabil dan terverifikasi secara penuh.

---

## 📋 Lisensi
Lisensi MIT - Dibuat untuk memudahkan developer dan komunitas Termux.

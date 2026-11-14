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
8. **Plugin & MCP Tool Installer (plugin.sh)**
9. **Knowledge Memory & AI Brain (memory.sh)**
10. **Manajemen AI Agent Skills (skill.sh) — deteksi Global & Workspace**
11. **Manajemen AI Subagents & Personas (agent.sh)**
12. **Diagnostik & Health Check Lingkungan (Doctor)**
13. **Export (Backup) Pengaturan & Token ke Arsip (.tar.gz)**
14. **Restore Pengaturan dari File Backup**
15. **Manajemen Background Web Service (service.sh)**
16. **Pasang Shortcut Cepat (Perintah 'ai', widget, aliases)**
17. **Uninstall Tools (Hapus biner / data)**
18. **Keluar**

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

## 📖 Panduan Lengkap Semua Perintah (All Commands Reference)

Berikut ringkasan lengkap seluruh perintah (*cheatsheet*), alias cepat, skrip CLI, dan widget yang tersedia di **Termux AI Tools**:

### 1. ⚡ Shell Aliases (Perintah Singkat di Terminal)
Setelah menjalankan `./setup-shortcuts.sh`, alias berikut otomatis aktif di `~/.bashrc` dan `~/.zshrc`:

| Alias | Perintah Asli | Deskripsi Singkat |
| :--- | :--- | :--- |
| `ai` | `ai-launcher.sh` | **Menu Utama**: Buka TUI launcher interaktif untuk semua tool AI |
| `oc` | `opencode "$@"` | Jalankan **OpenCode v1** langsung dengan argumen tambahan |
| `oc2` | `opencode-v2 "$@"` | Jalankan **OpenCode v2** langsung dengan argumen tambahan |
| `aidoc` | `doctor.sh` | Jalankan **Health Doctor** & verifikasi 18 titik sistem |
| `aiup` | `update.sh` | Cek status rilis terbaru upstream dari GitHub & npm |
| `aicfg` | `config.sh` | Buka wizard pengaturan **API Key & Model** AI |
| `aisess` | `session.sh` | Buka manager **Sesi, Pencarian, & SQLite Vacuum** |
| `aiplug` | `plugin.sh` | Buka installer **Plugin & MCP Server** (Android Bridge) |
| `aimem` | `memory.sh` | Buka **Knowledge Memory & AI Brain** (Solusi terverifikasi & FTS5) |
| `aiskill` | `skill.sh` | Buka **AI Agent Skill Manager** (Prompt Master, Antislop, UI/UX) |
| `aiagent` | `agent.sh` | Buka **AI Persona & Subagent Manager** (Roblox, Toolkit, Reverser) |
| `aiacc` | `account.sh` | Buka **Multi-Account & Quota Manager** (Personal/Work, Quota 5h, Rotasi) |
| `ai usage` | `usage-stats.sh` | Tampilkan **Usage Statistics** token & request OpenCode + AGY |

---

### 2. ⚡ Dispatcher Perintah Global `ai`
Perintah `ai` dapat dijalankan dari folder mana saja dengan sub-perintah berikut:

```bash
ai                           # Buka menu interaktif TUI
ai oc [args...]              # Jalankan OpenCode v1 secara langsung
ai oc2 [args...]             # Jalankan OpenCode v2 secara langsung
ai agy [args...]             # Jalankan Antigravity CLI secara langsung
ai web [v1|v2]               # Buka OpenCode Web Server & otomatis buka di browser Android
ai service [cmd] [args...]   # Kelola background web daemon (status, start, stop, logs)
ai session [cmd] [args...]   # Kelola riwayat sesi, ekspor .md, dan SQLite vacuum
ai memory [cmd] [args...]    # Akses Knowledge Memory, simpan solusi sesi & search FTS5
ai plugin [cmd] [args...]    # Kelola MCP servers dan OpenCode plugins
ai skill [cmd] [args...]     # Kelola AI Agent Skills (daftar, pasang, toggle, update)
ai agent [cmd] [args...]     # Kelola AI Subagents & Personas (daftar, create, sync, run)
ai account [cmd] [args...]   # Multi-account registry, pantau kuota 5h, rotasi failover & backup
ai config [cmd] [args...]    # Atur provider API key dan default model
ai doctor [--fix]            # Periksa dan perbaiki kesehatan lingkungan sistem
ai update                    # Cek versi terpasang vs rilis terbaru GitHub/npm
ai backup [--full]           # Backup konfigurasi dan token ke .tar.gz
ai restore [berkas.tar.gz]   # Pulihkan pengaturan dari berkas backup
ai usage [--opencode|--agy] [--days N]  # Statistik token & request OpenCode + AGY (per-hari)
```

---

### 3. 🛠️ Daftar Perintah CLI Lengkap Berdasarkan Modul

#### A. 🩺 Health Doctor (`doctor.sh`)
```bash
doctor.sh                    # Jalankan 18 pemeriksaan lingkungan & dependensi
doctor.sh --fix              # Otomatis perbaiki sertifikat TLS, permission, dan dependensi
```

#### B. 📊 Usage Statistics (`usage-stats.sh`)
```bash
ai usage                     # Total token & request + statistik per-hari (14 hari terakhir)
ai usage --opencode          # Hanya OpenCode (per-hari, per-model breakdown)
ai usage --agy               # Hanya Antigravity CLI
ai usage --days 7            # Batasi tabel per-hari ke N hari terakhir
ai usage --help              # Panduan lengkap
```

**Data sumber:**
- **OpenCode**: `~/.local/share/opencode/opencode.db` — total requests, input/output/cache tokens, biaya, **tabel per-hari** (request, token, cost, bar chart), dan breakdown per-model. Skema storage **v2** (`session_message`, kolom `type`) dan **v1 legacy** (`message`) dilaporkan **terpisah** agar angkanya akurat, lalu ditutup dengan baris **Total Gabungan (unik)**. Pesan legacy yang sudah termigrasi ke v2 dikecualikan dari bagian v1 supaya tidak terhitung dua kali.
- **AGY**: request dihitung dari `~/.gemini/antigravity-cli/conversations/*.db` (gen_metadata); token & **statistik per-hari** di-parse dari `brain/*/.system_generated/logs/transcript_full.jsonl` (`created_at`, `input_tokens`, `output_tokens`, `cache_read_tokens`).

#### C. 🔄 Pengecek Versi Rilis Upstream (`update.sh`)
```bash
update.sh                    # Periksa rilis resmi GitHub anomalyco/opencode vs versi lokal
```

#### C. 🌐 Background Web Service Manager (`service.sh`)
```bash
service.sh                   # Menu interaktif Web Service Manager
service.sh status            # Cek status PID, port (4096/4097), dan pemakaian RAM
service.sh start v2          # Jalankan OpenCode v2 Web Service & otomatis buka browser
service.sh start v1          # Jalankan OpenCode v1 Web Service & otomatis buka browser
service.sh stop v2           # Hentikan background service OpenCode v2
service.sh stop all          # Hentikan semua service AI yang sedang berjalan
service.sh restart v2        # Restart background service OpenCode v2
service.sh logs v2           # Tampilkan isi log web service
service.sh logs v2 -f        # Pantau log secara real-time (follow)
service.sh open v2           # Buka kembali halaman Web UI di browser Android
```

#### D. 🔑 Wizard Setup API Key & Provider (`config.sh` / `aiconfig`)
```bash
config.sh                    # Buka wizard konfigurasi interaktif (Menu 1: Selector OpenCode / AGY)
config.sh tool               # Pilih Tool AI (OpenCode atau AGY) -> Cek Konek, Add, Apus
config.sh opencode           # Kelola langsung provider yang konek ke OpenCode
config.sh agy                # Kelola langsung provider yang konek ke Antigravity CLI
config.sh tool-list [tool]   # Daftar provider yang konek ke target (opencode/agy)
config.sh list               # Tampilkan tabel status provider aktif, masked key, dan model
config.sh set <provider>     # Simpan API key (input disembunyikan untuk privasi)
config.sh set <prov> <key>   # Simpan API key secara langsung
config.sh get <provider>     # Tampilkan masked key untuk provider tertentu
config.sh remove <provider>  # Hapus kredensial API key provider (opencode, agy, atau all)
config.sh model              # Tampilkan model default OpenCode yang aktif saat ini
config.sh model <model_id>   # Atur model default OpenCode (misal: google/gemini-2.5-flash)
config.sh test [provider]    # Uji validitas API key via HTTPS (HTTP 200 OK)
config.sh sync-env           # Ekspor key ke ~/.termux_ai_env & auto-load ke ~/.bashrc
```

#### E. 🔄 Manajemen Sesi & Optimasi Penyimpanan (`session.sh` / `aisession`)
```bash
session.sh                   # Menu interaktif Session Manager
session.sh status            # Analisis storage database, total sesi, dan ruang dead space
session.sh list [limit]      # Tampilkan daftar sesi terbaru (OpenCode & Antigravity)
session.sh search <keyword>  # Cari percakapan lama berdasarkan topik, prompt, atau ID
session.sh info <id_sesi>    # Tampilkan metadata lengkap sesi (model, token, biaya)
session.sh export <id_sesi>  # Ekspor sesi ke file Markdown (.md) & salin ke /sdcard/Download/
session.sh clean             # Bersihkan berkas log debug lama dan cache temporary snapshot
session.sh vacuum            # SQLite VACUUM untuk mengompresi DB & bebaskan 1GB+ memori HP
session.sh prune --days <N>  # Hapus sesi lama yang lebih tua dari N hari & jalankan VACUUM
session.sh prune --keep <N>  # Sisakan N sesi terbaru dan bersihkan sisanya
session.sh resume <id_sesi>  # Lanjutkan percakapan lama langsung di OpenCode
```

#### F. 🧩 Plugin & MCP Tool Installer (`plugin.sh` / `aiplugin`)
```bash
plugin.sh                           # Menu interaktif TUI Plugin & MCP Installer
plugin.sh status                    # Tampilkan status terperinci: pemisah MCP vs Plugin & matriks sinkronisasi
plugin.sh install <preset> [target] # Pasang preset MCP ke target tertentu:
                                    # Target: 'agy' (Antigravity), 'opencode'/'oc', atau 'all' (keduanya)
                                    # Contoh: plugin.sh install termux-device agy
                                    #         plugin.sh install sqlite opencode
                                    #         plugin.sh install fetch all
plugin.sh add-custom <id> <target> <command> [args] [env] # Pasang Custom MCP Server bebas
plugin.sh install notifier          # Pasang plugin notifikasi Android ke OpenCode
plugin.sh test <nama>               # Uji apakah biner command MCP server dapat dieksekusi di Termux
plugin.sh remove <nama> [target]    # Hapus MCP server atau plugin dari target (agy/opencode/all)
```

#### G. 🧠 Knowledge Memory & AI Brain (`memory.sh` / `aimem` / `aisession memory`)
```bash
memory.sh                    # Menu interaktif TUI Knowledge Memory & AI Brain
memory.sh add [options]      # Tambah catatan pengetahuan permanen baru
memory.sh show <id>          # Tampilkan detail lengkap catatan pengetahuan
memory.sh list [options]     # Daftar catatan (filter: --category, --status, --tag, --project)
memory.sh search <keyword>   # Pencarian teks penuh cepat (SQLite FTS5 + LIKE Fallback)
memory.sh edit <id> [opts]   # Edit atau perbarui konten, judul, tag, atau status
memory.sh delete <id> [-y]   # Hapus catatan memori dengan konfirmasi aman
memory.sh tag <id> <op> <t>  # Tambah atau hapus tag (op: add | remove)
memory.sh verify <id>        # Tandai catatan sebagai terverifikasi (verified)
memory.sh deprecate <id>     # Tandai catatan sebagai usang (deprecated)
memory.sh export [--all|<id>]# Ekspor catatan ke file Markdown (.md) dengan YAML frontmatter
memory.sh import <path>      # Impor catatan dari file/folder Markdown (dengan deduplikasi)
memory.sh context "<query>"  # Ekspor ringkasan konteks terverifikasi untuk Agent AI (OpenCode/AGY)
memory.sh save-from-session  # Workflow simpan solusi penting dari sesi obrolan (auto secret redaction)
memory.sh stats              # Tampilkan statistik jumlah catatan, verifikasi, dan status FTS5
memory.sh mcp-export         # Ekspor basis pengetahuan ke format entitas MCP Knowledge Graph
```

#### H. 🧠 AI Agent Skill Manager (`skill.sh` / `aiskill` / `ai skill`)

Mendeteksi skill dari **dua cakupan**:

| Cakupan | Lokasi yang dipindai |
| --- | --- |
| **Global** (semua proyek) | `~/.agents/skills`, `~/.claude/skills`, `~/.config/opencode/skills`, `~/.gemini/skills` |
| **Workspace** (proyek aktif) | `./.agents/skills`, `./.claude/skills`, `./.opencode/skills` — walk-up dari cwd sampai git worktree root, sama seperti OpenCode |

Setiap lokasi juga memiliki pasangan `skills-disabled/` untuk toggle hemat token.

```bash
skill.sh                     # Menu interaktif TUI Skill Manager
skill.sh list                # Tampilkan skill GLOBAL + WORKSPACE (aktif & nonaktif)
skill.sh list --global       # Filter hanya skill global
skill.sh list --workspace    # Filter hanya skill workspace proyek ini
skill.sh presets             # Lihat katalog skill populer (prompt-master, antislop, ui-ux-pro-max, dll.)
skill.sh search [keyword]    # Cari skill resmi Claude dari anthropics/claude-plugins-official (hanya yang didukung)
skill.sh install <nama|url>  # Pasang skill dari katalog preset, Claude, GitHub URL, atau folder lokal
skill.sh install <x> -w      # Pasang skill ke workspace proyek ini (./.agents/skills)
skill.sh toggle <nama>       # Toggle aktif/nonaktifkan skill (global maupun workspace)
skill.sh enable <nama>       # Aktifkan skill yang sebelumnya dinonaktifkan
skill.sh disable <nama>      # Nonaktifkan skill tanpa menghapus berkas (pindah ke skills-disabled)
skill.sh update [nama]       # Perbarui skill berbasis Git menggunakan git pull
skill.sh info <nama>         # Detail metadata, scope (global/workspace), & pratinjau SKILL.md
skill.sh create <nama>       # Buat scaffold template skill baru global
skill.sh create <nama> -w    # Buat scaffold skill baru di workspace proyek (./.agents/skills)
skill.sh remove <nama>       # Hapus skill dari penyimpanan (global & workspace)
skill.sh doctor              # Audit frontmatter, benturan nama antar scope, & integritas skill
```

#### I. 🤖 AI Subagents & Personas Manager (`agent.sh` / `aiagent` / `ai agent`)
```bash
agent.sh                     # Menu interaktif TUI Persona Manager
agent.sh list                # Tampilkan daftar persona aktif/nonaktif di Antigravity & OpenCode
agent.sh presets             # Lihat template persona populer (code-reviewer, android-reverser, dll)
agent.sh create <nama>       # Buat persona baru (opsi: --both, --gemini, --opencode)
agent.sh sync [nama]         # Sinkronkan silang persona antara Antigravity <-> OpenCode
agent.sh info <nama>         # Tampilkan detail metadata, tools aktif, dan instruksi sistem
agent.sh toggle <nama>       # Toggle aktif/nonaktifkan persona
agent.sh run <nama>          # Jalankan OpenCode atau Antigravity langsung dengan persona tersebut
agent.sh remove <nama>       # Hapus persona dari sistem
agent.sh doctor              # Audit kelengkapan YAML frontmatter & sinkronisasi silang
```

#### J. 🔐 Multi-Account, Quota & Rotation Manager (`account.sh` / `aiacc` / `ai account`)
```bash
account.sh                   # Menu interaktif TUI Multi-Account & Quota Manager
account.sh list              # Daftar semua profil akun terdaftar & indikator status aktif
account.sh current           # Tampilkan metadata dan kredensial profil akun aktif
account.sh switch <nama>     # Beralih akun aktif secara instan (swap auth.json, config & env)
account.sh add <nama> [desc] # Daftarkan profil akun baru (personal, work, testing)
account.sh set-key <p> <k>   # Simpan API key & target platform ke profil tertentu
account.sh remove <nama>     # Hapus profil akun dari registry
account.sh quota [--all]     # Pantau kuota live (jendela rolling 5 jam, mingguan, reset harian 00:00 UTC)
account.sh rotate            # Putar otomatis ke profil berikutnya di pool failover
account.sh pool [set p1,p2]  # Konfigurasi urutan pool rotasi otomatis saat limit tercapai
account.sh backup [file.enc] # Snapshot kredensial terenkripsi AES-256 (PBKDF2 100k + SHA256)
account.sh restore <file.enc># Pulihkan kredensial akun dari berkas backup terenkripsi
```

##### 🪐 Integrasi Antigravity-Swap (`aswap`) untuk Antigravity CLI (`agy`)
Dukungan bawaan untuk multi-account Google OAuth pada Antigravity CLI (`agy`) menggunakan [antigravity-swap](https://github.com/ngewa/antigravity-swap):
```bash
ai aswap                     # Buka menu aswap (atau langsung ketik 'aswap')
ai aswap list                # Lihat seluruh akun Google agy beserta kuota 5h/7d live (Claude/GPT & Gemini)
ai aswap list --detail       # Detail per grup model: daftar model, status tersedia/habis, & waktu reset
ai aswap add                 # Simpan akun Google yang sedang aktif di agy ke registry aswap
ai aswap switch <1|email>    # Beralih akun Google Antigravity tanpa harus logout
ai aswap watch               # Dashboard real-time countdown kuota & jendela reset
ai aswap auto                # Daemon background auto-switch sebelum kuota habis (threshold 90%)
ai aswap run "<prompt>"      # Jalankan task agy dengan failover otomatis ke akun berikutnya jika limit
```

#### K. 💾 Backup & Restore Pengaturan (`backup.sh`)
```bash
backup.sh                    # Menu interaktif Backup & Restore
backup.sh export             # Ekspor konfigurasi, token OAuth, memory.db, dan skills ke tar.gz (~3MB)
backup.sh export --full      # Ekspor lengkap termasuk seluruh riwayat percakapan
backup.sh restore <file>     # Pulihkan konfigurasi & memory.db dari file backup .tar.gz
```

#### L. 🚀 Setup Shortcuts & Widget (`setup-shortcuts.sh`)
```bash
setup-shortcuts.sh           # Pasang perintah 'ai', shell aliases, dan Termux:Widget
setup-shortcuts.sh --remove  # Bersihkan semua shortcut dan alias dari sistem
```

#### M. 🗑️ Uninstaller (`uninstall.sh`)
```bash
uninstall.sh                 # Menu interaktif penghapusan tools
uninstall.sh opencode        # Hapus binary wrapper OpenCode v1
uninstall.sh opencode-v2     # Hapus binary wrapper OpenCode v2
uninstall.sh agy             # Hapus binary wrapper Antigravity CLI
uninstall.sh all             # Hapus semua binary tools
uninstall.sh all --purge     # Hapus semua tools beserta folder data & konfigurasi user
```

---

### 4. 📱 Android Homescreen Shortcuts (Termux:Widget)
Bagi pengguna aplikasi **Termux:Widget** dari F-Droid, shortcut sekali-ketuk berikut otomatis tersedia di layar utama Android:
- ⚡ **`AI-Menu.sh`** : Membuka launcher utama pilihan AI
- 🌐 **`AI-Web.sh`** : Memulai background Web UI & langsung membuka browser
- 🔑 **`AI-Config.sh`** : Membuka wizard konfigurasi API key & model
- 🔄 **`AI-Session.sh`** : Membuka penjelajah sesi, ekspor, dan vacuum database
- 🧠 **`AI-Memory.sh`** : Membuka Knowledge Memory & AI Brain persisten
- 🧩 **`AI-Plugin.sh`** : Membuka installer plugin & MCP tool
- 🎯 **`AI-Skill.sh`**  : Membuka AI Agent Skill Manager
- 🤖 **`AI-Agent.sh`**  : Membuka AI Persona & Subagent Manager
- 🔐 **`AI-Account.sh`**: Membuka Multi-Account, Quota & Rotation Manager
- 🩺 **`AI-Doctor.sh`** : Menjalankan diagnostik kesehatan sistem
- 💻 **`OpenCode.sh`** : Membuka OpenCode v1 langsung di terminal
- 🚀 **`OpenCode-v2.sh`**: Membuka OpenCode v2 langsung di terminal
- 🪐 **`Antigravity-CLI.sh`**: Membuka Antigravity CLI langsung di terminal

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
| `config.sh tool` | Membuka interactive selector untuk memilih Tool AI (`OpenCode` atau `AGY`), melihat daftar provider yang terkoneksi, menambah (Add) provider baru, atau menghapus (Apus) provider |
| `config.sh opencode` (atau `oc`) | Langsung membuka dashboard provider yang terhubung ke OpenCode (v1 & v2) |
| `config.sh agy` (atau `antigravity`) | Langsung membuka dashboard provider yang terhubung ke Antigravity CLI (agy) |
| `config.sh tool-list [opencode\|agy]` | Menampilkan daftar provider yang terkoneksi khusus pada tool target |
| `config.sh list` (atau `aiconfig`) | Menampilkan tabel status provider aktif, target AI (OpenCode/AGY/Universal), API mode, masked key, model aktif, dan lokasi berkas setting manual |
| `config.sh manual` (atau `paths`) | Menampilkan panduan komprehensif, struktur JSON, izin berkas (chmod), dan menu buka berkas konfigurasi di terminal text editor |
| `config.sh info <provider>` | Menampilkan detail lengkap parameter provider (Target, Base URL, Model, API Mode, Status OpenCode, Status AGY, Key) |
| `config.sh target <provider> <opencode\|agy\|all>` | Mengatur target penerapan provider ke OpenCode saja, Antigravity (agy) saja, atau keduanya (Universal) |
| `config.sh set <provider> <key> [target] [baseURL] [model] [apiMode]` | Menyimpan konfigurasi provider lanjutan ke OpenCode v1/v2 dan/atau Antigravity agy |
| `config.sh set-advanced <provider> <key> [target] [baseURL] [model] [apiMode]` | Alias langsung konfigurasi lanjutan via CLI |
| `config.sh edit <provider> [target] [baseURL] [model] [apiMode] [key]` | Mengubah/mengedit konfigurasi provider yang sudah terpasang |
| `config.sh edit-field <provider> <target\|baseurl\|model\|mode\|key> <val>` | Mengedit nilai spesifik parameter provider secara langsung |
| `config.sh enable <provider> [target]` | Mengaktifkan provider (opsional spesifik `opencode`, `agy`, atau `all`) |
| `config.sh disable <provider> [target]` | Menonaktifkan provider tanpa menghapus API Key (opsional spesifik `opencode`, `agy`, atau `all`) |
| `config.sh toggle <provider> [target]` | Beralih status aktif / nonaktif provider dengan cepat pada target tertentu |
| `config.sh get <provider> [target]` | Menampilkan masked API key untuk provider tertentu |
| `config.sh remove <provider> [target]` | Menghapus konfigurasi provider dari OpenCode saja (`opencode`), AGY saja (`agy`), atau keduanya (`all`) |
| `config.sh model [model_id]` | Menampilkan atau mengatur default model di `~/.config/opencode/opencode.jsonc` |
| `config.sh model-agy [model_id]` | Menampilkan atau mengatur default model di `~/.gemini/antigravity-cli/settings.json` |
| `config.sh test [provider]` | Menguji validitas koneksi & API key secara langsung via HTTP (HTTP 200 OK) |
| `config.sh sync-env` | Mengekspor API keys, Base URLs, dan model ke `~/.termux_ai_env` (bisa di-source oleh `~/.bashrc`) |

### Provider yang Didukung Secara Langsung:
- 🌐 **Google Gemini** (`google`): `google/gemini-2.5-flash`, `google/gemini-2.5-pro`
- 🧠 **Anthropic Claude** (`anthropic`): `anthropic/claude-3-7-sonnet`, `anthropic/claude-3-5-sonnet`
- ⚡ **OpenAI** (`openai`): `openai/gpt-4.5-preview`, `openai/gpt-4o`, `openai/o3-mini`
- 🐋 **DeepSeek** (`deepseek`): `deepseek/deepseek-chat`, `deepseek/deepseek-reasoner`
- 🔀 **OpenRouter** (`openrouter`): `openrouter/auto`, ratusan model lewat satu API key
- 🚀 **Groq** (`groq`): `groq/llama-3.3-70b-versatile`, inferensi ultra-cepat
- 🌪️ **Mistral AI** (`mistral`): `mistral/mistral-large-latest`, `mistral/codestral-latest`
- 🤖 **xAI (Grok)** (`xai`): `xai/grok-2-latest`, `xai/grok-beta`
- 🌐 **NaraRouter** (`bynara`): `https://router.bynara.id/v1`, rute cepat Claude, GLM, & DeepSeek
- ⚙️ **Custom Provider**: Masukkan provider ID atau base URL kustom pilihan Anda.

### Target Integrasi AI & Mode Lanjutan:
- **Target Integrasi**:
  1. `opencode`: Diterapkan ke **OpenCode v1 & v2** (`~/.config/opencode/opencode.jsonc` & `auth.json`)
  2. `agy`: Diterapkan ke **Antigravity CLI (agy)** (`~/.gemini/antigravity-cli/settings.json`)
  3. `all`: **Universal** (Otomatis disinkronkan ke OpenCode v1, v2, dan Antigravity agy)
- **Parameter Lanjutan**:
  - **Base URL**: Endpoint kustom (contoh: `https://router.bynara.id/v1`, `http://localhost:11434/v1`)
  - **Default Model**: Model utama (contoh: `bynara/glm-5.3-flash`, `google/gemini-2.5-flash`)
  - **API Key**: Kredensial rahasia (disimpan aman dengan `chmod 600`)
  - **API Mode**:
    1. `auto` (**Automatic**): Menggunakan default bawaan provider dan model
    2. `chat_completions` (**Chat Completions**): Endpoint `/chat/completions` standar OpenAI
    3. `responses` (**Responses**): Endpoint `/responses` untuk provider yang mendukung Responses API
    4. `responses_compat` (**Responses Compat**): Endpoint `/responses` legacy text chunks untuk strict gateways

### Contoh Tampilan Status:
```text
========================================================================================
                       DAFTAR PROVIDER & STATUS API KEY TERPASANG                       
========================================================================================
🎯 Model OpenCode (v1 & v2): bynara/glm-5.3-flash
🎯 Model Antigravity (agy) : Gemini 3.8 Flash (Medium)

PROVIDER     NAMA               STATUS       TARGET       API MODE         API KEY (MASKED)  
------------------------------------------------------------------------------------------
google       Google Gemini      [ AKTIF ]    Universal    Automatic        AIzaSyAT...3g4k   
anthropic    Anthropic Claude   [ NONAKTIF ] OpenCode     Automatic        sk-ant-a...xyz1   
openai       OpenAI             [ BELUM ]    -            -                -                 
deepseek     DeepSeek           [ BELUM ]    -            -                -                 
openrouter   OpenRouter         [ BELUM ]    -            -                -                 
groq         Groq               [ BELUM ]    -            -                -                 
mistral      Mistral AI         [ BELUM ]    -            -                -                 
xai          xAI (Grok)         [ BELUM ]    -            -                -                 
bynara       NaraRouter         [ AKTIF ]    OpenCode     Chat Compl.      sk-nry-L...Pbuc   
------------------------------------------------------------------------------------------

🌐 Detail Konfigurasi Endpoint & Parameter Provider:
  • bynara    : Target=OpenCode [OC:AKTIF|AGY:AKTIF] | BaseURL=https://router.bynara.id/v1 | Model=glm-5.3-flash | Mode=Chat Completions

📁 Lokasi Berkas & Panduan Setting Manual:
  • OpenCode Auth (API Key)        : ~/.local/share/opencode/auth.json (chmod 600)
    Format: {"<provider>": {"type": "api", "key": "<API_KEY>"}}
  • OpenCode Config (Model/Endpoint) : ~/.config/opencode/opencode.jsonc
    Format: {"model": "provider/model", "provider": {"<id>": {"options": {"baseURL": "...", "apiKey": "..."}}}}
  • Antigravity CLI (agy Settings)   : ~/.gemini/antigravity-cli/settings.json
    Format: {"model": "...", "providers": {"<id>": {"apiKey": "...", "baseURL": "..."}}}
  • Shell Env Fallback (Global)      : ~/.termux_ai_env (source di ~/.bashrc)
    Format: export GEMINI_API_KEY="..." | export OPENAI_API_KEY="..." | dll.
  • Perintah Edit Berkas Manual      : nano ~/.local/share/opencode/auth.json
                                     nano ~/.config/opencode/opencode.jsonc
                                     nano ~/.gemini/antigravity-cli/settings.json
  • Panduan Lengkap CLI              : config.sh manual (atau menu pilihan [12])
```

### 📁 Lokasi Berkas Konfigurasi & Setting Manual:

Bagi pengguna yang ingin mengatur provider, API key, endpoint proxy, atau default model secara langsung melalui text editor (seperti `nano` atau `vim`):

1. **OpenCode Auth (API Keys)**:
   - **Path**: `~/.local/share/opencode/auth.json`
   - **Izin Berkas**: Wajib privat `chmod 600 ~/.local/share/opencode/auth.json`
   - **Format JSON**:
     ```json
     {
       "google": { "type": "api", "key": "AIzaSy..." },
       "anthropic": { "type": "api", "key": "sk-ant-..." },
       "bynara": { "type": "api", "key": "sk-nry-...", "baseURL": "https://router.bynara.id/v1", "apiMode": "chat_completions" }
     }
     ```

2. **OpenCode Configuration (Model & Provider Endpoints)**:
   - **Path**: `~/.config/opencode/opencode.jsonc`
   - **Format JSONC**:
     ```jsonc
     {
       "$schema": "https://opencode.ai/config.json",
       "model": "bynara/glm-5.3-flash",
       "provider": {
         "bynara": {
           "name": "NaraRouter",
           "npm": "@ai-sdk/openai-compatible",
           "options": {
             "baseURL": "https://router.bynara.id/v1",
             "apiKey": "sk-nry-...",
             "apiMode": "chat_completions"
           },
           "models": {
             "glm-5.3-flash": { "name": "glm-5.3-flash" }
           }
         }
       },
       "disabled_providers": ["deepseek"]
     }
     ```

3. **Antigravity CLI (agy Settings & Provider)**:
   - **Path**: `~/.gemini/antigravity-cli/settings.json`
   - **Format JSON**:
     ```json
     {
       "model": "Gemini 3.8 Flash (Medium)",
       "providers": {
         "google": { "apiKey": "AIzaSy..." },
         "bynara": {
           "apiKey": "sk-nry-...",
           "baseURL": "https://router.bynara.id/v1",
           "model": "bynara/glm-5.3-flash",
           "apiMode": "chat_completions"
         }
       },
       "disabled_providers": ["anthropic"]
     }
     ```

4. **Shell Environment Variables (Fallback Global)**:
   - **Path**: `~/.termux_ai_env` (otomatis dimuat jika di-source di `~/.bashrc` atau `~/.zshrc`)
   - **Contoh baris**:
     ```bash
     export GEMINI_API_KEY="AIzaSy..."
     export ANTHROPIC_API_KEY="sk-ant-..."
     export OPENAI_API_KEY="sk-..."
     export DEEPSEEK_API_KEY="sk-..."
     export OPENROUTER_API_KEY="sk-or-..."
     export GROQ_API_KEY="gsk_..."
     export BYNARA_API_KEY="sk-nry-..."
     ```
   - **Sinkronisasi Otomatis**: Jalankan `config.sh sync-env` untuk mengekspor kredensial dari `auth.json` ke file environment ini secara otomatis.

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

## 🧠 Knowledge Memory & AI Brain (`memory.sh`)

**Knowledge Memory (AI Brain)** adalah lapisan memori persisten teknis yang dirancang untuk menyimpan, mengindeks, dan menggunakan kembali solusi terverifikasi, keputusan arsitektur, catatan *troubleshooting*, dan *lessons learned* lintas proyek dan lintas AI coding agent (**OpenCode**, **Antigravity CLI**, dll).

Berbeda dari sekadar riwayat sesi percakapan, Knowledge Memory menyaring dan menyimpan pengetahuan esensial dengan **verifikasi kualitas**, **pencarian teks penuh lokal (FTS5)** tanpa membutuhkan API AI atau embedding berbayar, dan **redaksi keamanan otomatis**.

```bash
# Buka menu interaktif TUI Knowledge Memory:
memory.sh
# Atau via launcher cepat:
ai memory
# Atau via shell alias:
aimem
# Atau terintegrasi dari session manager:
session.sh memory
```

### 1. ⚖️ Pemisahan Tanggung Jawab (Separation of Concerns)

| Lapisan | Komponen | Tanggung Jawab Utama | Sifat Data |
| :--- | :--- | :--- | :--- |
| **Session Manager** | `session.sh` / `aisession` | Mengelola riwayat obrolan lengkap, resume percakapan, ekspor turn-based Markdown, dan optimasi disk (`VACUUM` / prune). | Sementara / Transaksional (Bisa dibersihkan saat storage penuh). |
| **Knowledge Memory** | `memory.sh` / `aimem` | Mengelola catatan teknis terverifikasi, solusi bug, tips konfigurasi, dan keputusan arsitektur. | Permanen (Tidak pernah dihapus oleh session prune / vacuum). |
| **Agent Context** | `memory.sh context` | Menyediakan ringkasan referensi data relevan ke dalam konteks prompt AI agent. | Read-only Data (Bukan instruksi sistem / bebas prompt injection). |

> [!IMPORTANT]
> **Penyimpanan Terisolasi**: Knowledge Memory disimpan di database independen `~/.local/share/termux-ai/memory.db` dengan hak akses ketat (`chmod 700` pada folder dan `chmod 600` pada database). Database ini **tidak akan pernah disentuh** atau terhapus ketika menjalankan *pruning* sesi pada `session.sh`.

---

### 2. 🗂️ Struktur Catatan & Lifecycle Status Verifikasi

Setiap catatan dalam Knowledge Memory memiliki struktur data standar:
- **`ID`**: ID unik dan stabil (contoh: `mem_20261028_a1b2c3`).
- **`Title`**: Judul deskriptif solusi/catatan.
- **`Content`**: Solusi teknis lengkap atau langkah-langkah implementasi.
- **`Category`**: `troubleshooting`, `solution`, `architecture`, `configuration`, `workflow`, `decision`, `lesson`.
- **`Tags`**: Kata kunci/tag terindeks (contoh: `sqlite,wal,termux,concurrency`).
- **`Project`**: Nama repositori atau direktori proyek terkait.
- **`Tool`**: Agent atau platform sumber (`opencode`, `agy`, `general`).
- **`Status`**: Siklus hidup verifikasi catatan:
  - 🟡 **`unverified`**: Catatan awal dari sesi atau catatan cepat yang belum diuji ulang.
  - 🟢 **`verified`**: Solusi yang telah terbukti berhasil dan diverifikasi oleh pengguna.
  - 🔴 **`deprecated`**: Solusi usang/lama (otomatis diturunkan prioritasnya dan tidak diekspor ke konteks agent).
- **`Source Session`**: Referensi ID sesi asal jika catatan diekstraksi dari percakapan obrolan.

---

### 3. 🛡️ Mesin Redaksi Keamanan Otomatis (Secret Auto-Redaction)

Sebelum catatan disimpan ke dalam database (baik melalui CLI, impor Markdown, atau ekstraksi sesi), konten secara otomatis dipindai oleh mesin *Secret Redaction*:
- 🔑 **Google API Keys** (`AIzaSy...`) -> `[REDACTED_GOOGLE_API_KEY]`
- 🔑 **Anthropic Keys** (`sk-ant-...`) -> `[REDACTED_ANTHROPIC_KEY]`
- 🔑 **OpenAI & generic keys** (`sk-...`, `sk-proj-...`) -> `[REDACTED_OPENAI_KEY]`
- 🔑 **GitHub PAT Tokens** (`ghp_...`, `github_pat_...`) -> `[REDACTED_GITHUB_TOKEN]`
- 🔑 **Bearer Tokens** (`Bearer ...`) -> `Bearer [REDACTED_BEARER_TOKEN]`
- 🔑 **Private Keys** (`BEGIN RSA/OPENSSH PRIVATE KEY`) -> `[REDACTED_PRIVATE_KEY]`
- 🔑 **Basic Auth URLs** (`https://user:pass@host`) -> `https://***:***@host`

Jika ditemukan kredensial sensitif, sistem akan menampilkan peringatan dan menyensor nilai tersebut sebelum disimpan permanen.

---

### 4. 🔍 Mesin Pencari Lokal Cepat (SQLite FTS5 + LIKE Fallback)

Knowledge Memory menggunakan virtual table **SQLite FTS5** (`memory_fts`) dengan *synchronization triggers* otomatis:
- **Kecepatan Tinggi**: Pencarian instan pada ribuan catatan teknis langsung di prosesor smartphone ARM64.
- **Hemat Resource**: Bekerja 100% lokal di Termux tanpa memerlukan internet, API LLM, atau vector database yang berat.
- **Graceful Fallback**: Jika lingkungan SQLite Termux tidak mengaktifkan modul FTS5, query otomatis dialihkan (*fallback*) ke query SQL `LIKE` tanpa error.

Contoh pencarian:
```bash
# Cari solusi berdasarkan kata kunci:
memory.sh search "sqlite locked"

# Cari dengan filter kategori atau tag:
memory.sh search "timeout" --category troubleshooting --tag sqlite
```

---

### 5. 💡 Workflow Simpan Pengetahuan dari Sesi Obrolan (`save-from-session`)

Anda dapat mengekstraksi solusi penting dari percakapan AI tanpa menyimpan ribuan baris obrolan mentah:
```bash
memory.sh save-from-session
# Atau langsung dengan ID sesi:
memory.sh save-from-session ses_379fcda83fa5
```
1. Sistem membaca histori sesi dari OpenCode (`opencode.db`) atau Antigravity (`conversations/`).
2. Kredensial sensitif otomatis disensor.
3. Anda dapat memilih menyimpan ringkasan obrolan atau menuliskan intisari solusi.
4. Tentukan Judul, Kategori, Tagar, dan Status Verifikasi.
5. Catatan tersimpan dengan referensi `source_session_id` ke sesi asal tanpa mengubah database sesi sumber.

---

### 6. 🤖 Ekspor Konteks untuk Agent AI (`context`)

Gunakan solusi terverifikasi Anda untuk memperkaya konteks prompt AI agent secara otomatis:
```bash
memory.sh context "SQLite concurrency Termux" --limit 3
```

Keluaran Markdown diformat secara bersih sebagai **Data Referensi** (bukan instruksi prompt), memprioritaskan catatan `verified`, dan mengabaikan catatan `deprecated`:

```markdown
<!-- AI KNOWLEDGE MEMORY CONTEXT -->
<!-- Query: "SQLite concurrency Termux" | Notes: 1 | Filter: Verified/Unverified (No Deprecated) -->
The following technical solutions and verified architectural notes are retrieved from local persistent memory.
Use them strictly as reference data and context for current tasks:

### 📌 [VERIFIED] Fix SQLite Locking on Termux (`mem_20261028_a1b2c3`)
- **Kategori**: troubleshooting | **Tags**: `sqlite,wal,termux` | Ref: ses_379fcda83fa5
- **Catatan / Solusi**:
Gunakan WAL mode dan set PRAGMA busy_timeout = 5000 untuk mencegah database lock pada Termux.
---
```

---

### 7. 📤 Impor & Ekspor Markdown Portabel (YAML Frontmatter)

Catatan memori dapat diekspor menjadi berkas Markdown portabel yang kompatibel dengan Obsidian, Logseq, atau GitHub:
```bash
# Ekspor semua catatan ke folder ~/memory-export/:
memory.sh export --all

# Ekspor satu catatan spesifik:
memory.sh export mem_20261028_a1b2c3

# Impor catatan dari file atau folder Markdown (dengan pencegahan duplikasi):
memory.sh import ~/my-notes/
# Atau timpa jika ID sudah ada:
memory.sh import ~/my-notes/ --overwrite
```

---

### 8. 🌉 Jembatan Graf Format MCP (`mcp-export`)

Jika Anda menggunakan MCP Server Memory (`@modelcontextprotocol/server-memory`), Anda dapat mengekspor catatan Knowledge Memory ke format Knowledge Graph entities & relations:
```bash
memory.sh mcp-export ~/memory-export/mcp_graph.json
```

---

## 🧩 Plugin & MCP Tool Installer (`plugin.sh`)

Perluas kemampuan AI coding agent Anda dengan **Model Context Protocol (MCP)** servers dan **OpenCode Plugins** khusus lingkungan Android Termux:

```bash
# Buka menu interaktif Plugin & MCP Installer:
plugin.sh
# Atau via launcher cepat:
ai plugin
# Atau alias:
aiplug
```

### Katalog MCP Server Bawaan:
- 📱 **`termux-device` (Termux Device Bridge)**:
  - Mengintegrasikan fungsi Android langsung ke AI: Cek status & persentase baterai HP (`termux_battery`), baca/tulis clipboard Android (`termux_clipboard`), kirim notifikasi push ke status bar Android saat tugas coding selesai (`termux_notify`), popup toast di layar (`termux_toast`), getarkan HP (`termux_vibrate`), dan buka link di browser Android (`termux_open_url`).
- 🌐 **`fetch` (Web Fetcher)**:
  - Mengambil artikel web, dokumentasi online, dan response REST API secara instan (`@modelcontextprotocol/server-fetch`).
- 🗄️ **`sqlite` (SQLite Database Explorer)**:
  - Menghubungkan AI langsung ke file SQLite untuk inspeksi tabel dan eksekusi query (`@modelcontextprotocol/server-sqlite`).
- 📁 **`filesystem` (Filesystem Manager)**:
  - Operasi file terisolasi (`@modelcontextprotocol/server-filesystem`).
- 🧠 **`memory` (Knowledge Graph Memory)**:
  - Memori jangka panjang AI yang persisten lintas sesi percakapan (`@modelcontextprotocol/server-memory`).
- 🐙 **`github` (GitHub API)**:
  - Mengelola repositori, issue, dan pull request GitHub langsung dari chat AI (`@modelcontextprotocol/server-github`).

### Katalog Plugin OpenCode Bawaan:
- 🔔 **`termux-notifier.ts`**: Notifikasi otomatis ke status bar Android saat sesi OpenCode selesai memproses instruksi panjang.
- ⚡ **`rtk.ts`**: Plugin penghemat token dan kompilasi cerdas menggunakan Rust Toolkit (`rtk`).
- 🛡️ **`crg-plugin.ts`**: Auto-update knowledge graph code review.

### Kemampuan & Perintah CLI Cepat:

| Perintah | Deskripsi |
| :--- | :--- |
| `plugin.sh status` (atau `aiplugin`) | Menampilkan status lengkap dengan pemisah tegas antara **`[MCP SERVER]`** vs **`[PLUGIN]`**, matriks sinkronisasi platform, dan statistik |
| `plugin.sh install <preset> [target]` | Memasang preset MCP ke target: `agy` (Antigravity), `opencode` / `oc`, atau `all` (keduanya) |
| `plugin.sh add-custom <id> <target> <cmd> [args] [env]` | Memasang custom MCP server dari npm, python, atau biner lokal ke platform pilihan |
| `plugin.sh install notifier` | Memasang plugin notifikasi Android ke OpenCode |
| `plugin.sh install rtk` | Memasang plugin penghemat token & command rewriter ke OpenCode |
| `plugin.sh test <nama>` | Menguji ketersediaan biner/command MCP server di sistem Termux |
| `plugin.sh remove <nama> [target]` | Menghapus integrasi MCP server atau plugin dari target tertentu (`agy`, `opencode`, `all`) |

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

4. **Isolasi `LD_LIBRARY_PATH` & Dynamic Linker Cache glibc (Solusi `bad ELF magic: 2f2a2047`)**:
   - **Latar Belakang Masalah**: Jika wrapper C menetapkan `setenv("LD_LIBRARY_PATH", "$PREFIX/glibc/lib")`, variabel tersebut akan diwariskan ke seluruh proses turunan (*child processes*), seperti MCP Server (`termux-device`, `code-review-graph`), plugin, dan command bash Termux asli.
   - Dynamic linker Android Bionic (`/system/bin/linker64`) yang menjalankan executable Termux asli (seperti `python3`) akan membaca `LD_LIBRARY_PATH` glibc dan mencoba me-load `$PREFIX/glibc/lib/libc.so`. Karena file tersebut sebenarnya adalah GNU ld script berbasis teks (`/* GNU ld script...` dengan magic hex header `2f2a2047`), Android Bionic linker langsung crash dengan error:
     ```text
     CANNOT LINK EXECUTABLE "python3": ".../glibc/lib/libc.so" has bad ELF magic: 2f2a2047
     ```
   - **Solusi Arsitektur**:
     - Direktori `$PREFIX/glibc/lib` didaftarkan ke `$PREFIX/glibc/etc/ld.so.conf` dan dicache menggunakan `ldconfig` (`$PREFIX/glibc/etc/ld.so.cache`). Dynamic linker glibc (`ld-linux-aarch64.so.1`) me-resolve pustaka miliknya secara native dan cepat dari file cache tersebut.
     - Seluruh biner wrapper C (`opencode`, `opencode-v2`, `agy`) memanggil `unsetenv("LD_LIBRARY_PATH")` dan `unsetenv("LD_PRELOAD")`, sehingga seluruh proses turunan Termux berjalan di lingkungan Android Bionic yang bersih tanpa kontaminasi library glibc.

---

## 📋 Lisensi
Lisensi MIT - Dibuat untuk memudahkan developer dan komunitas Termux.

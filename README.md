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
6. **Export (Backup) Pengaturan & Token ke Arsip (.tar.gz)**
7. **Restore Pengaturan dari File Backup**
8. **Uninstall Tools (Hapus biner / data)**
9. **Keluar**

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
dpkg -i dist/opencode-v2_2.1.4_all.deb
dpkg -i dist/antigravity-cli_1.3.5_all.deb
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

# Termux AI Tools 🚀

Kumpulan skrip instalasi, auto-updater, dan paket DEBIAN (.deb) untuk menjalankan **OpenCode** dan **Antigravity CLI (agy)** di lingkungan **Termux (Android)** menggunakan runtime **glibc**.

---

## ⚡ Instalasi Cepat (One-Liner)

Jalankan perintah ini di terminal Termux Anda:

```bash
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash
```

Perintah di atas akan menampilkan menu interaktif:
1. **Install / Update OpenCode** (versi terbaru upstream `v1.19.4`)
2. **Install / Update Antigravity CLI** (`agy v1.3.5` build stabil dengan memory patch)
3. **Install / Update Keduanya**
4. **Cek Status & Versi Terpasang**
5. **Keluar**

---

## 🛠️ Instalasi Langsung via Argumen

Jika ingin langsung memasang atau memperbarui salah satu tool tanpa melalui menu interaktif:

```bash
# Pasang / Update OpenCode saja
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- opencode

# Pasang / Update Antigravity CLI saja
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- agy

# Pasang / Update Keduanya
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/install.sh | bash -s -- all
```

---

## 🔄 Pembaruan (Update Checker)

Skrip `update.sh` secara otomatis membandingkan versi yang terpasang di Termux Anda dengan rilis resmi terbaru di GitHub:

```bash
curl -fsSL https://raw.githubusercontent.com/ngewa/termux-ai-tools/main/update.sh | bash
```

Atau jika repo sudah di-clone secara lokal:
```bash
./update.sh
```

Contoh tampilan output:
```text
Software           | Terpasang        | Upstream         | Status    
----------------------------------------------------------------------
OpenCode           | 1.19.4           | 1.19.4           | Up-to-date
Antigravity CLI    | 1.3.5            | 1.4.8            | Stabil (1.3.5)
----------------------------------------------------------------------
```

---

## 📦 Paket DEBIAN (.deb)

Repositori ini juga menyertakan struktur paket DEBIAN (`control`, `postinst`, `preinst`, `postrm`) yang kompatibel dengan APT / DPKG Termux:

- `packages/opencode/DEBIAN/` (Target versi: `1.19.4`)
- `packages/antigravity-cli/DEBIAN/` (Target versi: `1.3.5`)

### Cara Build Paket .deb Sendiri:
```bash
git clone https://github.com/ngewa/termux-ai-tools.git
cd termux-ai-tools
bash build-deb.sh
```
File `.deb` hasil kompilasi akan tersimpan di folder `dist/`:
- `dist/opencode_1.19.4_all.deb`
- `dist/antigravity-cli_1.3.5_all.deb`

Untuk menginstall paket hasil build:
```bash
dpkg -i dist/opencode_1.19.4_all.deb
dpkg -i dist/antigravity-cli_1.3.5_all.deb
```

---

## 🔍 Detail Teknis & Arsitektur

1. **Glibc Wrapper Loader**:
   - Baik OpenCode maupun Antigravity CLI didistribusikan sebagai biner Linux glibc ARM64.
   - Karena Android/Termux menggunakan Bionic libc, skrip ini mengompilasi wrapper C ringan (`clang -O2`) yang memanggil glibc dynamic linker (`ld-linux-aarch64.so.1`) secara transparan.

2. **Patching Memori ARM64 untuk Antigravity CLI**:
   - Go runtime ARM64 versi Linux memiliki ekspektasi alokasi ruang alamat memori virtual 48-bit yang berbeda dengan alokasi kernel Android.
   - Pada `install-agy.sh` dan paket DEBIAN `antigravity-cli`, diterapkan patching instruksi ARM64 (rewriting pola opcode dan `immr`/`imms`) sehingga binary aman dari crash `Segmentation Fault`.
   - Versi `1.3.5` dipertahankan sebagai versi default yang stabil dan terverifikasi secara penuh.

---

## 📋 Lisensi
Lisensi MIT - Dibuat untuk memudahkan developer dan komunitas Termux.

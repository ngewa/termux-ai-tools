#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools Doctor & Diagnostics Script
# Memeriksa kesehatan lingkungan, glibc, sertifikat TLS, memori, biner & auth.
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
CERT_PEM="$PREFIX/etc/tls/cert.pem"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

PASS="${GREEN}✔ PASS${RESET}"
WARN="${YELLOW}⚠ WARN${RESET}"
FAIL="${RED}✖ FAIL${RESET}"

TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
ERRORS=0

AUTO_FIX=false
for arg in "$@"; do
    if [ "$arg" = "--fix" ] || [ "$arg" = "-f" ]; then
        AUTO_FIX=true
    fi
done

echo -e "\n${BOLD}${CYAN}=================================================="
echo "    🩺 Termux AI Tools - System & Health Doctor    "
echo -e "==================================================${RESET}\n"

# ------------------------------------------------------------------------------
# 1. Pengecekan Sistem & Arsitektur
# ------------------------------------------------------------------------------
echo -e "${BOLD}1. Sistem & Arsitektur:${RESET}"

# CPU Architecture
ARCH="$(uname -m)"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$ARCH" = "aarch64" ]; then
    echo -e "  [${PASS}] Arsitektur CPU: ${GREEN}aarch64 (ARM64)${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${FAIL}] Arsitektur CPU: ${RED}$ARCH${RESET} (Hanya aarch64 yang didukung)"
    ERRORS=$((ERRORS + 1))
fi

# Kernel & OS
KERNEL_VER="$(uname -r 2>/dev/null || echo 'Unknown')"
echo -e "  [${PASS}] Kernel Linux: ${CYAN}$KERNEL_VER${RESET}"

# Storage Space (using df -k for Toybox/Termux compatibility)
FREE_DISK_KB=$(df -k "$PREFIX" 2>/dev/null | awk 'NR==2 {print $4}')
FREE_DISK_MB=$(( ${FREE_DISK_KB:-0} / 1024 ))
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ "$FREE_DISK_MB" -gt 2048 ] 2>/dev/null; then
    echo -e "  [${PASS}] Ruang Penyimpanan: ${GREEN}$((FREE_DISK_MB / 1024)) GB bebas${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
elif [ "$FREE_DISK_MB" -gt 500 ] 2>/dev/null; then
    echo -e "  [${WARN}] Ruang Penyimpanan: ${YELLOW}${FREE_DISK_MB} MB bebas${RESET} (Disarankan minimal 1 GB)"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "  [${FAIL}] Ruang Penyimpanan kritis: ${RED}${FREE_DISK_MB} MB bebas${RESET}"
    ERRORS=$((ERRORS + 1))
fi


# ------------------------------------------------------------------------------
# 2. Lingkungan glibc & Dynamic Linker
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}2. Lingkungan glibc & Dynamic Linker:${RESET}"

# glibc loader check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -x "$LOADER" ]; then
    echo -e "  [${PASS}] glibc dynamic loader: ${GREEN}$LOADER${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${FAIL}] glibc dynamic loader ${RED}tidak ditemukan${RESET}!"
    ERRORS=$((ERRORS + 1))
    if [ "$AUTO_FIX" = "true" ]; then
        echo -e "         ${CYAN}[Auto-Fix] Menginstall glibc-repo dan glibc...${RESET}"
        apt-get update -y && apt-get install -y glibc-repo glibc
    fi
fi

# glibc libc.so.6 check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "$PREFIX/glibc/lib/libc.so.6" ]; then
    echo -e "  [${PASS}] glibc core libraries: ${GREEN}libc.so.6 terdeteksi${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${FAIL}] glibc core libraries: ${RED}libc.so.6 tidak ditemukan${RESET}"
    ERRORS=$((ERRORS + 1))
fi

# glibc dynamic linker cache check (mencegah bad ELF magic 2f2a2047 pada biner Termux/Bionic)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "$PREFIX/glibc/etc/ld.so.cache" ]; then
    echo -e "  [${PASS}] glibc dynamic linker cache: ${GREEN}ld.so.cache aktif${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
elif [ -x "$PREFIX/glibc/bin/ldconfig" ]; then
    echo -e "  [${WARN}] glibc dynamic linker cache: ${YELLOW}belum dibuat (ld.so.cache)${RESET}"
    WARNINGS=$((WARNINGS + 1))
    if [ "$AUTO_FIX" = "true" ]; then
        echo -e "         ${CYAN}[Auto-Fix] Mengonfigurasi ld.so.conf dan menjalankan ldconfig...${RESET}"
        mkdir -p "$PREFIX/glibc/etc"
        if ! grep -qsF "$PREFIX/glibc/lib" "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null; then
            echo "$PREFIX/glibc/lib" >> "$PREFIX/glibc/etc/ld.so.conf"
        fi
        chmod 644 "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null || true
        "$PREFIX/glibc/bin/ldconfig" >/dev/null 2>&1 || true
    fi
else
    echo -e "  [${WARN}] glibc ldconfig: ${YELLOW}tidak ditemukan${RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

# Tools & dependencies
DEPS=("clang" "curl" "tar" "python" "patchelf")
MISSING_DEPS=()
for dep in "${DEPS[@]}"; do
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if command -v "$dep" >/dev/null 2>&1; then
        echo -e "  [${PASS}] Dependensi binary: ${GREEN}$dep${RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${WARN}] Dependensi binary: ${YELLOW}$dep belum terpasang${RESET}"
        MISSING_DEPS+=("$dep")
        WARNINGS=$((WARNINGS + 1))
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ] && [ "$AUTO_FIX" = "true" ]; then
    echo -e "         ${CYAN}[Auto-Fix] Menginstall dependensi: ${MISSING_DEPS[*]}...${RESET}"
    apt-get update -y && apt-get install -y "${MISSING_DEPS[@]}"
fi

# ------------------------------------------------------------------------------
# 3. Jaringan, DNS & Sertifikat TLS/SSL
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}3. Jaringan & Sertifikat TLS/SSL:${RESET}"

# TLS Cert PEM check
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -s "$CERT_PEM" ]; then
    echo -e "  [${PASS}] TLS/SSL Certificate: ${GREEN}$CERT_PEM (${RESET}$(du -h "$CERT_PEM" | cut -f1)${GREEN})${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${FAIL}] TLS/SSL Certificate: ${RED}$CERT_PEM tidak ditemukan atau kosong${RESET}"
    ERRORS=$((ERRORS + 1))
    if [ "$AUTO_FIX" = "true" ]; then
        echo -e "         ${CYAN}[Auto-Fix] Memperbaiki sertifikat ca-certificates...${RESET}"
        apt-get install -y ca-certificates
        mkdir -p "$PREFIX/etc/tls"
        cp "$PREFIX/etc/ssl/certs/ca-certificates.crt" "$CERT_PEM" 2>/dev/null || true
    fi
fi

# HTTPS Connectivity check (GitHub API)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if curl -s --max-time 5 -I "https://api.github.com" >/dev/null 2>&1; then
    echo -e "  [${PASS}] Koneksi HTTPS ke GitHub API: ${GREEN}Normal (200/OK)${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${WARN}] Koneksi HTTPS ke GitHub API: ${YELLOW}Lambat / Gagal terhubung${RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

# HTTPS Connectivity check (npm registry)
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if curl -s --max-time 5 -I "https://registry.npmjs.org" >/dev/null 2>&1; then
    echo -e "  [${PASS}] Koneksi HTTPS ke npm registry: ${GREEN}Normal (200/OK)${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${WARN}] Koneksi HTTPS ke npm registry: ${YELLOW}Lambat / Gagal terhubung${RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

# ------------------------------------------------------------------------------
# 4. Analisis Memori RAM & Swap / zRAM
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}4. Analisis Memori RAM & Swap (OOM Prevention):${RESET}"

MEM_TOTAL_KB=$(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
MEM_AVAIL_KB=$(grep MemAvailable /proc/meminfo 2>/dev/null | awk '{print $2}')
SWAP_TOTAL_KB=$(grep SwapTotal /proc/meminfo 2>/dev/null | awk '{print $2}')
SWAP_FREE_KB=$(grep SwapFree /proc/meminfo 2>/dev/null | awk '{print $2}')

if [ -n "$MEM_TOTAL_KB" ] && [ -n "$MEM_AVAIL_KB" ]; then
    MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
    MEM_AVAIL_MB=$((MEM_AVAIL_KB / 1024))
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ "$MEM_AVAIL_MB" -gt 1500 ]; then
        echo -e "  [${PASS}] RAM Tersedia: ${GREEN}${MEM_AVAIL_MB} MB / ${MEM_TOTAL_MB} MB${RESET} (Sangat aman untuk LLM agent)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    elif [ "$MEM_AVAIL_MB" -gt 600 ]; then
        echo -e "  [${PASS}] RAM Tersedia: ${GREEN}${MEM_AVAIL_MB} MB / ${MEM_TOTAL_MB} MB${RESET} (Cukup)"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${WARN}] RAM Tersedia: ${YELLOW}${MEM_AVAIL_MB} MB${RESET} (Waspada Android OOM Killer saat prompt panjang)"
        WARNINGS=$((WARNINGS + 1))
    fi
fi

if [ -n "$SWAP_TOTAL_KB" ] && [ "$SWAP_TOTAL_KB" -gt 0 ]; then
    SWAP_TOTAL_MB=$((SWAP_TOTAL_KB / 1024))
    SWAP_FREE_MB=$((SWAP_FREE_KB / 1024))
    echo -e "  [${PASS}] Swap / zRAM: ${CYAN}${SWAP_FREE_MB} MB bebas / ${SWAP_TOTAL_MB} MB${RESET}"
else
    echo -e "  [${WARN}] Swap / zRAM: ${YELLOW}Tidak terdeteksi${RESET} (Disarankan mengaktifkan zRAM jika RAM < 4GB)"
fi

# ------------------------------------------------------------------------------
# 5. Status & Integritas Biner AI Tools
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}5. Status & Integritas Biner AI Tools:${RESET}"

# OpenCode v1
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "$PREFIX/bin/opencode" ] && [ -f "$PREFIX/share/opencode/opencode.real" ]; then
    V1_VER=$("$PREFIX/bin/opencode" --version 2>/dev/null || echo "Error")
    if [ "$V1_VER" != "Error" ]; then
        echo -e "  [${PASS}] OpenCode v1: ${GREEN}Terpasang (v${V1_VER})${RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${FAIL}] OpenCode v1: ${RED}Biner tidak dapat dieksekusi${RESET}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  [INFO] OpenCode v1: Belum terpasang di sistem"
fi

# OpenCode v2
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "$PREFIX/bin/opencode-v2" ] && [ -f "$PREFIX/share/opencode-v2/opencode.real" ]; then
    V2_VER=$("$PREFIX/bin/opencode-v2" --version 2>/dev/null || echo "Error")
    if [ "$V2_VER" != "Error" ]; then
        echo -e "  [${PASS}] OpenCode v2: ${GREEN}Terpasang (${V2_VER})${RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${FAIL}] OpenCode v2: ${RED}Biner tidak dapat dieksekusi${RESET}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  [INFO] OpenCode v2: Belum terpasang di sistem"
fi

# Antigravity CLI
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "$PREFIX/bin/agy" ] && [ -f "$PREFIX/share/antigravity-cli/agy.real" ]; then
    AGY_VER=$("$PREFIX/bin/agy" --version 2>/dev/null || echo "Error")
    if [ "$AGY_VER" != "Error" ]; then
        echo -e "  [${PASS}] Antigravity CLI (agy): ${GREEN}Terpasang (v${AGY_VER})${RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${FAIL}] Antigravity CLI: ${RED}Biner gagal dieksekusi${RESET}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "  [INFO] Antigravity CLI: Belum terpasang di sistem"
fi

# ------------------------------------------------------------------------------
# 6. Status Kredensial & Autentikasi
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}6. Status Kredensial & Autentikasi:${RESET}"

# OpenCode Auth
OC_AUTH_FILE="$HOME_DIR/.local/share/opencode/auth.json"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -s "$OC_AUTH_FILE" ]; then
    PROVIDERS=$(grep -E '^[[:space:]]*"[^"]+":[[:space:]]*\{' "$OC_AUTH_FILE" 2>/dev/null | sed -E 's/^[[:space:]]*"([^"]+)".*/\1/' | paste -sd, -)
    echo -e "  [${PASS}] OpenCode Auth: ${GREEN}Terkonfigurasi${RESET} (Provider: ${CYAN}${PROVIDERS:-Aktif}${RESET})"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${WARN}] OpenCode Auth: ${YELLOW}Belum ada API key terdaftar${RESET} (Jalankan 'opencode auth' atau isi opencode.jsonc)"
    WARNINGS=$((WARNINGS + 1))
fi


# Antigravity OAuth Token
AGY_TOKEN_FILE="$HOME_DIR/.gemini/antigravity-cli/antigravity-oauth-token"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -f "$AGY_TOKEN_FILE" ]; then
    # Check permissions
    PERM=$(stat -c "%a" "$AGY_TOKEN_FILE" 2>/dev/null || echo "unknown")
    if [ "$PERM" = "600" ]; then
        echo -e "  [${PASS}] Antigravity OAuth Token: ${GREEN}Tersedia & aman (chmod 600)${RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${WARN}] Antigravity OAuth Token: Izin file ${YELLOW}$PERM${RESET} (Disarankan 600)"
        WARNINGS=$((WARNINGS + 1))
        if [ "$AUTO_FIX" = "true" ]; then
            chmod 600 "$AGY_TOKEN_FILE"
            echo -e "         ${CYAN}[Auto-Fix] Izin file diperbaiki ke 600.${RESET}"
        fi
    fi
else
    echo -e "  [${WARN}] Antigravity OAuth Token: ${YELLOW}Belum login${RESET} (Jalankan 'agy' untuk login via browser)"
    WARNINGS=$((WARNINGS + 1))
fi

# ------------------------------------------------------------------------------
# 7. Knowledge Memory & AI Brain Health
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}7. Knowledge Memory & AI Brain Health:${RESET}"

# Check Python SQLite & FTS5
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if python3 -c "import sqlite3; con=sqlite3.connect(':memory:'); cur=con.cursor(); cur.execute('CREATE VIRTUAL TABLE t USING fts5(c);');" >/dev/null 2>&1; then
    echo -e "  [${PASS}] SQLite3 & Mesin FTS5: ${GREEN}Tersedia & Aktif (High Speed Search)${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "  [${WARN}] SQLite3 FTS5: ${YELLOW}Tidak aktif / Fallback ke LIKE${RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

# Check Memory DB and directory permissions
MEMORY_DIR="$HOME_DIR/.local/share/termux-ai"
MEMORY_DB="$MEMORY_DIR/memory.db"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [ -d "$MEMORY_DIR" ]; then
    DIR_PERM=$(stat -c "%a" "$MEMORY_DIR" 2>/dev/null || echo "unknown")
    if [ "$DIR_PERM" = "700" ]; then
        echo -e "  [${PASS}] Knowledge Memory Storage: ${GREEN}Aman (chmod 700)${RESET}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        echo -e "  [${WARN}] Knowledge Memory Storage: Izin direktori ${YELLOW}$DIR_PERM${RESET} (Disarankan 700)"
        WARNINGS=$((WARNINGS + 1))
        if [ "$AUTO_FIX" = "true" ]; then
            chmod 700 "$MEMORY_DIR"
            [ -f "$MEMORY_DB" ] && chmod 600 "$MEMORY_DB"
            echo -e "         ${CYAN}[Auto-Fix] Izin direktori diperbaiki ke 700.${RESET}"
        fi
    fi
else
    echo -e "  [${PASS}] Knowledge Memory Storage: ${GREEN}Siap diinisialisasi${RESET}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

# ------------------------------------------------------------------------------
# 8. Ringkasan Diagnostik & Skor Kesehatan
# ------------------------------------------------------------------------------
echo -e "\n${BOLD}${CYAN}=================================================="
echo "               Ringkasan Diagnostik               "
echo -e "==================================================${RESET}"


if [ "$TOTAL_CHECKS" -gt 0 ]; then
    HEALTH_SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    HEALTH_SCORE=100
fi

echo -e "Total Pengecekan : $TOTAL_CHECKS"
echo -e "Lolos (Pass)     : ${GREEN}$PASSED_CHECKS${RESET}"
echo -e "Peringatan (Warn): ${YELLOW}$WARNINGS${RESET}"
echo -e "Masalah (Error)  : ${RED}$ERRORS${RESET}"
echo -e "Skor Kesehatan   : ${BOLD}${CYAN}${HEALTH_SCORE}%${RESET}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 SEMUA SISTEM NORMAL! Lingkungan Termux AI Tools 100% prima.${RESET}\n"
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}✔ Sistem berfungsi dengan baik, ada $WARNINGS peringatan ringan yang dapat diabaikan atau disesuaikan.${RESET}\n"
else
    echo -e "${RED}${BOLD}✖ Ditemukan $ERRORS masalah kritis yang perlu diperbaiki!${RESET}"
    echo -e "Jalankan perintah ini untuk perbaikan otomatis: ${BOLD}./doctor.sh --fix${RESET}\n"
fi

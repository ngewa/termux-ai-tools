#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# OpenCode Installer & Updater for Termux (glibc environment)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SHARE_DIR="$PREFIX/share/opencode"
BIN_DIR="$PREFIX/bin"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
REAL_BIN="$SHARE_DIR/opencode.real"
LIB_PATH="$PREFIX/glibc/lib"
TMP_DIR="${TMPDIR:-$PREFIX/tmp}/opencode-install-$$"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err() { echo -e "${RED}[ERROR]${RESET} $1"; }

# 1. Check prerequisites
log_info "Memeriksa dependensi sistem..."
MISSING_PKGS=()
for pkg in clang curl tar; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ! -f "$LOADER" ]; then
    MISSING_PKGS+=("glibc")
fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warn "Menginstall dependensi yang dibutuhkan: ${MISSING_PKGS[*]}..."
    apt-get update -y
    apt-get install -y "${MISSING_PKGS[@]}"
fi

# 2. Determine version to install
TARGET_VERSION="$1"
if [ -z "$TARGET_VERSION" ]; then
    log_info "Mencari versi terbaru OpenCode v1 dari GitHub releases..."
    LATEST_TAG=$(curl -sL https://api.github.com/repos/anomalyco/opencode/releases?per_page=30 | grep '"tag_name":' | grep '"v1\.' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    TARGET_VERSION="${LATEST_TAG#v}"
    if [ -z "$TARGET_VERSION" ]; then
        log_warn "Gagal mendeteksi via API GitHub, menggunakan default v1.19.4"
        TARGET_VERSION="1.19.4"
    fi
else
    TARGET_VERSION="${TARGET_VERSION#v}"
fi

# Check current version
if [ -f "$REAL_BIN" ]; then
    CURRENT_VERSION=$("$BIN_DIR/opencode" --version 2>/dev/null || echo "unknown")
    log_info "Versi terpasang saat ini : $CURRENT_VERSION"
    log_info "Target versi instalasi   : $TARGET_VERSION"
    if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ] && [ "$2" != "--force" ]; then
        log_ok "OpenCode sudah versi terbaru ($CURRENT_VERSION). Gunakan --force untuk reinstall."
        exit 0
    fi
fi

# 3. Download & extract
mkdir -p "$SHARE_DIR" "$BIN_DIR" "$TMP_DIR"
TARFILE="opencode-linux-arm64.tar.gz"
DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/download/v${TARGET_VERSION}/${TARFILE}"

log_info "Mengunduh OpenCode v${TARGET_VERSION} ($TARFILE)..."
if ! curl -fSL -o "$TMP_DIR/opencode.tar.gz" "$DOWNLOAD_URL"; then
    log_err "Gagal mengunduh $DOWNLOAD_URL"
    rm -rf "$TMP_DIR"
    exit 1
fi

log_info "Mengekstrak binary ke $SHARE_DIR..."
if [ -f "$REAL_BIN" ]; then
    cp "$REAL_BIN" "${REAL_BIN}.bak" || true
fi

tar -xzf "$TMP_DIR/opencode.tar.gz" -C "$TMP_DIR"
if [ ! -f "$TMP_DIR/opencode" ]; then
    log_err "Binary opencode tidak ditemukan di dalam arsip!"
    rm -rf "$TMP_DIR"
    exit 1
fi

mv "$TMP_DIR/opencode" "$REAL_BIN"
chmod +x "$REAL_BIN"

# 4. Compile C wrapper if needed
WRAPPER_BIN="$BIN_DIR/opencode"
log_info "Menyiapkan wrapper C di $WRAPPER_BIN..."

cat > "$TMP_DIR/opencode_helper.c" << 'EOF'
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <libgen.h>
#include <limits.h>
#include <stdio.h>

int main(int argc, char** argv) {
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");

    setenv("GODEBUG", "netdns=cgo", 1);
    setenv("SSL_CERT_FILE", "/data/data/com.termux/files/usr/etc/tls/cert.pem", 1);

    char* loader = "/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1";
    char real_bin[] = "/data/data/com.termux/files/usr/share/opencode/opencode.real";
    char lib_path[] = "/data/data/com.termux/files/usr/glibc/lib";

    char** new_argv = malloc((argc + 4) * sizeof(char*));
    if (!new_argv) {
        return 1;
    }

    new_argv[0] = loader;
    new_argv[1] = "--library-path";
    new_argv[2] = lib_path;
    new_argv[3] = real_bin;

    for (int i = 1; i < argc; i++) {
        new_argv[i + 3] = argv[i];
    }
    new_argv[argc + 3] = NULL;

    execv(loader, new_argv);
    perror("execv");
    free(new_argv);
    return 1;
}
EOF

clang -O2 -o "$WRAPPER_BIN" "$TMP_DIR/opencode_helper.c"
chmod +x "$WRAPPER_BIN"
rm -rf "$TMP_DIR"

# 5. Verification
NEW_VER=$("$WRAPPER_BIN" --version 2>/dev/null || echo "error")
log_ok "OpenCode v${NEW_VER} berhasil dipasang & siap digunakan!"
log_info "Jalankan 'opencode' di terminal Termux Anda."

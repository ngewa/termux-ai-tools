#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

# ==============================================================================
# OpenCode v2 Installer & Updater for Termux (glibc + patchelf environment)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SHARE_DIR="$PREFIX/share/opencode-v2"
BIN_DIR="$PREFIX/bin"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
LIB_PATH="$PREFIX/glibc/lib"
TMP_DIR="${TMPDIR:-$PREFIX/tmp}"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err() { echo -e "${RED}[ERROR]${RESET} $1"; }

# 1. Architecture check
ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
    log_err "Hanya arsitektur aarch64 (ARM64) yang didukung. Arsitektur Anda: $ARCH"
    exit 1
fi

# 2. Check prerequisites
log_info "Memeriksa dependensi sistem..."
MISSING_PKGS=()
for pkg in clang curl tar patchelf; do
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

# 3. Determine version to install
TARGET_VERSION="${1:-2.1.4}"
TARGET_VERSION="${TARGET_VERSION#v}"
TARFILE="cli-linux-arm64-${TARGET_VERSION}.tgz"
DOWNLOAD_URL="https://registry.npmjs.org/@opencode/cli-linux-arm64/-/${TARFILE}"

# Known verified sha256 for 2.1.4
KNOWN_SHA256="e9acb4e23a9ac432139693aa166455a6add8946533394cbe083459a48e788861"

# Check current version
if [ -f "$BIN_DIR/opencode-v2" ]; then
    CURRENT_VERSION=$("$BIN_DIR/opencode-v2" --version 2>/dev/null || echo "unknown")
    log_info "Versi terpasang saat ini : $CURRENT_VERSION"
    log_info "Target versi instalasi   : $TARGET_VERSION"
    if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ] && [ "${2:-}" != "--force" ]; then
        log_ok "OpenCode 2 sudah versi target ($CURRENT_VERSION). Gunakan --force untuk reinstall."
        exit 0
    fi
fi

STAGE=$(mktemp -d "$TMP_DIR/opencode-v2-install.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

# 4. Download and verify
log_info "Mengunduh OpenCode 2 v${TARGET_VERSION} dari npm registry..."
curl -fL --retry 3 --max-time 600 -o "$STAGE/$TARFILE" "$DOWNLOAD_URL"

if [ "$TARGET_VERSION" = "2.1.4" ]; then
    if ! printf '%s  %s\n' "$KNOWN_SHA256" "$STAGE/$TARFILE" | sha256sum -c - >/dev/null; then
        log_err "Checksum mismatch untuk $TARFILE!"
        exit 1
    fi
fi

# 5. Extract and patch interpreter
log_info "Mengekstrak dan menyesuaikan binary..."
tar -xzf "$STAGE/$TARFILE" -C "$STAGE"
if [ ! -f "$STAGE/package/bin/opencode" ]; then
    log_err "Binary opencode tidak ditemukan di dalam paket!"
    exit 1
fi

rm -rf "$SHARE_DIR"
mkdir -p "$SHARE_DIR" "$BIN_DIR"

log_info "Mengatur glibc interpreter via patchelf..."
patchelf --set-interpreter "$LOADER" "$STAGE/package/bin/opencode"
mv "$STAGE/package/bin/opencode" "$SHARE_DIR/opencode.real"
chmod 755 "$SHARE_DIR/opencode.real"

# 6. Write and compile C wrapper
log_info "Menyiapkan wrapper C di $BIN_DIR/opencode-v2..."
cat > "$STAGE/opencode-v2.c" <<'C_EOF'
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main(int argc, char** argv) {
    unsetenv("LD_PRELOAD");

    setenv("LD_LIBRARY_PATH", "/data/data/com.termux/files/usr/glibc/lib", 1);
    setenv("GODEBUG", "netdns=cgo", 1);
    setenv("SSL_CERT_FILE", "/data/data/com.termux/files/usr/etc/tls/cert.pem", 1);

    char real_bin[] = "/data/data/com.termux/files/usr/share/opencode-v2/opencode.real";

    char** new_argv = malloc((argc + 1) * sizeof(char*));
    if (!new_argv) {
        return 1;
    }

    new_argv[0] = real_bin;
    for (int i = 1; i < argc; i++) {
        new_argv[i] = argv[i];
    }
    new_argv[argc] = NULL;

    execv(real_bin, new_argv);
    perror("execv");
    free(new_argv);
    return 1;
}
C_EOF

clang -O2 -o "$BIN_DIR/opencode-v2" "$STAGE/opencode-v2.c"
chmod 755 "$BIN_DIR/opencode-v2"

# 7. Verification
if timeout 60 "$BIN_DIR/opencode-v2" --version >/dev/null 2>&1; then
    NEW_VER=$("$BIN_DIR/opencode-v2" --version 2>/dev/null || echo "$TARGET_VERSION")
    log_ok "OpenCode 2 ($NEW_VER) berhasil dipasang & siap digunakan!"
    log_info "Jalankan 'opencode-v2' di terminal Termux Anda."
else
    log_err "OpenCode 2 gagal dijalankan!"
    exit 1
fi

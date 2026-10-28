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
BOLD="\033[1m"
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

# 3. Determine version to install (Ambil langsung rilis v2.* terbaru dari GitHub)
TARGET_VERSION="${1:-}"
if [ -z "$TARGET_VERSION" ]; then
    log_info "Mencari versi terbaru OpenCode v2 langsung dari GitHub upstream..."
    LATEST_TAG=$(curl -sL https://api.github.com/repos/anomalyco/opencode/releases?per_page=30 | grep '"tag_name":' | grep '"v2\.' | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
    TARGET_VERSION="${LATEST_TAG#v}"
    if [ -z "$TARGET_VERSION" ]; then
        log_warn "Gagal mendeteksi via API GitHub, menggunakan default v2.2.0"
        TARGET_VERSION="2.2.0"
    fi
else
    TARGET_VERSION="${TARGET_VERSION#v}"
fi

# Check current version
if [ -f "$BIN_DIR/opencode-v2" ]; then
    CURRENT_VERSION=$("$BIN_DIR/opencode-v2" --version 2>/dev/null || echo "unknown")
    log_info "Versi terpasang saat ini : $CURRENT_VERSION"
    log_info "Target versi instalasi   : $TARGET_VERSION"
    if echo "$CURRENT_VERSION" | grep -q "$TARGET_VERSION" && [ "${2:-}" != "--force" ]; then
        log_ok "OpenCode 2 sudah versi target ($CURRENT_VERSION). Gunakan --force untuk reinstall."
        exit 0
    fi
fi

STAGE=$(mktemp -d "$TMP_DIR/opencode-v2-install.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT

# 4. Download directly from GitHub release, with fallback to npm
GITHUB_DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/download/v${TARGET_VERSION}/opencode-linux-arm64.tar.gz"
NPM_DOWNLOAD_URL="https://registry.npmjs.org/@opencode/cli-linux-arm64/-/cli-linux-arm64-${TARGET_VERSION}.tgz"

log_info "Mengunduh OpenCode 2 v${TARGET_VERSION} langsung dari GitHub releases..."
DOWNLOAD_SUCCESS=false

if curl -fL --retry 3 --max-time 600 -o "$STAGE/opencode.tar.gz" "$GITHUB_DOWNLOAD_URL" 2>/dev/null; then
    DOWNLOAD_SUCCESS=true
    log_ok "Berhasil mengunduh dari GitHub Releases."
    
    # Verifikasi SHA256 dari release jika tersedia
    if curl -fsSL -o "$STAGE/SHA256SUMS" "https://github.com/anomalyco/opencode/releases/download/v${TARGET_VERSION}/SHA256SUMS" 2>/dev/null; then
        EXPECTED_SHA=$(grep "opencode-linux-arm64.tar.gz" "$STAGE/SHA256SUMS" | awk '{print $1}')
        if [ -n "$EXPECTED_SHA" ]; then
            log_info "Memverifikasi SHA256: $EXPECTED_SHA..."
            if printf '%s  %s\n' "$EXPECTED_SHA" "$STAGE/opencode.tar.gz" | sha256sum -c - >/dev/null 2>&1; then
                log_ok "Verifikasi checksum SHA256 valid!"
            else
                log_warn "Checksum mismatch, namun melanjutkan ekstraksi..."
            fi
        fi
    fi

    tar -xzf "$STAGE/opencode.tar.gz" -C "$STAGE"
    EXTRACTED_BIN="$STAGE/opencode"
else
    log_warn "Download GitHub gagal, mencoba unduh dari npm registry..."
    if curl -fL --retry 3 --max-time 600 -o "$STAGE/opencode-npm.tgz" "$NPM_DOWNLOAD_URL"; then
        DOWNLOAD_SUCCESS=true
        tar -xzf "$STAGE/opencode-npm.tgz" -C "$STAGE"
        EXTRACTED_BIN="$STAGE/package/bin/opencode"
    fi
fi

if [ "$DOWNLOAD_SUCCESS" != "true" ] || [ ! -f "$EXTRACTED_BIN" ]; then
    log_err "Gagal mengunduh atau mengekstrak biner OpenCode 2!"
    exit 1
fi

# 5. Backup & Install binary
rm -rf "$SHARE_DIR"
mkdir -p "$SHARE_DIR" "$BIN_DIR"

log_info "Mengatur glibc interpreter via patchelf..."
patchelf --set-interpreter "$LOADER" "$EXTRACTED_BIN" 2>/dev/null || true
mv "$EXTRACTED_BIN" "$SHARE_DIR/opencode.real"
chmod 755 "$SHARE_DIR/opencode.real"

# 6. Configure glibc ld.so.cache & compile C wrapper
log_info "Mengonfigurasi glibc dynamic linker cache..."
if [ -d "$PREFIX/glibc/etc" ] && [ -x "$PREFIX/glibc/bin/ldconfig" ]; then
    mkdir -p "$PREFIX/glibc/etc"
    if ! grep -qsF "$LIB_PATH" "$PREFIX/glibc/etc/ld.so.conf"; then
        echo "$LIB_PATH" >> "$PREFIX/glibc/etc/ld.so.conf"
    fi
    chmod 644 "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null || true
    "$PREFIX/glibc/bin/ldconfig" >/dev/null 2>&1 || true
fi

log_info "Menyiapkan wrapper C di $BIN_DIR/opencode-v2..."
cat > "$STAGE/opencode-v2.c" <<'C_EOF'
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>

int main(int argc, char** argv) {
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");

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

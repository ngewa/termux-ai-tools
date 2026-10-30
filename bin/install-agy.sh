#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Antigravity CLI (agy) Installer & Updater for Termux (glibc environment)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SHARE_DIR="$PREFIX/share/antigravity-cli"
BIN_DIR="$PREFIX/bin"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
PATCHED_BIN="$SHARE_DIR/agy.real"
LIB_PATH="$PREFIX/glibc/lib"
TMP_DIR="${TMPDIR:-$PREFIX/tmp}/agy-install-$$"

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
for pkg in clang curl tar python; do
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
# Catatan: v1.3.5 adalah versi paling stabil dengan verified ARM64 memory patch untuk Termux.
TARGET_VERSION="$1"
if [ -z "$TARGET_VERSION" ]; then
    TARGET_VERSION="1.3.5"
else
    TARGET_VERSION="${TARGET_VERSION#v}"
fi

# Check current version
if [ -f "$PATCHED_BIN" ]; then
    CURRENT_VERSION=$("$BIN_DIR/agy" --version 2>/dev/null || echo "unknown")
    log_info "Versi terpasang saat ini : $CURRENT_VERSION"
    log_info "Target versi instalasi   : $TARGET_VERSION"
    if [ "$CURRENT_VERSION" = "$TARGET_VERSION" ] && [ "$2" != "--force" ]; then
        log_ok "Antigravity CLI sudah versi target ($CURRENT_VERSION). Gunakan --force untuk reinstall."
        exit 0
    fi
fi

# 3. Download & staging
mkdir -p "$SHARE_DIR" "$BIN_DIR" "$TMP_DIR"
DOWNLOAD_URL="https://github.com/google-antigravity/antigravity-cli/releases/download/${TARGET_VERSION}/agy_cli_linux_arm64.tar.gz"

log_info "Mengunduh Antigravity CLI v${TARGET_VERSION}..."
if ! curl -fSL -o "$TMP_DIR/agy.tar.gz" "$DOWNLOAD_URL"; then
    DOWNLOAD_URL_V="https://github.com/google-antigravity/antigravity-cli/releases/download/v${TARGET_VERSION}/agy_cli_linux_arm64.tar.gz"
    log_warn "Mencoba URL alternatif dengan awalan 'v': $DOWNLOAD_URL_V..."
    if ! curl -fSL -o "$TMP_DIR/agy.tar.gz" "$DOWNLOAD_URL_V"; then
        log_err "Gagal mengunduh Antigravity CLI v${TARGET_VERSION} dari GitHub Releases!"
        rm -rf "$TMP_DIR"
        exit 1
    fi
fi

log_info "Mengekstrak arsip..."
tar -xzf "$TMP_DIR/agy.tar.gz" -C "$TMP_DIR"

if [ -f "$TMP_DIR/antigravity" ]; then
    ORIG_BIN="$TMP_DIR/antigravity"
elif [ -f "$TMP_DIR/agy" ]; then
    ORIG_BIN="$TMP_DIR/agy"
else
    log_err "Binary tidak ditemukan dalam arsip!"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Backup current binary if exists
if [ -f "$PATCHED_BIN" ]; then
    cp "$PATCHED_BIN" "${PATCHED_BIN}.bak" || true
fi

# 4. Apply ARM64 memory layout patching (Go runtime virtual address fix on Android)
log_info "Menerapkan ARM64 memory patch untuk Android/Termux..."
python3 - << 'PYEOF' "$ORIG_BIN" "$PATCHED_BIN"
import sys, struct, pathlib

src = sys.argv[1]
dst = sys.argv[2]

data = bytearray(pathlib.Path(src).read_bytes())

def get(off):
    return struct.unpack_from("<I", data, off)[0]

def put(off, word):
    struct.pack_into("<I", data, off, word)

lo, hi = 0, len(data)

# immr/imms fixes
for off in range(lo, hi, 4):
    w = get(off)
    if (w & 0x7F800000) == 0x53000000:
        immr = (w >> 16) & 0x3F
        imms = (w >> 10) & 0x3F
        if immr == 42 and imms == 44:
            put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (35 << 16) | (37 << 10))
        elif immr == 22 and imms == 21:
            put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (29 << 16) | (28 << 10))

# two-instruction pattern
for off in range(lo, hi-4, 4):
    if get(off) == 0x92D3800A and get(off+4) == 0xF2E0000A:
        put(off, 0x9280000A)
        put(off+4, 0xD35DFD4A)

# single instruction
for off in range(lo, hi, 4):
    if get(off) == 0xF2E00029:
        put(off, 0xD3596129)

# word rewrites
rewrites = {
    0xD2C20009: 0xD2C00409, 0xD2C2000A: 0xD2C0040A, 0xF2C20008: 0xF2DFF408,
    0xF2C20009: 0xF2DFF409, 0xD2C10009: 0xD2C00209, 0xD2C1000A: 0xD2C0020A,
    0xF2C38008: 0xF2DFF708, 0xF2C38009: 0xF2DFF709, 0x92560A6C: 0x925D0A6C,
    0x92560A6A: 0x925D0A6A, 0xD2C3000D: 0xD2C0060D, 0xD2C3000C: 0xD2C0060C,
    0xD2C08008: 0xD2C00108,
}
for off in range(lo, hi, 4):
    w = get(off)
    if w in rewrites:
        put(off, rewrites[w])

# three-instruction pattern
for off in range(0, len(data)-12, 4):
    if get(off) == 0xAA1F03E5 and get(off+4) == 0xAA1F03E6 and get(off+8) == 0xD28036E0 and (get(off+12) & 0xFC000000) == 0x94000000:
        put(off+8, 0xD2800600)

pathlib.Path(dst).write_bytes(data)
PYEOF

chmod +x "$PATCHED_BIN"

# 5. Compile C wrapper
WRAPPER_BIN="$BIN_DIR/agy"
log_info "Menyiapkan wrapper C di $WRAPPER_BIN..."

cat > "$TMP_DIR/agy_wrapper.c" << 'EOF'
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

int main(int argc, char** argv) {
    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");
    setenv("GODEBUG", "netdns=cgo", 1);
    setenv("SSL_CERT_FILE", "/data/data/com.termux/files/usr/etc/tls/cert.pem", 1);

    char* loader = "/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1";
    char real_bin[] = "/data/data/com.termux/files/usr/share/antigravity-cli/agy.real";
    char lib_path[] = "/data/data/com.termux/files/usr/glibc/lib";

    char** new_argv = malloc((argc + 4) * sizeof(char*));
    if (!new_argv) return 1;
    new_argv[0] = loader;
    new_argv[1] = "--library-path";
    new_argv[2] = lib_path;
    new_argv[3] = real_bin;
    for (int i = 1; i < argc; i++) new_argv[i + 3] = argv[i];
    new_argv[argc + 3] = NULL;

    execv(loader, new_argv);
    perror("execv");
    free(new_argv);
    return 1;
}
EOF

clang -O2 -o "$WRAPPER_BIN" "$TMP_DIR/agy_wrapper.c"
chmod +x "$WRAPPER_BIN"
rm -rf "$TMP_DIR"

# 6. Verification
NEW_VER=$("$WRAPPER_BIN" --version 2>/dev/null || echo "error")
log_ok "Antigravity CLI v${NEW_VER} berhasil dipasang!"
log_info "Jalankan 'agy' di terminal Termux Anda."

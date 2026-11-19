#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Antigravity CLI (agy) Installer, Updater & Self-Healing Wrapper for Termux
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SHARE_DIR="$PREFIX/share/antigravity-cli"
BIN_DIR="$PREFIX/bin"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
PATCHED_BIN="$SHARE_DIR/agy.real"
PATCH_HELPER="$SHARE_DIR/patch-agy.sh"
WRAPPER_BIN="$BIN_DIR/agy"
LIB_PATH="$PREFIX/glibc/lib"
CERT_PEM="$PREFIX/etc/tls/cert.pem"
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

cleanup_tmp() {
    rm -rf "$TMP_DIR"
}
trap cleanup_tmp EXIT

ensure_glibc_ldcache() {
    if [ -d "$PREFIX/glibc/etc" ] && [ -x "$PREFIX/glibc/bin/ldconfig" ]; then
        mkdir -p "$PREFIX/glibc/etc"
        if ! grep -qsF "$LIB_PATH" "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null; then
            echo "$LIB_PATH" >> "$PREFIX/glibc/etc/ld.so.conf"
        fi
        chmod 644 "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null || true
        "$PREFIX/glibc/bin/ldconfig" >/dev/null 2>&1 || true
    fi
}

install_patch_helper() {
    mkdir -p "$SHARE_DIR"
    local tmp_helper="$SHARE_DIR/.patch-agy.sh.tmp.$$"
    cat > "$tmp_helper" << 'HELPER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Antigravity CLI (agy) Atomic ARM64 + GLIBC Interpreter Self-Healing Patcher
# Dipanggil otomatis oleh wrapper C jika AGY self-update menimpa agy.real.
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
SHARE_DIR="$PREFIX/share/antigravity-cli"
LOADER="$PREFIX/glibc/lib/ld-linux-aarch64.so.1"
LIB_PATH="$PREFIX/glibc/lib"
CERT_PEM="$PREFIX/etc/tls/cert.pem"
TARGET_BIN="${1:-$SHARE_DIR/agy.real}"
FORCE_PATCH=false
if [ "${2:-}" = "--force" ] || [ "${1:-}" = "--force" ]; then
    FORCE_PATCH=true
    [ "${1:-}" = "--force" ] && TARGET_BIN="$SHARE_DIR/agy.real"
fi

BACKUP_BIN="${TARGET_BIN}.bak"
TARGET_DIR="$(dirname "$TARGET_BIN")"
LOCK_DIR="$TARGET_DIR/.patch-agy.lock"
STAGING_BIN=""

cleanup_lock() {
    [ -n "$STAGING_BIN" ] && rm -f "$STAGING_BIN" 2>/dev/null || true
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

# Acquire lock (avoid concurrent patching race)
LOCK_WAIT=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    LOCK_WAIT=$((LOCK_WAIT + 1))
    if [ "$LOCK_WAIT" -gt 60 ]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
        mkdir "$LOCK_DIR" 2>/dev/null || true
        break
    fi
    sleep 0.5
done
trap cleanup_lock EXIT

ensure_ldcache() {
    if [ -d "$PREFIX/glibc/etc" ] && [ -x "$PREFIX/glibc/bin/ldconfig" ]; then
        mkdir -p "$PREFIX/glibc/etc"
        if ! grep -qsF "$LIB_PATH" "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null; then
            echo "$LIB_PATH" >> "$PREFIX/glibc/etc/ld.so.conf"
        fi
        chmod 644 "$PREFIX/glibc/etc/ld.so.conf" 2>/dev/null || true
        "$PREFIX/glibc/bin/ldconfig" >/dev/null 2>&1 || true
    fi
}

verify_binary() {
    local bin="$1"
    env -u LD_PRELOAD -u LD_LIBRARY_PATH \
        GODEBUG="netdns=cgo" \
        SSL_CERT_FILE="$CERT_PEM" \
        "$bin" --version >/dev/null 2>&1
}

# If target binary is missing, try restoring from backup
if [ ! -f "$TARGET_BIN" ]; then
    if [ -f "$BACKUP_BIN" ]; then
        echo "[agy-patch] $TARGET_BIN tidak ditemukan, memulihkan dari backup..." >&2
        cp "$BACKUP_BIN" "$TARGET_BIN"
        chmod +x "$TARGET_BIN"
    else
        echo "[agy-patch] ERROR: $TARGET_BIN dan backup tidak ditemukan." >&2
        exit 1
    fi
fi

if [ ! -x "$LOADER" ]; then
    echo "[agy-patch] ERROR: glibc loader tidak ditemukan di $LOADER" >&2
    exit 1
fi

if ! command -v patchelf >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    echo "[agy-patch] ERROR: Membutuhkan 'patchelf' dan 'python3' untuk auto-patch." >&2
    exit 1
fi

CUR_INTERP=$(patchelf --print-interpreter "$TARGET_BIN" 2>/dev/null || echo "")
if [ "$FORCE_PATCH" = "false" ] && [ "$CUR_INTERP" = "$LOADER" ]; then
    exit 0
fi

STAGING_BIN="$TARGET_DIR/.agy.real.staging.$$"

# Apply ARM64 memory layout patch (Go runtime 48-bit -> 39-bit VA for Android)
# Fast C-speed byte search (~1-2s on 250MB binary instead of >60s pure Python loop)
python3 - << 'PYEOF' "$TARGET_BIN" "$STAGING_BIN"
import sys, struct, pathlib, re

src = sys.argv[1]
dst = sys.argv[2]

raw = pathlib.Path(src).read_bytes()
data = bytearray(raw)
n = len(data)

def get(off):
    return struct.unpack_from("<I", data, off)[0]

def put(off, word):
    struct.pack_into("<I", data, off, word)

# 1. immr/imms fixes: (w & 0x7F800000) == 0x53000000
#    immr=42,imms=44 -> b1 in 0xB0..0xB3, b2 in {0x2A,0x6A}, b3 in {0x53,0xD3}
#    immr=22,imms=21 -> b1 in 0x54..0x57, b2 in {0x16,0x56}, b3 in {0x53,0xD3}
pat_imm = re.compile(rb"[\xb0-\xb3][\x2a\x6a][\x53\xd3]|[\x54-\x57][\x16\x56][\x53\xd3]")
for m in pat_imm.finditer(raw):
    off = m.start() - 1
    if off >= 0 and (off & 3) == 0:
        w = get(off)
        if (w & 0x7F800000) == 0x53000000:
            immr = (w >> 16) & 0x3F
            imms = (w >> 10) & 0x3F
            if immr == 42 and imms == 44:
                put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (35 << 16) | (37 << 10))
            elif immr == 22 and imms == 21:
                put(off, (w & ~((0x3F << 16) | (0x3F << 10))) | (29 << 16) | (28 << 10))

# 2. two-instruction pattern
needle2 = struct.pack("<II", 0x92D3800A, 0xF2E0000A)
pos = 0
while True:
    idx = raw.find(needle2, pos)
    if idx == -1:
        break
    if (idx & 3) == 0:
        put(idx, 0x9280000A)
        put(idx + 4, 0xD35DFD4A)
    pos = idx + 1

# 3. single instruction & word rewrites
rewrites = {
    0xF2E00029: 0xD3596129,
    0xD2C20009: 0xD2C00409, 0xD2C2000A: 0xD2C0040A, 0xF2C20008: 0xF2DFF408,
    0xF2C20009: 0xF2DFF409, 0xD2C10009: 0xD2C00209, 0xD2C1000A: 0xD2C0020A,
    0xF2C38008: 0xF2DFF708, 0xF2C38009: 0xF2DFF709, 0x92560A6C: 0x925D0A6C,
    0x92560A6A: 0x925D0A6A, 0xD2C3000D: 0xD2C0060D, 0xD2C3000C: 0xD2C0060C,
    0xD2C08008: 0xD2C00108,
}
for old_w, new_w in rewrites.items():
    needle = struct.pack("<I", old_w)
    pos = 0
    while True:
        idx = raw.find(needle, pos)
        if idx == -1:
            break
        if (idx & 3) == 0:
            put(idx, new_w)
        pos = idx + 1

# 4. three-instruction pattern
needle3 = struct.pack("<III", 0xAA1F03E5, 0xAA1F03E6, 0xD28036E0)
pos = 0
while True:
    idx = raw.find(needle3, pos)
    if idx == -1:
        break
    if (idx & 3) == 0 and idx + 16 <= n:
        if (get(idx + 12) & 0xFC000000) == 0x94000000:
            put(idx + 8, 0xD2800600)
    pos = idx + 1

pathlib.Path(dst).write_bytes(data)
PYEOF

chmod +x "$STAGING_BIN"

if ! patchelf --set-interpreter "$LOADER" "$STAGING_BIN"; then
    echo "[agy-patch] ERROR: Gagal mengatur interpreter glibc pada staging binary." >&2
    exit 1
fi

NEW_INTERP=$(patchelf --print-interpreter "$STAGING_BIN" 2>/dev/null || echo "")
if [ "$NEW_INTERP" != "$LOADER" ]; then
    echo "[agy-patch] ERROR: Interpreter tidak sesuai setelah patch: ${NEW_INTERP:-kosong}" >&2
    exit 1
fi

ensure_ldcache

if ! verify_binary "$STAGING_BIN"; then
    echo "[agy-patch] ERROR: Verifikasi binary baru gagal (--version error)." >&2
    if [ -f "$BACKUP_BIN" ] && verify_binary "$BACKUP_BIN"; then
        echo "[agy-patch] Melakukan rollback ke backup yang sehat ($BACKUP_BIN)..." >&2
        cp "$BACKUP_BIN" "$STAGING_BIN"
        chmod +x "$STAGING_BIN"
        mv -f "$STAGING_BIN" "$TARGET_BIN"
        STAGING_BIN=""
        exit 0
    fi
    exit 1
fi

# Preserve the previous working binary (from AGY's native auto-update *.old) as a single .bak
if [ "$TARGET_BIN" = "$SHARE_DIR/agy.real" ]; then
    LATEST_OLD=$(ls -t "$SHARE_DIR"/agy.real.*.old 2>/dev/null | head -n 1 || true)
    if [ -n "$LATEST_OLD" ] && [ -f "$LATEST_OLD" ]; then
        OLD_INTERP=$(patchelf --print-interpreter "$LATEST_OLD" 2>/dev/null || echo "")
        if [ "$OLD_INTERP" = "$LOADER" ]; then
            mv -f "$LATEST_OLD" "$BACKUP_BIN" 2>/dev/null || true
        fi
    fi
    # Clean up remaining stale .old and .broken-* binaries so storage doesn't balloon
    rm -f "$SHARE_DIR"/agy.real.*.old "$SHARE_DIR"/agy.real.broken-* 2>/dev/null || true
fi

# Atomic swap
mv -f "$STAGING_BIN" "$TARGET_BIN"
STAGING_BIN=""
echo "[agy-patch] Patch Termux berhasil diterapkan." >&2
HELPER_EOF
    chmod 755 "$tmp_helper"
    mv -f "$tmp_helper" "$PATCH_HELPER"
}

compile_wrapper() {
    mkdir -p "$BIN_DIR" "$TMP_DIR"
    log_info "Menyiapkan self-healing wrapper C di $WRAPPER_BIN..."

    cat > "$TMP_DIR/agy_wrapper.c" << 'EOF'
#include <elf.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define REAL_BIN "/data/data/com.termux/files/usr/share/antigravity-cli/agy.real"
#define EXPECTED_INTERP "/data/data/com.termux/files/usr/glibc/lib/ld-linux-aarch64.so.1"
#define PATCH_SCRIPT "/data/data/com.termux/files/usr/share/antigravity-cli/patch-agy.sh"
#define BASH_BIN "/data/data/com.termux/files/usr/bin/bash"
#define CERT_PEM "/data/data/com.termux/files/usr/etc/tls/cert.pem"

static int has_expected_interpreter(const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) return 0;

    Elf64_Ehdr ehdr;
    if (pread(fd, &ehdr, sizeof(ehdr), 0) != (ssize_t)sizeof(ehdr)) {
        close(fd);
        return 0;
    }
    if (memcmp(ehdr.e_ident, ELFMAG, SELFMAG) != 0 ||
        ehdr.e_ident[EI_CLASS] != ELFCLASS64 ||
        ehdr.e_phentsize != sizeof(Elf64_Phdr) ||
        ehdr.e_phnum == 0 || ehdr.e_phnum > 128) {
        close(fd);
        return 0;
    }

    int ok = 0;
    for (uint16_t i = 0; i < ehdr.e_phnum; i++) {
        Elf64_Phdr phdr;
        off_t off = (off_t)ehdr.e_phoff + (off_t)i * (off_t)ehdr.e_phentsize;
        if (pread(fd, &phdr, sizeof(phdr), off) != (ssize_t)sizeof(phdr)) break;
        if (phdr.p_type == PT_INTERP) {
            if (phdr.p_filesz > 0 && phdr.p_filesz < 512) {
                char interp[512];
                ssize_t n = pread(fd, interp, phdr.p_filesz, (off_t)phdr.p_offset);
                if (n == (ssize_t)phdr.p_filesz) {
                    interp[phdr.p_filesz - 1] = '\0';
                    if (strcmp(interp, EXPECTED_INTERP) == 0) {
                        ok = 1;
                    }
                }
            }
            break;
        }
    }
    close(fd);
    return ok;
}

static int run_self_heal(void) {
    if (access(PATCH_SCRIPT, R_OK) != 0) return -1;
    fprintf(stderr, "[agy] Deteksi update biner baru / interpreter belum di-patch. Menerapkan patch Termux otomatis...\n");
    pid_t pid = fork();
    if (pid < 0) return -1;
    if (pid == 0) {
        execl(BASH_BIN, "bash", PATCH_SCRIPT, REAL_BIN, (char *)NULL);
        _exit(127);
    }
    int status = 0;
    while (waitpid(pid, &status, 0) < 0) {
        if (errno != EINTR) return -1;
    }
    if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        return 0;
    }
    return -1;
}

int main(int argc, char **argv) {
    /* Self-heal BEFORE clearing LD_PRELOAD so Termux Bionic tools (bash/python3/patchelf) work normally */
    if (!has_expected_interpreter(REAL_BIN)) {
        run_self_heal();
    }

    unsetenv("LD_PRELOAD");
    unsetenv("LD_LIBRARY_PATH");
    setenv("GODEBUG", "netdns=cgo", 1);
    setenv("SSL_CERT_FILE", CERT_PEM, 1);

    char real_bin[] = REAL_BIN;
    char **new_argv = malloc((size_t)(argc + 1) * sizeof(char *));
    if (!new_argv) return 1;
    new_argv[0] = real_bin;
    for (int i = 1; i < argc; i++) new_argv[i] = argv[i];
    new_argv[argc] = NULL;

    execv(real_bin, new_argv);
    perror("execv");
    free(new_argv);
    return 1;
}
EOF

    local tmp_wrapper="$BIN_DIR/.agy.tmp.$$"
    clang -O2 -Wall -Wextra -o "$tmp_wrapper" "$TMP_DIR/agy_wrapper.c"
    chmod 755 "$tmp_wrapper"
    mv -f "$tmp_wrapper" "$WRAPPER_BIN"
    log_ok "Self-healing wrapper C aktif di $WRAPPER_BIN"
}

# 1. Check prerequisites
log_info "Memeriksa dependensi sistem..."
MISSING_PKGS=()
for pkg in clang curl tar python patchelf; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ! -f "$LOADER" ]; then
    if ! dpkg -s glibc-repo >/dev/null 2>&1; then
        log_warn "Menginstall glibc-repo terlebih dahulu..."
        if command -v pkg >/dev/null 2>&1; then
            pkg install glibc-repo -y
        else
            apt-get update -y
            apt-get install -y glibc-repo
        fi
    fi
    MISSING_PKGS+=("glibc")
fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    log_warn "Menginstall dependensi yang dibutuhkan: ${MISSING_PKGS[*]}..."
    apt-get update -y
    apt-get install -y "${MISSING_PKGS[@]}"
fi

# Fast mode: repair/install self-healing helper & wrapper without re-downloading binary
if [ "${1:-}" = "--repair-wrapper" ]; then
    ensure_glibc_ldcache
    install_patch_helper
    compile_wrapper
    if [ -f "$PATCHED_BIN" ]; then
        bash "$PATCH_HELPER" "$PATCHED_BIN"
        rm -f "$SHARE_DIR"/agy.real.*.old "$SHARE_DIR"/agy.real.broken-* 2>/dev/null || true
        NEW_VER=$("$WRAPPER_BIN" --version 2>/dev/null || echo "error")
        if [ "$NEW_VER" = "error" ] || [ -z "$NEW_VER" ]; then
            log_err "Verifikasi gagal setelah repair wrapper."
            exit 1
        fi
        log_ok "Self-healing wrapper & patch helper aktif untuk Antigravity CLI v${NEW_VER}!"
    fi
    exit 0
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
    CURRENT_VERSION=$("$WRAPPER_BIN" --version 2>/dev/null || echo "unknown")
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
    exit 1
fi

# 4. Install reusable patch helper & apply atomic ARM64 + patchelf staging patch
install_patch_helper
ensure_glibc_ldcache

STAGING_BIN="$SHARE_DIR/.agy.real.install.$$"
cp "$ORIG_BIN" "$STAGING_BIN"
chmod +x "$STAGING_BIN"

log_info "Menerapkan ARM64 memory patch & glibc interpreter secara atomik..."
if ! bash "$PATCH_HELPER" "$STAGING_BIN" --force; then
    rm -f "$STAGING_BIN"
    log_err "Gagal mem-patch atau memverifikasi binary Antigravity CLI v${TARGET_VERSION}. Instalasi lama tetap aman."
    exit 1
fi

# Backup current working binary and atomically swap
if [ -f "$PATCHED_BIN" ]; then
    cp "$PATCHED_BIN" "${PATCHED_BIN}.bak" 2>/dev/null || true
fi
mv -f "$STAGING_BIN" "$PATCHED_BIN"
rm -f "$SHARE_DIR"/agy.real.*.old "$SHARE_DIR"/agy.real.broken-* 2>/dev/null || true

# 5. Compile self-healing C wrapper
compile_wrapper

# 6. Verification
NEW_VER=$("$WRAPPER_BIN" --version 2>/dev/null || echo "error")
if [ "$NEW_VER" = "error" ] || [ -z "$NEW_VER" ]; then
    log_err "Verifikasi gagal: '$WRAPPER_BIN --version' tidak mengembalikan versi."
    if [ -f "${PATCHED_BIN}.bak" ]; then
        log_warn "Memulihkan backup binary sebelumnya..."
        cp "${PATCHED_BIN}.bak" "$PATCHED_BIN"
        chmod +x "$PATCHED_BIN"
    fi
    exit 1
fi
log_ok "Antigravity CLI v${NEW_VER} berhasil dipasang (dengan auto-recovery saat self-update)!"
log_info "Jalankan 'agy' di terminal Termux Anda."

#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# Scaffold Generator for Android/Termux Compatible Projects
# Creates production-ready CLI tools, wrappers, or patchers adhering to Termux rules.
# ==============================================================================
set -euo pipefail

PROJ_NAME="${1:-}"
PROJ_TYPE="${2:-bash-python}" # Options: bash-python, nodejs, patcher

if [ -z "$PROJ_NAME" ]; then
    echo "Penggunaan: $0 <nama-projek> [tipe: bash-python | nodejs | patcher]"
    echo "Contoh    : $0 my-termux-tool bash-python"
    exit 1
fi

DEST_DIR="$HOME/$PROJ_NAME"
if [ -d "$DEST_DIR" ]; then
    echo "Error: Direktori $DEST_DIR sudah ada!"
    exit 1
fi

echo -e "\033[36m[INFO]\033[0m Membuat projek Termux baru: $PROJ_NAME ($PROJ_TYPE) di $DEST_DIR..."
mkdir -p "$DEST_DIR/bin" "$DEST_DIR/lib" "$DEST_DIR/tests"

# 1. Main Launcher
cat << 'EOF' > "$DEST_DIR/bin/launcher.sh"
#!/data/data/com.termux/files/usr/bin/bash
set -e

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}====================================================${RESET}"
        echo -e "${BOLD}              Termux Application Menu              ${RESET}"
        echo -e "${BOLD}${CYAN}====================================================${RESET}"
        echo -e "  ${GREEN}1)${RESET} Jalankan Tugas Utama"
        echo -e "  ${CYAN}2)${RESET} Periksa Status & Diagnostik"
        echo -e "  ${YELLOW}0)${RESET} Keluar"
        echo ""
        if [ ! -t 0 ]; then
            break
        fi
        read -r -p "Pilihan Anda [0-2]: " choice
        case "$choice" in
            1)
                python3 "$SCRIPT_DIR/bin/engine.py" run
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            2)
                python3 "$SCRIPT_DIR/bin/engine.py" status
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            0|q|exit)
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${RESET}"
                sleep 1
                ;;
        esac
    done
}

case "${1:-}" in
    run)
        python3 "$SCRIPT_DIR/bin/engine.py" run "${@:2}"
        ;;
    status)
        python3 "$SCRIPT_DIR/bin/engine.py" status
        ;;
    help|--help|-h)
        echo "Penggunaan: $(basename "$0") [run|status|help]"
        ;;
    *)
        interactive_menu
        ;;
esac
EOF
chmod +x "$DEST_DIR/bin/launcher.sh"

# 2. Python Engine
cat << 'EOF' > "$DEST_DIR/bin/engine.py"
import sys, os, json, platform

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        print("\033[32m[OK]\033[0m Sistem Operasi :", platform.system())
        print("\033[32m[OK]\033[0m Arsitektur     :", platform.machine())
        print("\033[32m[OK]\033[0m Python Version :", platform.python_version())
        print("\033[32m[OK]\033[0m Lingkungan     : Termux Android")
    elif cmd == "run":
        print("\033[36m[INFO]\033[0m Menjalankan tugas utama aplikasi...")
        # Core logic here
        print("\033[32m[OK]\033[0m Tugas selesai dijalankan.")

if __name__ == "__main__":
    main()
EOF

# 3. Root symlink target
ln -sf "bin/launcher.sh" "$DEST_DIR/$PROJ_NAME.sh"

# 4. install.sh
cat << EOF > "$DEST_DIR/install.sh"
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PREFIX="\${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="\${HOME:-/data/data/com.termux/files/home}"
INSTALL_DIR="\$HOME_DIR/$PROJ_NAME"

GREEN="\033[32m"
CYAN="\033[36m"
RESET="\033[0m"

echo -e "\${CYAN}[INFO]\${RESET} Memeriksa dependensi Termux..."
for pkg in git curl python; do
    if ! command -v "\$pkg" >/dev/null 2>&1; then
        pkg install -y "\$pkg"
    fi
done

# Pasang symlink ke \$PREFIX/bin
ln -sf "\$INSTALL_DIR/bin/launcher.sh" "\$PREFIX/bin/$PROJ_NAME"
chmod +x "\$PREFIX/bin/$PROJ_NAME"

echo -e "\${GREEN}[OK]\${RESET} $PROJ_NAME berhasil dipasang!"
echo -e "Jalankan perintah: \033[1m$PROJ_NAME\033[0m dari terminal mana saja."
EOF
chmod +x "$DEST_DIR/install.sh"

# 5. update.sh
cat << 'EOF' > "$DEST_DIR/update.sh"
#!/data/data/com.termux/files/usr/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -d ".git" ]; then
    echo "Memeriksa pembaruan upstream Git..."
    git fetch origin main --quiet 2>/dev/null || true
    LOCAL=$(git rev-parse HEAD 2>/dev/null || echo "local")
    REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "remote")

    if [ "$LOCAL" != "$REMOTE" ] && [ "$REMOTE" != "remote" ]; then
        echo "Pembaruan tersedia! Mengunduh versi terbaru..."
        git pull origin main
        echo "Sukses diperbarui."
    else
        echo "Aplikasi sudah dalam versi terbaru."
    fi
else
    echo "Instalasi mandiri tanpa Git. Cek repositori resmi untuk rilis terbaru."
fi
EOF
chmod +x "$DEST_DIR/update.sh"

# 6. tests/test_main.sh
cat << EOF > "$DEST_DIR/tests/test_main.sh"
#!/data/data/com.termux/files/usr/bin/bash
set -e

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
LAUNCHER="\$SCRIPT_DIR/bin/launcher.sh"

PASSED=0
FAILED=0

assert_output() {
    local name="\$1"
    local exp="\$2"
    shift 2
    local out
    out="\$("\$@")" || true
    if [[ "\$out" == *"\$exp"* ]]; then
        echo -e "  \033[32m[PASS]\033[0m \$name"
        PASSED=\$((PASSED + 1))
    else
        echo -e "  \033[31m[FAIL]\033[0m \$name (Expected '\$exp')"
        FAILED=\$((FAILED + 1))
    fi
}

echo "Menjalankan Test Suite untuk $PROJ_NAME..."
assert_output "Launcher executable exists" "Termux Android" bash "\$LAUNCHER" status
assert_output "Run command works" "Tugas selesai" bash "\$LAUNCHER" run

echo "Total: \$((PASSED + FAILED)) | Lolos: \$PASSED | Gagal: \$FAILED"
[ \$FAILED -eq 0 ]
EOF
chmod +x "$DEST_DIR/tests/test_main.sh"

# 7. README.md
cat << EOF > "$DEST_DIR/README.md"
# $PROJ_NAME 🚀

Projek aplikasi/CLI yang dioptimalkan untuk lingkungan **Android / Termux**.

## ⚡ Instalasi Cepat
\`\`\`bash
curl -fsSL https://raw.githubusercontent.com/username/$PROJ_NAME/main/install.sh | bash
\`\`\`

## 📖 Penggunaan
\`\`\`bash
$PROJ_NAME              # Menu interaktif TUI
$PROJ_NAME run          # Jalankan tugas langsung
$PROJ_NAME status       # Periksa status sistem
\`\`\`

## 🧪 Testing
\`\`\`bash
./tests/test_main.sh
\`\`\`
EOF

echo -e "\033[32m[OK]\033[0m Projek Termux berhasil di-scaffold di: $DEST_DIR"

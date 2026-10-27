#!/data/data/com.termux/files/usr/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$1" in
    export|backup|--export)
        shift
        bash "$SCRIPT_DIR/bin/export-config.sh" "$@"
        ;;
    restore|--restore)
        shift
        bash "$SCRIPT_DIR/bin/restore-config.sh" "$@"
        ;;
    *)
        echo "Termux AI Tools - Backup & Restore Manager"
        echo "1) Export (Backup) Pengaturan & Token"
        echo "2) Restore Pengaturan dari Backup"
        echo "3) Keluar"
        read -r -p "Pilihan [1-3]: " opt
        case "$opt" in
            1) bash "$SCRIPT_DIR/bin/export-config.sh" ;;
            2) bash "$SCRIPT_DIR/bin/restore-config.sh" ;;
            *) exit 0 ;;
        esac
        ;;
esac

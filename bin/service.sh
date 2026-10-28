#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# OpenCode Background Web Service Manager for Termux
# Mengelola background daemon untuk OpenCode Web / Serve & auto-open di browser
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BASE_DIR="${HOME:-/data/data/com.termux/files/home}/.cache/termux-ai-services"
PID_DIR="$BASE_DIR/run"
LOG_DIR="$BASE_DIR/logs"

mkdir -p "$PID_DIR" "$LOG_DIR"

DEFAULT_V1_PORT=4096
DEFAULT_V2_PORT=4097
DEFAULT_HOST="127.0.0.1"

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

get_service_name() {
    local ver="${1:-v2}"
    if [ "$ver" = "1" ] || [ "$ver" = "v1" ] || [ "$ver" = "opencode" ]; then
        echo "opencode-v1"
    else
        echo "opencode-v2"
    fi
}

get_pid() {
    local sname="$1"
    local pid_file="$PID_DIR/${sname}.pid"
    if [ -f "$pid_file" ]; then
        local pid
        pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
        rm -f "$pid_file"
    fi
    echo ""
}

open_url() {
    local url="$1"
    log_info "Membuka antarmuka web di browser Android..."
    if command -v termux-open-url >/dev/null 2>&1; then
        termux-open-url "$url"
    elif command -v termux-open >/dev/null 2>&1; then
        termux-open "$url"
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" 2>/dev/null || true
    else
        echo -e "${YELLOW}Silakan buka URL ini di browser Anda: ${BOLD}${url}${RESET}"
    fi
}

start_service() {
    local sname="$1"
    local port="$2"
    local host="${3:-$DEFAULT_HOST}"
    local should_open="${4:-true}"

    local existing_pid
    existing_pid=$(get_pid "$sname")
    if [ -n "$existing_pid" ]; then
        log_warn "Layanan $sname sudah berjalan (PID: $existing_pid)!"
        local cur_port
        cur_port=$(cat "$PID_DIR/${sname}.port" 2>/dev/null || echo "$port")
        if [ "$should_open" = "true" ]; then
            open_url "http://${host}:${cur_port}"
        fi
        return 0
    fi

    local bin_path
    local cmd_args=()
    if [ "$sname" = "opencode-v1" ]; then
        bin_path="$PREFIX/bin/opencode"
        port="${port:-$DEFAULT_V1_PORT}"
        cmd_args=("web" "--port" "$port" "--hostname" "$host")
    else
        bin_path="$PREFIX/bin/opencode-v2"
        port="${port:-$DEFAULT_V2_PORT}"
        cmd_args=("serve" "--port" "$port" "--hostname" "$host")
    fi

    if [ ! -x "$bin_path" ]; then
        log_err "Biner $bin_path tidak ditemukan atau belum terpasang!"
        return 1
    fi

    local log_file="$LOG_DIR/${sname}.log"
    log_info "Memulai background service $sname pada http://${host}:${port}..."

    # Launch daemon
    nohup "$bin_path" "${cmd_args[@]}" > "$log_file" 2>&1 &
    local new_pid=$!

    # Wait up to 5 seconds to verify process startup
    local running=false
    for _ in {1..10}; do
        sleep 0.5
        if kill -0 "$new_pid" 2>/dev/null; then
            running=true
            break
        fi
    done

    if [ "$running" = "true" ]; then
        echo "$new_pid" > "$PID_DIR/${sname}.pid"
        echo "$port" > "$PID_DIR/${sname}.port"
        echo "$host" > "$PID_DIR/${sname}.host"
        log_ok "Layanan $sname berhasil aktif! (PID: $new_pid)"
        log_info "Log server tersimpan di: $log_file"
        echo -e "Akses URL: ${BOLD}${GREEN}http://${host}:${port}${RESET}"

        if [ "$should_open" = "true" ]; then
            sleep 1
            open_url "http://${host}:${port}"
        fi
    else
        log_err "Gagal memulai $sname! Periksa log untuk detail:"
        tail -n 10 "$log_file"
        return 1
    fi
}

stop_service() {
    local sname="$1"
    local pid
    pid=$(get_pid "$sname")

    if [ -z "$pid" ]; then
        log_warn "Layanan $sname tidak sedang berjalan."
        rm -f "$PID_DIR/${sname}.pid" "$PID_DIR/${sname}.port" "$PID_DIR/${sname}.host"
        return 0
    fi

    log_info "Menghentikan layanan $sname (PID: $pid)..."
    kill "$pid" 2>/dev/null || true

    # Graceful wait
    local stopped=false
    for _ in {1..6}; do
        sleep 0.5
        if ! kill -0 "$pid" 2>/dev/null; then
            stopped=true
            break
        fi
    done

    if [ "$stopped" != "true" ]; then
        log_warn "Proses belum berhenti, mengirim SIGKILL..."
        kill -9 "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_DIR/${sname}.pid" "$PID_DIR/${sname}.port" "$PID_DIR/${sname}.host"
    log_ok "Layanan $sname berhasil dihentikan."
}

show_status() {
    echo -e "\n${BOLD}${CYAN}=== Status Background Web Services ===${RESET}\n"
    printf "%-15s | %-12s | %-8s | %-6s | %-25s\n" "Layanan" "Status" "PID" "Port" "URL"
    echo "----------------------------------------------------------------------------"

    for sname in "opencode-v1" "opencode-v2"; do
        local pid
        pid=$(get_pid "$sname")
        local port
        port=$(cat "$PID_DIR/${sname}.port" 2>/dev/null || echo "-")
        local host
        host=$(cat "$PID_DIR/${sname}.host" 2>/dev/null || echo "127.0.0.1")

        if [ -n "$pid" ]; then
            local status="${GREEN}RUNNING${RESET}"
            local url="http://${host}:${port}"
            # Check RSS memory
            local mem_rss
            mem_rss=$(grep VmRSS "/proc/$pid/status" 2>/dev/null | awk '{print $2 $3}' || echo "")
            [ -n "$mem_rss" ] && status="${GREEN}RUNNING${RESET} (${CYAN}${mem_rss}${RESET})"
            printf "%-15s | %-21b | %-8s | %-6s | %-25s\n" "$sname" "$status" "$pid" "$port" "$url"
        else
            local status="${YELLOW}STOPPED${RESET}"
            printf "%-15s | %-21b | %-8s | %-6s | %-25s\n" "$sname" "$status" "-" "-" "-"
        fi
    done
    echo "----------------------------------------------------------------------------"
    echo ""
}

show_logs() {
    local sname="$1"
    local log_file="$LOG_DIR/${sname}.log"
    local follow="${2:-false}"

    if [ ! -f "$log_file" ]; then
        log_warn "Belum ada log untuk layanan $sname."
        return 0
    fi

    echo -e "\n${BOLD}${CYAN}=== Log Terakhir: $sname ($log_file) ===${RESET}\n"
    if [ "$follow" = "true" ] || [ "$follow" = "-f" ] || [ "$follow" = "--follow" ]; then
        log_info "Menampilkan live logs (Tekan Ctrl+C untuk keluar)..."
        tail -f "$log_file"
    else
        tail -n 35 "$log_file"
    fi
}

# Process Command
ACTION="$1"
TARGET_VER="${2:-v2}"

case "$ACTION" in
    start)
        sname=$(get_service_name "$TARGET_VER")
        port=""
        should_open=true
        shift 2 2>/dev/null || shift 1 2>/dev/null || true
        while [ $# -gt 0 ]; do
            case "$1" in
                --port|-p) port="$2"; shift 2 ;;
                --no-open) should_open=false; shift ;;
                --open) should_open=true; shift ;;
                *) shift ;;
            esac
        done
        start_service "$sname" "$port" "$DEFAULT_HOST" "$should_open"
        ;;
    stop)
        if [ "$TARGET_VER" = "all" ]; then
            stop_service "opencode-v1"
            stop_service "opencode-v2"
        else
            sname=$(get_service_name "$TARGET_VER")
            stop_service "$sname"
        fi
        ;;
    restart)
        sname=$(get_service_name "$TARGET_VER")
        stop_service "$sname"
        sleep 1
        start_service "$sname" "" "$DEFAULT_HOST" true
        ;;
    status)
        show_status
        ;;
    logs|log)
        sname=$(get_service_name "$TARGET_VER")
        show_logs "$sname" "$3"
        ;;
    open)
        sname=$(get_service_name "$TARGET_VER")
        pid=$(get_pid "$sname")
        if [ -n "$pid" ]; then
            port=$(cat "$PID_DIR/${sname}.port" 2>/dev/null || echo "4097")
            host=$(cat "$PID_DIR/${sname}.host" 2>/dev/null || echo "127.0.0.1")
            open_url "http://${host}:${port}"
        else
            log_warn "Layanan $sname tidak sedang berjalan. Menjalankan layanan terlebih dahulu..."
            start_service "$sname" "" "$DEFAULT_HOST" true
        fi
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Penggunaan service.sh:${RESET}"
        echo "  ./service.sh start [v1|v2] [--port PORT] [--no-open]"
        echo "  ./service.sh stop [v1|v2|all]"
        echo "  ./service.sh restart [v1|v2]"
        echo "  ./service.sh status"
        echo "  ./service.sh logs [v1|v2] [-f|--follow]"
        echo "  ./service.sh open [v1|v2]"
        exit 0
        ;;
    *)
        # Interactive Menu
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "    🌐 Termux AI Tools - Web Service Manager     "
        echo -e "==================================================${RESET}"
        show_status

        echo -e "${BOLD}Pilihan Aksi:${RESET}"
        echo -e "  ${GREEN}1)${RESET} Start OpenCode v2 Web Service & Buka di Browser"
        echo -e "  ${RED}2)${RESET} Stop OpenCode v2 Web Service"
        echo -e "  ${GREEN}3)${RESET} Start OpenCode v1 Web Service & Buka di Browser"
        echo -e "  ${RED}4)${RESET} Stop OpenCode v1 Web Service"
        echo -e "  ${CYAN}5)${RESET} Buka Web Interface di Browser Android"
        echo -e "  ${CYAN}6)${RESET} Lihat Log Server Terakhir (Logs)"
        echo -e "  ${YELLOW}7)${RESET} Stop Semua Layanan Web"
        echo -e "  ${BOLD}8)${RESET} Keluar"
        echo ""
        read -r -p "Masukkan pilihan [1-8]: " choice

        case "$choice" in
            1) start_service "opencode-v2" "$DEFAULT_V2_PORT" "$DEFAULT_HOST" true ;;
            2) stop_service "opencode-v2" ;;
            3) start_service "opencode-v1" "$DEFAULT_V1_PORT" "$DEFAULT_HOST" true ;;
            4) stop_service "opencode-v1" ;;
            5)
                # Open whatever is running
                if [ -n "$(get_pid 'opencode-v2')" ]; then
                    open_url "http://127.0.0.1:$(cat "$PID_DIR/opencode-v2.port")"
                elif [ -n "$(get_pid 'opencode-v1')" ]; then
                    open_url "http://127.0.0.1:$(cat "$PID_DIR/opencode-v1.port")"
                else
                    log_warn "Tidak ada layanan web yang sedang aktif. Menjalankan OpenCode v2..."
                    start_service "opencode-v2" "$DEFAULT_V2_PORT" "$DEFAULT_HOST" true
                fi
                ;;
            6)
                if [ -f "$LOG_DIR/opencode-v2.log" ]; then
                    show_logs "opencode-v2" false
                else
                    show_logs "opencode-v1" false
                fi
                ;;
            7)
                stop_service "opencode-v1"
                stop_service "opencode-v2"
                ;;
            *)
                echo "Selesai."
                exit 0
                ;;
        esac
        ;;
esac

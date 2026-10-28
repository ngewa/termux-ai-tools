#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Plugin & MCP Tool Installer (plugin.sh)
# Manages:
#   - MCP Servers for OpenCode (~/.config/opencode/opencode.jsonc)
#   - MCP Servers for Antigravity CLI (~/.gemini/settings.json)
#   - OpenCode Plugins (~/.config/opencode/plugins/ & plugin array in opencode.jsonc)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OPENCODE_CONFIG="$HOME_DIR/.config/opencode/opencode.jsonc"
OPENCODE_PLUGINS_DIR="$HOME_DIR/.config/opencode/plugins"
AGY_SETTINGS="$HOME_DIR/.gemini/settings.json"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err() { echo -e "${RED}[ERROR]${RESET} $1"; }

if ! command -v python3 >/dev/null 2>&1; then
    log_err "Python3 diperlukan untuk mengelola plugin & MCP server."
    echo "Jalankan: pkg install python"
    exit 1
fi

mkdir -p "$OPENCODE_PLUGINS_DIR"
mkdir -p "$HOME_DIR/.gemini"

# ------------------------------------------------------------------------------
# Python Core Manager
# ------------------------------------------------------------------------------
run_python_manager() {
    python3 - "$@" << 'EOF'
import sys, os, json, shutil

HOME = os.path.expanduser("~")
REPO_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HOME, "termux-ai-tools")
OPENCODE_CONFIG = os.path.join(HOME, ".config/opencode/opencode.jsonc")
OPENCODE_PLUGINS_DIR = os.path.join(HOME, ".config/opencode/plugins")
AGY_SETTINGS = os.path.join(HOME, ".gemini/settings.json")

PYTHON_BIN = shutil.which("python3") or "/data/data/com.termux/files/usr/bin/python3"
NPX_BIN = shutil.which("npx") or "npx"

PRESETS = {
    "termux-device": {
        "name": "Termux Device Bridge",
        "desc": "Baterai, Clipboard, Notifikasi Android, Toast, Getar & Buka Browser",
        "command": PYTHON_BIN,
        "args": [os.path.join(REPO_DIR, "mcp/termux-device/server.py")],
        "env": {}
    },
    "fetch": {
        "name": "Web Fetcher",
        "desc": "Akses konten halaman web & REST API secara instan (@modelcontextprotocol/server-fetch)",
        "command": NPX_BIN,
        "args": ["-y", "@modelcontextprotocol/server-fetch"],
        "env": {}
    },
    "sqlite": {
        "name": "SQLite Database Explorer",
        "desc": "Baca & eksekusi query database SQLite (@modelcontextprotocol/server-sqlite)",
        "command": NPX_BIN,
        "args": ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", os.path.join(HOME, ".local/share/opencode/opencode.db")],
        "env": {}
    },
    "filesystem": {
        "name": "Filesystem Manager",
        "desc": "Operasi baca/tulis direktori terisolasi (@modelcontextprotocol/server-filesystem)",
        "command": NPX_BIN,
        "args": ["-y", "@modelcontextprotocol/server-filesystem", HOME],
        "env": {}
    },
    "memory": {
        "name": "Memory Knowledge Graph",
        "desc": "Memori persisten konteks antar sesi (@modelcontextprotocol/server-memory)",
        "command": NPX_BIN,
        "args": ["-y", "@modelcontextprotocol/server-memory"],
        "env": {}
    },
    "github": {
        "name": "GitHub Integration",
        "desc": "Akses repository, issue & PR GitHub (@modelcontextprotocol/server-github)",
        "command": NPX_BIN,
        "args": ["-y", "@modelcontextprotocol/server-github"],
        "env": {"GITHUB_PERSONAL_ACCESS_TOKEN": ""}
    }
}

def strip_jsonc_comments(text):
    result = []
    i = 0
    in_string = False
    escape = False
    n = len(text)
    while i < n:
        c = text[i]
        if in_string:
            result.append(c)
            if escape:
                escape = False
            elif c == '\\':
                escape = True
            elif c == '"':
                in_string = False
            i += 1
        else:
            if c == '"':
                in_string = True
                result.append(c)
                i += 1
            elif c == '/' and i + 1 < n and text[i+1] == '/':
                i += 2
                while i < n and text[i] != '\n':
                    i += 1
            elif c == '/' and i + 1 < n and text[i+1] == '*':
                i += 2
                while i + 1 < n and not (text[i] == '*' and text[i+1] == '/'):
                    i += 1
                i += 2
            else:
                result.append(c)
                i += 1
    return ''.join(result)

def load_json(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return json.loads(strip_jsonc_comments(f.read()))
    except Exception:
        return {}

def save_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if os.path.exists(path):
        try:
            with open(path + ".bak", 'w', encoding='utf-8') as bak:
                with open(path, 'r', encoding='utf-8') as src:
                    bak.write(src.read())
        except Exception:
            pass
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

# ------------------------------------------------------------------------------
# Action: LIST STATUS
# ------------------------------------------------------------------------------
def action_list():
    opencode_data = load_json(OPENCODE_CONFIG)
    agy_data = load_json(AGY_SETTINGS)

    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                     STATUS MCP SERVERS & PLUGINS TERPASANG                             \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m")

    # 1. MCP Servers in Antigravity CLI
    agy_mcp = agy_data.get("mcpServers", {})
    print(f"\033[1m1. Antigravity CLI (~/.gemini/settings.json):\033[0m")
    if agy_mcp:
        for name, cfg in agy_mcp.items():
            cmd = cfg.get("command", "")
            args = " ".join(cfg.get("args", []))
            full = f"{cmd} {args}".strip()
            if len(full) > 45:
                full = full[:42] + "..."
            print(f"  • \033[32m[AKTIF]\033[0m \033[1m{name:<18}\033[0m -> {full}")
    else:
        print("  \033[33m(Belum ada MCP server yang terpasang)\033[0m")

    # 2. MCP Servers in OpenCode
    oc_mcp_raw = opencode_data.get("mcp", {})
    oc_mcp = oc_mcp_raw.get("servers", oc_mcp_raw) if isinstance(oc_mcp_raw, dict) else {}
    print(f"\n\033[1m2. OpenCode (~/.config/opencode/opencode.jsonc):\033[0m")
    if oc_mcp:
        for name, cfg in oc_mcp.items():
            if not isinstance(cfg, dict):
                continue
            cmd_arr = cfg.get("command", [])
            full = " ".join(cmd_arr) if isinstance(cmd_arr, list) else str(cmd_arr)
            if len(full) > 45:
                full = full[:42] + "..."
            status = "\033[32m[AKTIF]\033[0m" if cfg.get("enabled", True) else "\033[31m[NONAKTIF]\033[0m"
            print(f"  • {status} \033[1m{name:<18}\033[0m -> {full}")
    else:
        print("  \033[33m(Belum ada MCP server yang terpasang)\033[0m")

    # 3. OpenCode Plugins
    plugins_array = opencode_data.get("plugin", [])
    files_in_plugins_dir = os.listdir(OPENCODE_PLUGINS_DIR) if os.path.exists(OPENCODE_PLUGINS_DIR) else []
    print(f"\n\033[1m3. OpenCode Plugins ({len(plugins_array)} aktif di config, {len(files_in_plugins_dir)} file di plugins/):\033[0m")
    if files_in_plugins_dir:
        for pfile in sorted(files_in_plugins_dir):
            is_active = any(pfile in str(entry) for entry in plugins_array)
            st = "\033[32m[AKTIF]\033[0m" if is_active else "\033[33m[TERSEDIA]\033[0m"
            print(f"  • {st} {pfile}")
    else:
        print("  \033[33m(Tidak ada plugin di ~/.config/opencode/plugins/)\033[0m")

    print("\033[1m\033[36m========================================================================================\033[0m")

# ------------------------------------------------------------------------------
# Action: INSTALL MCP SERVER
# ------------------------------------------------------------------------------
def action_install_mcp(preset_id, target="all", custom_env=None):
    if preset_id not in PRESETS:
        print(f"Preset '{preset_id}' tidak dikenal.")
        return

    info = PRESETS[preset_id]
    cmd = info["command"]
    args = info["args"]
    env_vars = dict(info.get("env", {}))
    if custom_env:
        env_vars.update(custom_env)

    # 1. Install to Antigravity CLI
    if target in ("all", "agy", "antigravity"):
        agy_data = load_json(AGY_SETTINGS)
        if "mcpServers" not in agy_data:
            agy_data["mcpServers"] = {}
        server_entry = {
            "command": cmd,
            "args": args
        }
        if env_vars:
            server_entry["env"] = env_vars
        agy_data["mcpServers"][preset_id] = server_entry
        save_json(AGY_SETTINGS, agy_data)
        print(f"\033[32m[OK]\033[0m MCP '{preset_id}' berhasil dipasang ke Antigravity CLI (~/.gemini/settings.json)")

    # 2. Install to OpenCode
    if target in ("all", "oc", "opencode"):
        oc_data = load_json(OPENCODE_CONFIG)
        if "$schema" not in oc_data:
            oc_data["$schema"] = "https://opencode.ai/config.json"
        if "mcp" not in oc_data:
            oc_data["mcp"] = {}
        
        full_command = [cmd] + args
        server_entry = {
            "type": "local",
            "command": full_command,
            "enabled": True
        }
        if env_vars:
            server_entry["environment"] = env_vars
        
        oc_data["mcp"][preset_id] = server_entry
        save_json(OPENCODE_CONFIG, oc_data)
        print(f"\033[32m[OK]\033[0m MCP '{preset_id}' berhasil dipasang ke OpenCode (~/.config/opencode/opencode.jsonc)")

# ------------------------------------------------------------------------------
# Action: INSTALL OPENCODE PLUGIN
# ------------------------------------------------------------------------------
def action_install_plugin(plugin_name):
    src_file = os.path.join(REPO_DIR, "plugins", f"{plugin_name}.ts")
    if not os.path.exists(src_file):
        src_file = os.path.join(REPO_DIR, "plugins", plugin_name)
    
    if not os.path.exists(src_file):
        print(f"File plugin '{plugin_name}' tidak ditemukan di repositori.")
        return

    dest_file = os.path.join(OPENCODE_PLUGINS_DIR, os.path.basename(src_file))
    shutil.copy2(src_file, dest_file)
    print(f"\033[32m[OK]\033[0m Berkas plugin disalin ke {dest_file}")

    # Register in opencode.jsonc
    oc_data = load_json(OPENCODE_CONFIG)
    if "plugin" not in oc_data:
        oc_data["plugin"] = []
    
    plugin_rel_path = f"./plugins/{os.path.basename(dest_file)}"
    if plugin_rel_path not in oc_data["plugin"] and dest_file not in oc_data["plugin"]:
        oc_data["plugin"].append(plugin_rel_path)
        save_json(OPENCODE_CONFIG, oc_data)
        print(f"\033[32m[OK]\033[0m Plugin didaftarkan ke opencode.jsonc")
    else:
        print(f"[INFO] Plugin sudah terdaftar di opencode.jsonc")

# ------------------------------------------------------------------------------
# Action: REMOVE MCP / PLUGIN
# ------------------------------------------------------------------------------
def action_remove(name, target="all"):
    # Check if removing MCP from AGY
    if target in ("all", "agy", "antigravity"):
        agy_data = load_json(AGY_SETTINGS)
        if "mcpServers" in agy_data and name in agy_data["mcpServers"]:
            del agy_data["mcpServers"][name]
            save_json(AGY_SETTINGS, agy_data)
            print(f"\033[32m[OK]\033[0m MCP '{name}' dihapus dari Antigravity CLI")

    # Check if removing MCP from OpenCode
    if target in ("all", "oc", "opencode"):
        oc_data = load_json(OPENCODE_CONFIG)
        if "mcp" in oc_data and isinstance(oc_data["mcp"], dict):
            if name in oc_data["mcp"]:
                del oc_data["mcp"][name]
                save_json(OPENCODE_CONFIG, oc_data)
                print(f"\033[32m[OK]\033[0m MCP '{name}' dihapus dari OpenCode")

    # Check if removing OpenCode Plugin
    oc_data = load_json(OPENCODE_CONFIG)
    if "plugin" in oc_data:
        orig_len = len(oc_data["plugin"])
        oc_data["plugin"] = [p for p in oc_data["plugin"] if name not in p]
        if len(oc_data["plugin"]) != orig_len:
            save_json(OPENCODE_CONFIG, oc_data)
            print(f"\033[32m[OK]\033[0m Plugin '{name}' dinonaktifkan dari opencode.jsonc")

# ------------------------------------------------------------------------------
# Action: TEST MCP COMMAND
# ------------------------------------------------------------------------------
def action_test(name):
    agy_data = load_json(AGY_SETTINGS)
    oc_data = load_json(OPENCODE_CONFIG)

    cmd = None
    if name in agy_data.get("mcpServers", {}):
        cmd = agy_data["mcpServers"][name].get("command")
    elif "mcp" in oc_data and name in oc_data["mcp"]:
        c = oc_data["mcp"][name].get("command", [])
        cmd = c[0] if isinstance(c, list) and c else c

    if not cmd:
        print(f"Server MCP '{name}' tidak ditemukan di konfigurasi.")
        return

    path_loc = shutil.which(cmd)
    if path_loc:
        print(f"\033[32m[PASS]\033[0m Perintah '{cmd}' terdeteksi dan dapat dieksekusi ({path_loc})")
    else:
        print(f"\033[31m[FAIL]\033[0m Perintah '{cmd}' tidak ditemukan di PATH!")

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------
cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

if cmd in ("status", "list", "ls"):
    action_list()
elif cmd == "install-mcp":
    preset = sys.argv[3] if len(sys.argv) > 3 else "termux-device"
    target = sys.argv[4] if len(sys.argv) > 4 else "all"
    action_install_mcp(preset, target)
elif cmd == "install-plugin":
    pname = sys.argv[3] if len(sys.argv) > 3 else "termux-notifier"
    action_install_plugin(pname)
elif cmd in ("remove", "rm", "del"):
    name = sys.argv[3] if len(sys.argv) > 3 else ""
    target = sys.argv[4] if len(sys.argv) > 4 else "all"
    if name:
        action_remove(name, target)
    else:
        print("Gunakan: remove <nama>")
elif cmd == "test":
    name = sys.argv[3] if len(sys.argv) > 3 else ""
    if name:
        action_test(name)
    else:
        print("Gunakan: test <nama>")

EOF
}

# ------------------------------------------------------------------------------
# Interactive Menu Wizard
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "   🧩 Termux AI Tools - Plugin & MCP Installer   "
        echo -e "==================================================${RESET}"

        run_python_manager "status" "$REPO_DIR"
        echo ""
        echo -e "${BOLD}Pilihan Menu:${RESET}"
        echo -e "  ${GREEN}1)${RESET} 📱 Pasang MCP: Termux Device Bridge (Baterai, Notifikasi, Clipboard)"
        echo -e "  ${GREEN}2)${RESET} 🌐 Pasang MCP: Web Fetcher (Akses URL web & API)"
        echo -e "  ${GREEN}3)${RESET} 🗄️ Pasang MCP: SQLite Database Explorer"
        echo -e "  ${GREEN}4)${RESET} 📁 Pasang MCP: Filesystem Manager"
        echo -e "  ${GREEN}5)${RESET} 🧠 Pasang MCP: Memory Knowledge Graph"
        echo -e "  ${GREEN}6)${RESET} 🐙 Pasang MCP: GitHub API Integration"
        echo -e "  ${CYAN}7)${RESET} 🔔 Pasang OpenCode Plugin: Termux Notifier"
        echo -e "  ${CYAN}8)${RESET} ⚡ Pasang OpenCode Plugin: RTK (Token Savings & Command Rewriter)"
        echo -e "  ${YELLOW}9)${RESET} 🧪 Uji Validitas Eksekusi MCP Server"
        echo -e "  ${RED}10)${RESET} 🗑️ Hapus MCP Server / Plugin"
        echo -e "  ${YELLOW}0)${RESET} 🚪 Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-10]: " menu_opt

        case "$menu_opt" in
            1)
                echo ""
                log_info "Memasang MCP: Termux Device Bridge..."
                run_python_manager "install-mcp" "$REPO_DIR" "termux-device" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            2)
                echo ""
                log_info "Memasang MCP: Web Fetcher..."
                run_python_manager "install-mcp" "$REPO_DIR" "fetch" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            3)
                echo ""
                log_info "Memasang MCP: SQLite Explorer..."
                run_python_manager "install-mcp" "$REPO_DIR" "sqlite" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                echo ""
                log_info "Memasang MCP: Filesystem..."
                run_python_manager "install-mcp" "$REPO_DIR" "filesystem" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            5)
                echo ""
                log_info "Memasang MCP: Memory Graph..."
                run_python_manager "install-mcp" "$REPO_DIR" "memory" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            6)
                echo ""
                read -r -p "Masukkan GitHub Personal Access Token (kosongkan jika nanti): " gh_tok
                log_info "Memasang MCP: GitHub..."
                run_python_manager "install-mcp" "$REPO_DIR" "github" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            7)
                echo ""
                log_info "Memasang OpenCode Plugin: Termux Notifier..."
                run_python_manager "install-plugin" "$REPO_DIR" "termux-notifier"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            8)
                echo ""
                log_info "Memasang OpenCode Plugin: RTK..."
                run_python_manager "install-plugin" "$REPO_DIR" "rtk"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            9)
                echo ""
                read -r -p "Masukkan nama MCP server yang ingin diuji (contoh: termux-device): " test_name
                if [ -n "$test_name" ]; then
                    echo ""
                    run_python_manager "test" "$REPO_DIR" "$test_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            10)
                echo ""
                read -r -p "Masukkan nama MCP atau plugin yang ingin dihapus: " del_name
                if [ -n "$del_name" ]; then
                    read -r -p "Yakin ingin menghapus '$del_name'? (y/N): " conf_del
                    if [[ "$conf_del" =~ ^[Yy]$ ]]; then
                        echo ""
                        run_python_manager "remove" "$REPO_DIR" "$del_name" "all"
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            0)
                echo "Selesai."
                break
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${RESET}"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Dispatcher
# ------------------------------------------------------------------------------
case "$1" in
    status|list|ls)
        run_python_manager "status" "$REPO_DIR"
        ;;
    install|add)
        shift
        preset="${1:-termux-device}"
        target="${2:-all}"
        if [ "$preset" = "notifier" ] || [ "$preset" = "termux-notifier" ]; then
            run_python_manager "install-plugin" "$REPO_DIR" "termux-notifier"
        elif [ "$preset" = "rtk" ]; then
            run_python_manager "install-plugin" "$REPO_DIR" "rtk"
        else
            run_python_manager "install-mcp" "$REPO_DIR" "$preset" "$target"
        fi
        ;;
    remove|rm|del)
        shift
        name="$1"
        target="${2:-all}"
        if [ -n "$name" ]; then
            run_python_manager "remove" "$REPO_DIR" "$name" "$target"
        else
            echo "Gunakan: plugin.sh remove <nama> [all|oc|agy]"
            exit 1
        fi
        ;;
    test)
        shift
        name="$1"
        if [ -n "$name" ]; then
            run_python_manager "test" "$REPO_DIR" "$name"
        else
            echo "Gunakan: plugin.sh test <nama>"
            exit 1
        fi
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - Plugin & MCP Installer Usage:${RESET}"
        echo "  plugin.sh                          Buka menu interaktif TUI"
        echo "  plugin.sh status                   Tampilkan daftar status MCP & Plugin terpasang"
        echo "  plugin.sh install <preset> [target]Pasang preset MCP (termux-device, fetch, sqlite, etc)"
        echo "  plugin.sh remove <nama> [target]   Hapus MCP server atau plugin"
        echo "  plugin.sh test <nama>              Uji apakah binary command MCP tersedia"
        exit 0
        ;;
    *)
        interactive_menu
        ;;
esac

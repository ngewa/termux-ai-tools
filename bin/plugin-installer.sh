#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Plugin & MCP Tool Installer (plugin.sh)
# Manages:
#   - MCP Servers for OpenCode (~/.config/opencode/opencode.jsonc)
#   - MCP Servers for Antigravity CLI (~/.gemini/config/mcp_config.json & settings.json)
#   - OpenCode Plugins (~/.config/opencode/plugins/ & plugin array in opencode.jsonc)
#   - Antigravity Plugins (~/.gemini/config/plugins/)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OPENCODE_CONFIG="$HOME_DIR/.config/opencode/opencode.jsonc"
OPENCODE_PLUGINS_DIR="$HOME_DIR/.config/opencode/plugins"
AGY_SETTINGS="$HOME_DIR/.gemini/settings.json"
AGY_MCP_CONFIG="$HOME_DIR/.gemini/config/mcp_config.json"
AGY_PLUGINS_DIR="$HOME_DIR/.gemini/config/plugins"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
MAGENTA="\033[35m"
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
mkdir -p "$HOME_DIR/.gemini/config"
mkdir -p "$AGY_PLUGINS_DIR"

# ------------------------------------------------------------------------------
# Python Core Manager
# ------------------------------------------------------------------------------
run_python_manager() {
    python3 - "$@" << 'EOF'
import sys, os, json, shutil, shlex

HOME = os.path.expanduser("~")
REPO_DIR = sys.argv[2] if len(sys.argv) > 2 else os.path.join(HOME, "termux-ai-tools")
OPENCODE_CONFIG = os.path.join(HOME, ".config/opencode/opencode.jsonc")
OPENCODE_PLUGINS_DIR = os.path.join(HOME, ".config/opencode/plugins")
AGY_SETTINGS = os.path.join(HOME, ".gemini/settings.json")
AGY_MCP_CONFIG = os.path.join(HOME, ".gemini/config/mcp_config.json")
AGY_PLUGINS_DIR = os.path.join(HOME, ".gemini/config/plugins")

PYTHON_BIN = shutil.which("python3") or "/data/data/com.termux/files/usr/bin/python3"
NPX_BIN = shutil.which("npx") or "npx"

PRESETS = {
    "termux-device": {
        "name": "Termux Device Bridge",
        "desc": "Android Bridge: Baterai, Notifikasi, Clipboard, Toast, Sensor",
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
    },
    "code-review-graph": {
        "name": "Code Review Graph",
        "desc": "Knowledge graph & semantic code review tool (crg serve)",
        "command": shutil.which("python3.14") or PYTHON_BIN,
        "args": ["-m", "code_review_graph", "serve"],
        "cwd": HOME,
        "env": {}
    },
    "puppeteer": {
        "name": "Puppeteer Browser Automation",
        "desc": "Otomatisasi browser headless (@modelcontextprotocol/server-puppeteer)",
        "command": NPX_BIN,
        "args": ["-y", "@modelcontextprotocol/server-puppeteer"],
        "env": {}
    }
}

KNOWN_MCP_DESCS = {
    "termux-device": "Android Bridge: Baterai, Notifikasi, Clipboard, Toast, Sensor",
    "code-review-graph": "Knowledge Graph & Semantic Code Review (CRG Engine)",
    "fetch": "Web Page Content & REST API Fetcher (@modelcontextprotocol/server-fetch)",
    "sqlite": "SQLite Database Explorer & Query Runner",
    "filesystem": "Secure Filesystem Access & File Operations",
    "memory": "Persistent Knowledge Graph Memory across Sessions",
    "github": "GitHub Repository, Issues & Pull Requests Integration",
    "puppeteer": "Headless Browser Automation & Web Scraping"
}

KNOWN_PLUGIN_DESCS = {
    "rtk.ts": "Token Optimization & Bash Command Rewriter (OpenCode)",
    "rtk": "Token Optimization & Bash Command Rewriter (OpenCode)",
    "termux-notifier.ts": "Android Push Notifications & Toast on Task Done",
    "termux-notifier": "Android Push Notifications & Toast on Task Done",
    "crg-plugin.ts": "Code Review Graph Hook & Auto Graph Updater",
    "crg-plugin": "Code Review Graph Hook & Auto Graph Updater",
    "i-have-adhd.mjs": "Subagent Attention & Context Stream Filter",
    "antislop": "Anti-slop coding guidelines & prompt defense bundle"
}

def normalize_target(t):
    if not t:
        return "all"
    t = str(t).lower().strip()
    if t in ("1", "agy", "antigravity", "gemini"):
        return "agy"
    elif t in ("2", "oc", "opencode"):
        return "opencode"
    elif t in ("3", "all", "both", "keduanya"):
        return "all"
    return "all"

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
            content = f.read().strip()
            if not content:
                return {}
            return json.loads(strip_jsonc_comments(content))
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

def load_agy_mcp_servers():
    """Load MCP servers for Antigravity, synchronizing mcp_config.json and settings.json."""
    servers = {}
    
    # 1. Authoritative config for agy /mcp
    c_data = load_json(AGY_MCP_CONFIG)
    if "mcpServers" in c_data and isinstance(c_data["mcpServers"], dict):
        servers.update(c_data["mcpServers"])
        
    # 2. Legacy / hooks config
    s_data = load_json(AGY_SETTINGS)
    if "mcpServers" in s_data and isinstance(s_data["mcpServers"], dict):
        for k, v in s_data["mcpServers"].items():
            if k not in servers:
                servers[k] = v

    # Auto-repair / sync both files if one was missing entries
    if servers:
        need_sync_c = ("mcpServers" not in c_data) or (len(c_data.get("mcpServers", {})) != len(servers))
        need_sync_s = ("mcpServers" not in s_data) or (len(s_data.get("mcpServers", {})) != len(servers))
        if need_sync_c:
            c_data["mcpServers"] = servers
            save_json(AGY_MCP_CONFIG, c_data)
        if need_sync_s:
            s_data["mcpServers"] = servers
            save_json(AGY_SETTINGS, s_data)

    return servers

def save_agy_mcp_server(name, entry):
    """Save an MCP server to both ~/.gemini/config/mcp_config.json and settings.json."""
    # 1. Save to mcp_config.json (Read by agy /mcp)
    c_data = load_json(AGY_MCP_CONFIG)
    if "mcpServers" not in c_data or not isinstance(c_data["mcpServers"], dict):
        c_data["mcpServers"] = {}
    c_data["mcpServers"][name] = entry
    save_json(AGY_MCP_CONFIG, c_data)

    # 2. Save to settings.json (For compatibility)
    s_data = load_json(AGY_SETTINGS)
    if "mcpServers" not in s_data or not isinstance(s_data["mcpServers"], dict):
        s_data["mcpServers"] = {}
    s_data["mcpServers"][name] = entry
    save_json(AGY_SETTINGS, s_data)

def remove_agy_mcp_server(name):
    """Remove an MCP server from both ~/.gemini/config/mcp_config.json and settings.json."""
    removed = False
    c_data = load_json(AGY_MCP_CONFIG)
    if "mcpServers" in c_data and isinstance(c_data["mcpServers"], dict) and name in c_data["mcpServers"]:
        del c_data["mcpServers"][name]
        save_json(AGY_MCP_CONFIG, c_data)
        removed = True

    s_data = load_json(AGY_SETTINGS)
    if "mcpServers" in s_data and isinstance(s_data["mcpServers"], dict) and name in s_data["mcpServers"]:
        del s_data["mcpServers"][name]
        save_json(AGY_SETTINGS, s_data)
        removed = True
    return removed

# ------------------------------------------------------------------------------
# Action: LIST STATUS (MCP SERVERS vs PLUGINS)
# ------------------------------------------------------------------------------
def action_list():
    opencode_data = load_json(OPENCODE_CONFIG)
    agy_mcp = load_agy_mcp_servers()

    oc_mcp_raw = opencode_data.get("mcp", {})
    oc_mcp = oc_mcp_raw.get("servers", oc_mcp_raw) if isinstance(oc_mcp_raw, dict) else {}

    all_mcp_names = sorted(list(set(agy_mcp.keys()) | set(oc_mcp.keys())))
    both_mcps = [k for k in all_mcp_names if k in agy_mcp and k in oc_mcp]
    agy_only_mcps = [k for k in all_mcp_names if k in agy_mcp and k not in oc_mcp]
    oc_only_mcps = [k for k in all_mcp_names if k in oc_mcp and k not in agy_mcp]

    # Plugins OpenCode
    plugins_array = opencode_data.get("plugin", [])
    files_in_plugins_dir = os.listdir(OPENCODE_PLUGINS_DIR) if os.path.exists(OPENCODE_PLUGINS_DIR) else []
    all_oc_plugins = set(files_in_plugins_dir)
    for p in plugins_array:
        all_oc_plugins.add(os.path.basename(str(p)))
    all_oc_plugins = sorted(list(all_oc_plugins))

    # Plugins Antigravity
    agy_plugins = []
    if os.path.exists(AGY_PLUGINS_DIR):
        for entry in sorted(os.listdir(AGY_PLUGINS_DIR)):
            fp = os.path.join(AGY_PLUGINS_DIR, entry)
            if os.path.isdir(fp):
                agy_plugins.append(entry)

    W = 92
    print("\033[1m\033[36m" + "=" * W + "\033[0m")
    print("\033[1m" + "📊 STATUS INTEGRASI: MCP SERVERS vs RUNTIME PLUGINS".center(W) + "\033[0m")
    print("\033[1m\033[36m" + "=" * W + "\033[0m")
    print(" \033[1m\033[33m💡 PANDUAN PERBEDAAN:\033[0m")
    print("   • \033[1m\033[32m[MCP SERVER]\033[0m : Server Tool (stdio/SSE) yang dipanggil model AI (Baterai, DB, Web, Git).")
    print("   • \033[1m\033[35m[PLUGIN]\033[0m     : Ekstensi runtime (TS/JS/Bundle) untuk hook event lifecycle & command rewriter.")
    print("\033[2m" + "─" * W + "\033[0m")
    print(f" \033[1m📈 RINGKASAN:\033[0m")
    print(f"   • Total MCP Servers : \033[1m{len(all_mcp_names)}\033[0m terpasang  (\033[32m{len(both_mcps)} di Keduanya\033[0m | \033[36m{len(agy_only_mcps)} AGY saja\033[0m | \033[33m{len(oc_only_mcps)} OpenCode saja\033[0m)")
    print(f"   • Total Plugins     : \033[1m{len(all_oc_plugins) + len(agy_plugins)}\033[0m terdeteksi  (\033[35m{len(all_oc_plugins)} OpenCode\033[0m | \033[35m{len(agy_plugins)} Antigravity bundle\033[0m)")
    print("\033[1m\033[36m" + "=" * W + "\033[0m\n")

    # --------------------------------------------------------------------------
    # SECTION 1: MCP SERVERS
    # --------------------------------------------------------------------------
    print("\033[1m\033[32m🔌 [KATEGORI 1: MODEL CONTEXT PROTOCOL (MCP) SERVERS]\033[0m")
    print("   \033[2mMenyediakan tools & context provider yang dipanggil oleh model AI\033[0m\n")

    if all_mcp_names:
        print("  \033[1m🌐 Matriks Status Platform:\033[0m")
        for name in all_mcp_names:
            in_agy = name in agy_mcp
            in_oc = name in oc_mcp
            if in_agy and in_oc:
                badge = "\033[1m\033[32m[🌐 KEDUANYA: AGY + OpenCode]\033[0m"
            elif in_agy:
                badge = "\033[1m\033[36m[🚀 AGY SAJA]\033[0m                "
            else:
                badge = "\033[1m\033[33m[⚡ OPENCODE SAJA]\033[0m           "
            desc = KNOWN_MCP_DESCS.get(name, "")
            desc_str = f" \033[2m({desc})\033[0m" if desc else ""
            print(f"    • \033[1m{name:<18}\033[0m -> {badge}{desc_str}")
        print()

        # Detail AGY
        print("  \033[1m1.1 Antigravity CLI (~/.gemini/config/mcp_config.json):\033[0m")
        if agy_mcp:
            for name, cfg in agy_mcp.items():
                cmd = cfg.get("command", "")
                args = " ".join(str(a) for a in cfg.get("args", []))
                full = f"{cmd} {args}".strip()
                if len(full) > 42:
                    full = full[:39] + "..."
                print(f"    • \033[32m[AKTIF]\033[0m \033[1m\033[32m[MCP]\033[0m \033[1m{name:<18}\033[0m -> {full}")
        else:
            print("    \033[33m(Belum ada MCP server terpasang di Antigravity)\033[0m")
        print()

        # Detail OpenCode
        print("  \033[1m1.2 OpenCode (~/.config/opencode/opencode.jsonc):\033[0m")
        if oc_mcp:
            for name, cfg in oc_mcp.items():
                if not isinstance(cfg, dict):
                    continue
                cmd_arr = cfg.get("command", [])
                full = " ".join(cmd_arr) if isinstance(cmd_arr, list) else str(cmd_arr)
                if len(full) > 42:
                    full = full[:39] + "..."
                status = "\033[32m[AKTIF]\033[0m" if cfg.get("enabled", True) else "\033[31m[NONAKTIF]\033[0m"
                print(f"    • {status} \033[1m\033[32m[MCP]\033[0m \033[1m{name:<18}\033[0m -> {full}")
        else:
            print("    \033[33m(Belum ada MCP server terpasang di OpenCode)\033[0m")
    else:
        print("  \033[33m(Belum ada MCP server yang terpasang di sistem)\033[0m")

    print("\n" + "\033[2m" + "─" * W + "\033[0m\n")

    # --------------------------------------------------------------------------
    # SECTION 2: PLUGINS
    # --------------------------------------------------------------------------
    print("\033[1m\033[35m🧩 [KATEGORI 2: RUNTIME PLUGINS & EXTENSIONS]\033[0m")
    print("   \033[2mModul JavaScript/TypeScript & bundle untuk hook event runtime aplikasi\033[0m\n")

    # OpenCode Plugins
    print("  \033[1m2.1 OpenCode Plugins (~/.config/opencode/plugins/ & opencode.jsonc):\033[0m")
    if all_oc_plugins:
        for pfile in all_oc_plugins:
            is_active = any(pfile in str(entry) for entry in plugins_array)
            st = "\033[32m[AKTIF]\033[0m   " if is_active else "\033[33m[TERSEDIA]\033[0m"
            desc = KNOWN_PLUGIN_DESCS.get(pfile, "OpenCode Extension Plugin")
            print(f"    • {st} \033[1m\033[35m[PLUGIN]\033[0m \033[1m{pfile:<20}\033[0m -> {desc}")
    else:
        print("    \033[33m(Tidak ada plugin di OpenCode)\033[0m")
    print()

    # AGY Plugins
    print("  \033[1m2.2 Antigravity Plugins (~/.gemini/config/plugins/):\033[0m")
    if agy_plugins:
        for pdir in agy_plugins:
            desc = KNOWN_PLUGIN_DESCS.get(pdir, "Antigravity Customization Plugin Bundle")
            print(f"    • \033[32m[AKTIF]\033[0m   \033[1m\033[35m[PLUGIN]\033[0m \033[1m{pdir:<20}\033[0m -> {desc}")
    else:
        print("    \033[33m(Tidak ada plugin di ~/.gemini/config/plugins/)\033[0m")

    print("\n\033[1m\033[36m" + "=" * W + "\033[0m")

# ------------------------------------------------------------------------------
# Action: INSTALL MCP SERVER (TARGET: AGY / OPENCODE / ALL)
# ------------------------------------------------------------------------------
def action_install_mcp(preset_id, target="all", custom_env=None):
    target = normalize_target(target)
    if preset_id not in PRESETS:
        skill_presets = ["prompt-master", "antislop", "ui-ux-pro-max", "banner-design"]
        if preset_id in skill_presets or "skill" in preset_id.lower() or preset_id.endswith(".git") or "/" in preset_id:
            print(f"\033[33m[INFO]\033[0m '{preset_id}' terdeteksi sebagai AI Agent Skill (bukan MCP Server).")
            print(f"       Gunakan perintah Skill Manager: \033[1m\033[32maiskill install {preset_id}\033[0m atau \033[1mskill.sh\033[0m")
            return
        print(f"\033[31m[ERROR]\033[0m Preset '{preset_id}' tidak dikenal.")
        return

    info = PRESETS[preset_id]
    cmd = info["command"]
    args = info["args"]
    cwd = info.get("cwd")
    env_vars = dict(info.get("env", {}))
    if custom_env:
        env_vars.update(custom_env)

    # 1. Install to Antigravity CLI (mcp_config.json & settings.json)
    if target in ("all", "agy"):
        server_entry = {
            "command": cmd,
            "args": args
        }
        if cwd:
            server_entry["cwd"] = cwd
        if env_vars:
            server_entry["env"] = env_vars
        save_agy_mcp_server(preset_id, server_entry)
        print(f"\033[32m[OK]\033[0m [MCP SERVER] '{preset_id}' berhasil dipasang ke \033[1mAntigravity CLI\033[0m (~/.gemini/config/mcp_config.json)")

    # 2. Install to OpenCode
    if target in ("all", "opencode"):
        oc_data = load_json(OPENCODE_CONFIG)
        if "$schema" not in oc_data:
            oc_data["$schema"] = "https://opencode.ai/config.json"
        if "mcp" not in oc_data or not isinstance(oc_data["mcp"], dict):
            oc_data["mcp"] = {}
        
        full_command = [cmd] + args
        server_entry = {
            "type": "local",
            "command": full_command,
            "enabled": True
        }
        if env_vars:
            server_entry["environment"] = env_vars
        
        if "servers" in oc_data["mcp"] and isinstance(oc_data["mcp"]["servers"], dict):
            oc_data["mcp"]["servers"][preset_id] = server_entry
        else:
            oc_data["mcp"][preset_id] = server_entry
            
        save_json(OPENCODE_CONFIG, oc_data)
        print(f"\033[32m[OK]\033[0m [MCP SERVER] '{preset_id}' berhasil dipasang ke \033[1mOpenCode\033[0m (~/.config/opencode/opencode.jsonc)")

# ------------------------------------------------------------------------------
# Action: INSTALL CUSTOM MCP SERVER
# ------------------------------------------------------------------------------
def action_install_custom_mcp(mcp_id, target, command, args_str="", env_str=""):
    target = normalize_target(target)
    if not mcp_id or not command:
        print("\033[31m[ERROR]\033[0m ID dan command MCP wajib diisi.")
        return

    args = shlex.split(args_str) if args_str else []
    env_vars = {}
    if env_str:
        for item in env_str.split(","):
            if "=" in item:
                k, v = item.split("=", 1)
                env_vars[k.strip()] = v.strip()

    # 1. Install to Antigravity CLI
    if target in ("all", "agy"):
        server_entry = {
            "command": command,
            "args": args
        }
        if env_vars:
            server_entry["env"] = env_vars
        save_agy_mcp_server(mcp_id, server_entry)
        print(f"\033[32m[OK]\033[0m [MCP SERVER] Custom '{mcp_id}' berhasil dipasang ke \033[1mAntigravity CLI\033[0m (~/.gemini/config/mcp_config.json)")

    # 2. Install to OpenCode
    if target in ("all", "opencode"):
        oc_data = load_json(OPENCODE_CONFIG)
        if "$schema" not in oc_data:
            oc_data["$schema"] = "https://opencode.ai/config.json"
        if "mcp" not in oc_data or not isinstance(oc_data["mcp"], dict):
            oc_data["mcp"] = {}
        
        full_command = [command] + args
        server_entry = {
            "type": "local",
            "command": full_command,
            "enabled": True
        }
        if env_vars:
            server_entry["environment"] = env_vars
        
        if "servers" in oc_data["mcp"] and isinstance(oc_data["mcp"]["servers"], dict):
            oc_data["mcp"]["servers"][mcp_id] = server_entry
        else:
            oc_data["mcp"][mcp_id] = server_entry
            
        save_json(OPENCODE_CONFIG, oc_data)
        print(f"\033[32m[OK]\033[0m [MCP SERVER] Custom '{mcp_id}' berhasil dipasang ke \033[1mOpenCode\033[0m (~/.config/opencode/opencode.jsonc)")

# ------------------------------------------------------------------------------
# Action: INSTALL OPENCODE PLUGIN
# ------------------------------------------------------------------------------
def action_install_plugin(plugin_name):
    src_file = os.path.join(REPO_DIR, "plugins", f"{plugin_name}.ts")
    if not os.path.exists(src_file):
        src_file = os.path.join(REPO_DIR, "plugins", plugin_name)
    
    if not os.path.exists(src_file):
        print(f"\033[31m[ERROR]\033[0m File plugin '{plugin_name}' tidak ditemukan di repositori.")
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
        print(f"\033[32m[OK]\033[0m [PLUGIN] '{os.path.basename(dest_file)}' aktif didaftarkan ke opencode.jsonc")
    else:
        print(f"[INFO] Plugin sudah terdaftar di opencode.jsonc")

# ------------------------------------------------------------------------------
# Action: REMOVE MCP / PLUGIN (TARGET: AGY / OPENCODE / ALL)
# ------------------------------------------------------------------------------
def action_remove(name, target="all"):
    target = normalize_target(target)
    removed_any = False

    # Check if removing MCP from AGY
    if target in ("all", "agy"):
        if remove_agy_mcp_server(name):
            print(f"\033[32m[OK]\033[0m [MCP SERVER] '{name}' dihapus dari \033[1mAntigravity CLI\033[0m")
            removed_any = True

    # Check if removing MCP from OpenCode
    if target in ("all", "opencode"):
        oc_data = load_json(OPENCODE_CONFIG)
        if "mcp" in oc_data and isinstance(oc_data["mcp"], dict):
            if name in oc_data["mcp"]:
                del oc_data["mcp"][name]
                save_json(OPENCODE_CONFIG, oc_data)
                print(f"\033[32m[OK]\033[0m [MCP SERVER] '{name}' dihapus dari \033[1mOpenCode\033[0m")
                removed_any = True
            elif "servers" in oc_data["mcp"] and isinstance(oc_data["mcp"]["servers"], dict) and name in oc_data["mcp"]["servers"]:
                del oc_data["mcp"]["servers"][name]
                save_json(OPENCODE_CONFIG, oc_data)
                print(f"\033[32m[OK]\033[0m [MCP SERVER] '{name}' dihapus dari \033[1mOpenCode\033[0m")
                removed_any = True

    # Check if removing OpenCode Plugin
    if target in ("all", "opencode"):
        oc_data = load_json(OPENCODE_CONFIG)
        if "plugin" in oc_data and isinstance(oc_data["plugin"], list):
            orig_len = len(oc_data["plugin"])
            oc_data["plugin"] = [p for p in oc_data["plugin"] if name not in str(p)]
            if len(oc_data["plugin"]) != orig_len:
                save_json(OPENCODE_CONFIG, oc_data)
                print(f"\033[32m[OK]\033[0m [PLUGIN] '{name}' dinonaktifkan dari \033[1mOpenCode\033[0m (opencode.jsonc)")
                removed_any = True

    if not removed_any:
        print(f"\033[33m[WARN]\033[0m '{name}' tidak ditemukan di konfigurasi target '{target}'")

# ------------------------------------------------------------------------------
# Action: TEST MCP COMMAND
# ------------------------------------------------------------------------------
def action_test(name):
    agy_mcp = load_agy_mcp_servers()
    oc_data = load_json(OPENCODE_CONFIG)

    cmd = None
    if name in agy_mcp:
        cmd = agy_mcp[name].get("command")
    elif "mcp" in oc_data:
        m = oc_data["mcp"]
        cfg = None
        if isinstance(m, dict):
            if name in m:
                cfg = m[name]
            elif "servers" in m and isinstance(m["servers"], dict) and name in m["servers"]:
                cfg = m["servers"][name]
        if isinstance(cfg, dict):
            c = cfg.get("command", [])
            cmd = c[0] if isinstance(c, list) and c else c

    if not cmd:
        print(f"\033[33m[WARN]\033[0m Server MCP '{name}' tidak ditemukan di konfigurasi AGY maupun OpenCode.")
        return

    path_loc = shutil.which(cmd)
    if path_loc:
        print(f"\033[32m[PASS]\033[0m Perintah '{cmd}' terdeteksi dan dapat dieksekusi ({path_loc})")
    else:
        print(f"\033[31m[FAIL]\033[0m Perintah '{cmd}' tidak ditemukan di PATH sistem!")

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
elif cmd == "install-custom-mcp":
    cid = sys.argv[3] if len(sys.argv) > 3 else ""
    target = sys.argv[4] if len(sys.argv) > 4 else "all"
    ccmd = sys.argv[5] if len(sys.argv) > 5 else ""
    cargs = sys.argv[6] if len(sys.argv) > 6 else ""
    cenv = sys.argv[7] if len(sys.argv) > 7 else ""
    action_install_custom_mcp(cid, target, ccmd, cargs, cenv)
elif cmd == "install-plugin":
    pname = sys.argv[3] if len(sys.argv) > 3 else "termux-notifier"
    action_install_plugin(pname)
elif cmd in ("remove", "rm", "del"):
    name = sys.argv[3] if len(sys.argv) > 3 else ""
    target = sys.argv[4] if len(sys.argv) > 4 else "all"
    if name:
        action_remove(name, target)
    else:
        print("Gunakan: remove <nama> [target]")
elif cmd == "test":
    name = sys.argv[3] if len(sys.argv) > 3 else ""
    if name:
        action_test(name)
    else:
        print("Gunakan: test <nama>")

EOF
}

# ------------------------------------------------------------------------------
# Target Selection Helpers
# ------------------------------------------------------------------------------
prompt_target() {
    local preset_name="${1:-MCP Server}"
    echo "" >&2
    echo -e "${BOLD}${CYAN}==================================================${RESET}" >&2
    echo -e "${BOLD}🎯 Target Platform untuk '${preset_name}':${RESET}" >&2
    echo -e "${BOLD}${CYAN}==================================================${RESET}" >&2
    echo -e "  ${GREEN}1)${RESET} 🚀 Antigravity CLI (${BOLD}agy${RESET})" >&2
    echo -e "  ${GREEN}2)${RESET} ⚡ OpenCode (${BOLD}opencode${RESET})" >&2
    echo -e "  ${GREEN}3)${RESET} 🌐 Kedua-duanya (${BOLD}AGY & OpenCode${RESET}) ${DIM}[Rekomendasi / Default]${RESET}" >&2
    echo "" >&2
    read -r -p "Pilihan target [1-3, default: 3]: " t_choice
    case "$t_choice" in
        1|agy|AGY|antigravity) echo "agy" ;;
        2|oc|OC|opencode) echo "opencode" ;;
        *) echo "all" ;;
    esac
}

prompt_remove_target() {
    local item_name="${1:-item}"
    echo "" >&2
    echo -e "${BOLD}${YELLOW}==================================================${RESET}" >&2
    echo -e "${BOLD}🎯 Hapus '${item_name}' dari platform mana?${RESET}" >&2
    echo -e "${BOLD}${YELLOW}==================================================${RESET}" >&2
    echo -e "  ${CYAN}1)${RESET} 🚀 Antigravity CLI saja (${BOLD}agy${RESET})" >&2
    echo -e "  ${CYAN}2)${RESET} ⚡ OpenCode saja (${BOLD}opencode${RESET})" >&2
    echo -e "  ${CYAN}3)${RESET} 🌐 Kedua-duanya (${BOLD}all${RESET}) ${DIM}[Default]${RESET}" >&2
    echo "" >&2
    read -r -p "Pilihan target [1-3, default: 3]: " r_choice
    case "$r_choice" in
        1|agy|AGY|antigravity) echo "agy" ;;
        2|oc|OC|opencode) echo "opencode" ;;
        *) echo "all" ;;
    esac
}

install_custom_mcp_interactive() {
    echo ""
    echo -e "${BOLD}${CYAN}--- ➕ Tambah Custom MCP Server ---${RESET}"
    read -r -p "Masukkan ID/Nama unik MCP (contoh: my-mcp): " cust_id
    if [ -z "$cust_id" ]; then
        log_warn "ID MCP tidak boleh kosong."
        return
    fi
    read -r -p "Masukkan perintah eksekusi utama (contoh: npx, python3, node): " cust_cmd
    if [ -z "$cust_cmd" ]; then
        log_warn "Command utama tidak boleh kosong."
        return
    fi
    read -r -p "Masukkan argumen (contoh: -y @modelcontextprotocol/server-xyz, opsional): " cust_args
    read -r -p "Masukkan environment variables (format: KEY=VAL,KEY2=VAL2, opsional): " cust_env
    
    local target_platform
    target_platform="$(prompt_target "$cust_id")"
    log_info "Memasang Custom MCP '$cust_id' ke target: $target_platform..."
    run_python_manager "install-custom-mcp" "$REPO_DIR" "$cust_id" "$target_platform" "$cust_cmd" "$cust_args" "$cust_env"
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
        echo -e "  ${DIM}--- PASANG MCP SERVERS (PILIH: AGY / OPENCODE / KEDUANYA) ---${RESET}"
        echo -e "  ${GREEN}1)${RESET}  📱 Pasang MCP: Termux Device Bridge (Baterai, Notifikasi, Clipboard)"
        echo -e "  ${GREEN}2)${RESET}  🌐 Pasang MCP: Web Fetcher (Akses URL web & REST API)"
        echo -e "  ${GREEN}3)${RESET}  🗄️  Pasang MCP: SQLite Database Explorer"
        echo -e "  ${GREEN}4)${RESET}  📁 Pasang MCP: Filesystem Manager"
        echo -e "  ${GREEN}5)${RESET}  🧠 Pasang MCP: Memory Knowledge Graph"
        echo -e "  ${GREEN}6)${RESET}  🐙 Pasang MCP: GitHub API Integration"
        echo -e "  ${GREEN}7)${RESET}  📊 Pasang MCP: Code Review Graph (CRG)"
        echo -e "  ${GREEN}8)${RESET}  ➕ Pasang Custom MCP Server (Bebas: Command / NPX / Python)"
        echo ""
        echo -e "  ${DIM}--- PASANG OPENCODE PLUGINS ---${RESET}"
        echo -e "  ${CYAN}9)${RESET}  🔔 Pasang OpenCode Plugin: Termux Notifier"
        echo -e "  ${CYAN}10)${RESET} ⚡ Pasang OpenCode Plugin: RTK (Token Savings & Rewriter)"
        echo ""
        echo -e "  ${DIM}--- PENGUJIAN & PENGELOLAAN ---${RESET}"
        echo -e "  ${YELLOW}11)${RESET} 🧪 Uji Validitas Eksekusi MCP Server"
        echo -e "  ${RED}12)${RESET} 🗑️  Hapus MCP Server / Plugin (Pilih Target)"
        echo -e "  ${CYAN}13)${RESET} 🧠 Kelola AI Agent Skills (skill.sh / aiskill)"
        echo -e "  ${YELLOW}0)${RESET}  🚪 Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-13]: " menu_opt

        case "$menu_opt" in
            1)
                t="$(prompt_target "Termux Device Bridge")"
                log_info "Memasang MCP: Termux Device Bridge ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "termux-device" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            2)
                t="$(prompt_target "Web Fetcher")"
                log_info "Memasang MCP: Web Fetcher ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "fetch" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            3)
                t="$(prompt_target "SQLite Explorer")"
                log_info "Memasang MCP: SQLite Explorer ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "sqlite" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                t="$(prompt_target "Filesystem Manager")"
                log_info "Memasang MCP: Filesystem ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "filesystem" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            5)
                t="$(prompt_target "Memory Graph")"
                log_info "Memasang MCP: Memory Graph ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "memory" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            6)
                echo ""
                read -r -p "Masukkan GitHub Personal Access Token (kosongkan jika nanti): " gh_tok
                t="$(prompt_target "GitHub Integration")"
                log_info "Memasang MCP: GitHub ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "github" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            7)
                t="$(prompt_target "Code Review Graph")"
                log_info "Memasang MCP: Code Review Graph ke target '$t'..."
                run_python_manager "install-mcp" "$REPO_DIR" "code-review-graph" "$t"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            8)
                install_custom_mcp_interactive
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            9)
                echo ""
                log_info "Memasang OpenCode Plugin: Termux Notifier..."
                run_python_manager "install-plugin" "$REPO_DIR" "termux-notifier"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            10)
                echo ""
                log_info "Memasang OpenCode Plugin: RTK..."
                run_python_manager "install-plugin" "$REPO_DIR" "rtk"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            11)
                echo ""
                read -r -p "Masukkan nama MCP server yang ingin diuji (contoh: termux-device): " test_name
                if [ -n "$test_name" ]; then
                    echo ""
                    run_python_manager "test" "$REPO_DIR" "$test_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            12)
                echo ""
                read -r -p "Masukkan nama MCP atau plugin yang ingin dihapus: " del_name
                if [ -n "$del_name" ]; then
                    del_target="$(prompt_remove_target "$del_name")"
                    read -r -p "Yakin ingin menghapus '$del_name' dari target '$del_target'? (y/N): " conf_del
                    if [[ "$conf_del" =~ ^[Yy]$ ]]; then
                        echo ""
                        run_python_manager "remove" "$REPO_DIR" "$del_name" "$del_target"
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            13)
                echo ""
                if [ -f "$REPO_DIR/skill.sh" ]; then
                    bash "$REPO_DIR/skill.sh"
                elif [ -f "$TOOLS_DIR/skill.sh" ]; then
                    bash "$TOOLS_DIR/skill.sh"
                fi
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
        target="${2:-}"
        if [ "$preset" = "notifier" ] || [ "$preset" = "termux-notifier" ]; then
            run_python_manager "install-plugin" "$REPO_DIR" "termux-notifier"
        elif [ "$preset" = "rtk" ]; then
            run_python_manager "install-plugin" "$REPO_DIR" "rtk"
        else
            if [ -z "$target" ]; then
                if [ -t 0 ]; then
                    target="$(prompt_target "$preset")"
                else
                    target="all"
                fi
            fi
            run_python_manager "install-mcp" "$REPO_DIR" "$preset" "$target"
        fi
        ;;
    add-custom)
        shift
        cid="$1"
        target="${2:-all}"
        ccmd="$3"
        cargs="$4"
        cenv="$5"
        if [ -z "$cid" ] || [ -z "$ccmd" ]; then
            echo "Gunakan: plugin.sh add-custom <id> <target:agy|oc|all> <command> [args] [env]"
            exit 1
        fi
        run_python_manager "install-custom-mcp" "$REPO_DIR" "$cid" "$target" "$ccmd" "$cargs" "$cenv"
        ;;
    remove|rm|del)
        shift
        name="$1"
        target="${2:-}"
        if [ -n "$name" ]; then
            if [ -z "$target" ]; then
                if [ -t 0 ]; then
                    target="$(prompt_remove_target "$name")"
                else
                    target="all"
                fi
            fi
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
        echo "  plugin.sh status                   Tampilkan status terperinci MCP vs Plugins"
        echo "  plugin.sh install <preset> [target]Pasang preset MCP (target: agy, opencode, all)"
        echo "  plugin.sh add-custom <id> <target> <command> [args] [env]"
        echo "                                     Pasang custom MCP server ke target"
        echo "  plugin.sh remove <nama> [target]   Hapus MCP server atau plugin (target: agy, opencode, all)"
        echo "  plugin.sh test <nama>              Uji apakah command/binary MCP server tersedia di sistem"
        exit 0
        ;;
    *)
        interactive_menu
        ;;
esac
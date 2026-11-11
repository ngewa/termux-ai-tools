#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Multi-Account, Quota Monitoring & Rotation Manager
# Command: ai account [command] [args...]
# Features:
#   1. Multi-account management (personal, work, testing in single registry)
#   2. Account switching without re-login
#   3. Automatic quota rotation & failover pool
#   4. Quota monitoring (5-hour window, weekly, model groups, reset time)
#   5. Credential backup with PBKDF2 AES-256 + HMAC-SHA256 authenticated encryption
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(dirname "$SCRIPT_DIR")"

REGISTRY_DIR="$HOME_DIR/.config/termux-ai"
REGISTRY_FILE="$REGISTRY_DIR/accounts.json"
BACKUP_DIR="$REGISTRY_DIR/backups"

AUTH_FILE="$HOME_DIR/.local/share/opencode/auth.json"
CONFIG_FILE="$HOME_DIR/.config/opencode/opencode.jsonc"
AGY_SETTINGS_FILE="$HOME_DIR/.gemini/antigravity-cli/settings.json"
ENV_FILE="$HOME_DIR/.termux_ai_env"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
MAGENTA="\033[35m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

log_info() { echo -e "${CYAN}[INFO]${RESET} $1"; }
log_ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
log_err() { echo -e "${RED}[ERROR]${RESET} $1"; }

mkdir -p "$REGISTRY_DIR" "$BACKUP_DIR" "$HOME_DIR/.local/share/opencode" "$HOME_DIR/.config/opencode" "$HOME_DIR/.gemini/antigravity-cli"
chmod 700 "$REGISTRY_DIR" "$BACKUP_DIR" 2>/dev/null || true

# ------------------------------------------------------------------------------
# Python Account & Quota Engine
# ------------------------------------------------------------------------------
run_account_engine() {
    python3 - "$@" << 'EOF'
import sys, os, json, datetime, time, urllib.request, urllib.error, ssl, subprocess, hashlib

HOME = os.path.expanduser("~")
REGISTRY_DIR = os.path.join(HOME, ".config/termux-ai")
REGISTRY_FILE = os.path.join(REGISTRY_DIR, "accounts.json")
BACKUP_DIR = os.path.join(REGISTRY_DIR, "backups")

AUTH_FILE = os.path.join(HOME, ".local/share/opencode/auth.json")
CONFIG_FILE = os.path.join(HOME, ".config/opencode/opencode.jsonc")
AGY_SETTINGS_FILE = os.path.join(HOME, ".gemini/antigravity-cli/settings.json")
ENV_FILE = os.path.join(HOME, ".termux_ai_env")

GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RED = "\033[31m"
MAGENTA = "\033[35m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

def mask_key(k):
    if not k:
        return "-"
    if len(k) <= 8:
        return "***"
    return k[:6] + "..." + k[-4:]

def get_ssl_context():
    ctx = ssl.create_default_context()
    cert_paths = [
        "/data/data/com.termux/files/usr/etc/tls/cert.pem",
        "/etc/ssl/certs/ca-certificates.crt"
    ]
    for cp in cert_paths:
        if os.path.exists(cp):
            ctx.load_verify_locations(cafile=cp)
            break
    return ctx

def read_json_safe(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        clean = []
        for line in lines:
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("#"):
                continue
            clean.append(line)
        return json.loads("".join(clean))
    except Exception:
        return {}

def write_json_safe(path, data, mode=0o600):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    temp_path = path + f".tmp.{os.getpid()}"
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    os.chmod(temp_path, mode)
    os.replace(temp_path, path)

def is_valid_agy_model(m):
    if not m or not isinstance(m, str):
        return False
    m_clean = m.strip().lower()
    if "/" in m_clean or "luna" in m_clean:
        return False
    return True

def load_registry():
    if os.path.exists(REGISTRY_FILE):
        try:
            with open(REGISTRY_FILE, "r", encoding="utf-8") as f:
                reg = json.load(f)
                if "profiles" in reg and isinstance(reg["profiles"], dict) and len(reg["profiles"]) > 0:
                    return reg
        except Exception:
            pass

    # Auto-bootstrap registry from current active credentials if accounts.json is missing
    reg = {
        "version": 1,
        "active_profile": "default",
        "rotation_pool": ["default"],
        "profiles": {}
    }

    # Extract existing configs
    auth = read_json_safe(AUTH_FILE)
    cfg = read_json_safe(CONFIG_FILE)
    agy = read_json_safe(AGY_SETTINGS_FILE)

    default_providers = {}
    default_model = cfg.get("model", "")
    default_agy_model = agy.get("model", "")

    # OpenCode providers
    for prov_id, pdata in auth.items():
        if isinstance(pdata, dict) and "key" in pdata:
            default_providers[prov_id] = {
                "apiKey": pdata.get("key", ""),
                "target": "opencode",
                "baseURL": pdata.get("baseURL", ""),
                "apiMode": pdata.get("apiMode", "auto")
            }

    # Antigravity providers
    agy_provs = agy.get("providers", {})
    for prov_id, pdata in agy_provs.items():
        if isinstance(pdata, dict) and "apiKey" in pdata:
            if prov_id in default_providers:
                default_providers[prov_id]["target"] = "all"
            else:
                default_providers[prov_id] = {
                    "apiKey": pdata.get("apiKey", ""),
                    "target": "agy",
                    "baseURL": pdata.get("baseURL", ""),
                    "apiMode": pdata.get("apiMode", "auto")
                }

    reg["profiles"]["default"] = {
        "name": "default",
        "description": "Akun default awal (Auto-migrated)",
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "model": default_model,
        "agy_model": default_agy_model,
        "providers": default_providers
    }

    write_json_safe(REGISTRY_FILE, reg)
    return reg

def save_registry(reg):
    write_json_safe(REGISTRY_FILE, reg)

def sync_active_profile_to_system(reg):
    active_name = reg.get("active_profile", "default")
    profile = reg.get("profiles", {}).get(active_name)
    if not profile:
        return False

    providers = profile.get("providers", {})
    profile_model = profile.get("model", "")
    profile_agy_model = profile.get("agy_model", "")

    # 1. Update OpenCode auth.json
    auth_data = read_json_safe(AUTH_FILE)
    for prov_id, pinfo in providers.items():
        target = pinfo.get("target", "all")
        if target in ("opencode", "all"):
            auth_data[prov_id] = {
                "type": "api",
                "key": pinfo.get("apiKey", "")
            }
            if pinfo.get("baseURL"):
                auth_data[prov_id]["baseURL"] = pinfo["baseURL"]
            if pinfo.get("apiMode"):
                auth_data[prov_id]["apiMode"] = pinfo["apiMode"]

    write_json_safe(AUTH_FILE, auth_data)

    # 2. Update OpenCode opencode.jsonc
    cfg_data = read_json_safe(CONFIG_FILE)
    if profile_model:
        cfg_data["model"] = profile_model
    write_json_safe(CONFIG_FILE, cfg_data)

    # 3. Update Antigravity settings.json
    agy_data = read_json_safe(AGY_SETTINGS_FILE)
    if profile_agy_model:
        agy_data["model"] = profile_agy_model
    elif profile_model and is_valid_agy_model(profile_model):
        agy_data["model"] = profile_model
    if "providers" not in agy_data:
        agy_data["providers"] = {}
    for prov_id, pinfo in providers.items():
        target = pinfo.get("target", "all")
        if target in ("agy", "all"):
            agy_data["providers"][prov_id] = {
                "apiKey": pinfo.get("apiKey", "")
            }
            if pinfo.get("baseURL"):
                agy_data["providers"][prov_id]["baseURL"] = pinfo["baseURL"]
            if pinfo.get("model"):
                agy_data["providers"][prov_id]["model"] = pinfo["model"]
    write_json_safe(AGY_SETTINGS_FILE, agy_data)

    # 4. Update Shell ~/.termux_ai_env
    env_lines = [
        f"# Termux AI Tools Environment - Active Profile: {active_name}",
        f"# Generated at {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}"
    ]
    env_map = {
        "google": "GEMINI_API_KEY",
        "anthropic": "ANTHROPIC_API_KEY",
        "openai": "OPENAI_API_KEY",
        "deepseek": "DEEPSEEK_API_KEY",
        "openrouter": "OPENROUTER_API_KEY",
        "groq": "GROQ_API_KEY",
        "mistral": "MISTRAL_API_KEY",
        "xai": "XAI_API_KEY",
        "bynara": "BYNARA_API_KEY"
    }
    for prov_id, pinfo in providers.items():
        var_name = env_map.get(prov_id, f"{prov_id.upper()}_API_KEY")
        key = pinfo.get("apiKey", "")
        if key:
            env_lines.append(f"export {var_name}=\"{key}\"")
        if pinfo.get("baseURL"):
            env_lines.append(f"export {prov_id.upper()}_BASE_URL=\"{pinfo['baseURL']}\"")
    if profile_model:
        env_lines.append(f"export AI_DEFAULT_MODEL=\"{profile_model}\"")

    try:
        with open(ENV_FILE, "w", encoding="utf-8") as f:
            f.write("\n".join(env_lines) + "\n")
        os.chmod(ENV_FILE, 0o600)
    except Exception:
        pass

    return True

# ------------------------------------------------------------------------------
# Action Handlers
# ------------------------------------------------------------------------------

def cmd_list(args):
    reg = load_registry()
    active_name = reg.get("active_profile", "")
    pool = reg.get("rotation_pool", [])
    profiles = reg.get("profiles", {})

    print(f"\n{BOLD}{CYAN}========================================================================================{RESET}")
    print(f"{BOLD}                        REGISTRY MULTI-ACCOUNT & POOL ROTASI                           {RESET}")
    print(f"{BOLD}{CYAN}========================================================================================{RESET}")
    print(f"🎯 Profil Aktif : {GREEN}{BOLD}{active_name}{RESET}")
    print(f"🔄 Pool Rotasi  : {YELLOW}{', '.join(pool) if pool else '(kosong)'}{RESET}\n")

    print(f"{BOLD}{'STATUS':<8} {'PROFIL':<15} {'POOL':<8} {'MODEL DEFAULT':<28} {'JUMLAH PROVIDER':<15}{RESET}")
    print("-" * 88)

    for name, pdata in profiles.items():
        is_active = (name == active_name)
        in_pool = (name in pool)
        status_str = f"{GREEN}[*AKTIF]{RESET}" if is_active else f"{DIM}[     ]{RESET}"
        pool_str = f"{YELLOW}[POOL]{RESET}" if in_pool else f"{DIM}-{RESET}"
        model_str = pdata.get("model", "") or "(default)"
        if len(model_str) > 26:
            model_str = model_str[:24] + ".."
        provs = pdata.get("providers", {})
        prov_summary = f"{len(provs)} provider"
        if provs:
            prov_names = list(provs.keys())[:3]
            prov_summary += f" ({', '.join(prov_names)})"

        print(f"{status_str:<17} {BOLD}{name:<15}{RESET} {pool_str:<16} {model_str:<28} {prov_summary:<15}")

    print("-" * 88)
    print(f"\n{DIM}Tip: Gunakan 'ai account switch <nama>' untuk berganti akun instan.{RESET}\n")

def cmd_current(args):
    reg = load_registry()
    target_name = args[0] if args else reg.get("active_profile", "")
    profile = reg.get("profiles", {}).get(target_name)
    if not profile:
        print(f"{RED}[ERROR] Profil '{target_name}' tidak ditemukan di registry!{RESET}")
        sys.exit(1)

    pool = reg.get("rotation_pool", [])
    is_active = (target_name == reg.get("active_profile", ""))
    active_str = f" {GREEN}[AKTIF]{RESET}" if is_active else ""
    header_title = "Detail Profil Aktif" if is_active else "Detail Profil"
    print(f"\n{BOLD}{CYAN}=== {header_title}: {target_name}{active_str} ==={RESET}")
    print(f"• Deskripsi     : {profile.get('description', '-')}")
    print(f"• Dibuat pada   : {profile.get('created_at', '-')}")
    print(f"• Default Model : {profile.get('model', '(system default)')}")
    print(f"• Status Pool   : {'Terdaftar di Pool Rotasi' if target_name in pool else 'Tidak di rotasi pool'}")
    print(f"\n{BOLD}Daftar Provider & Kredensial:{RESET}")
    provs = profile.get("providers", {})
    if not provs:
        print("  (Belum ada provider dikonfigurasi)")
    for pid, pinfo in provs.items():
        target = pinfo.get("target", "all")
        m_key = mask_key(pinfo.get("apiKey", ""))
        b_url = pinfo.get("baseURL", "default")
        print(f"  • {BOLD}{pid:<12}{RESET}: Target={target:<8} | Key={m_key:<16} | BaseURL={b_url}")
    print()

def cmd_switch(args):
    if not args:
        print(f"{RED}[ERROR] Masukkan nama profil target.{RESET} Contoh: ai account switch work")
        sys.exit(1)

    target_name = args[0]
    reg = load_registry()
    profiles = reg.get("profiles", {})
    if target_name not in profiles:
        print(f"{RED}[ERROR] Profil '{target_name}' tidak ditemukan di registry!{RESET}")
        print(f"Profil yang tersedia: {', '.join(profiles.keys())}")
        sys.exit(1)

    reg["active_profile"] = target_name
    save_registry(reg)
    sync_active_profile_to_system(reg)

    prof = profiles[target_name]
    print(f"\n{GREEN}[OK] Berhasil beralih ke profil: {BOLD}{target_name}{RESET}")
    print(f"• Model aktif   : {prof.get('model', '(default)')}")
    prov_keys = list(prof.get("providers", {}).keys())
    print(f"• Provider aktif: {', '.join(prov_keys) if prov_keys else '(none)'}")
    print(f"• Kredensial disinkronkan ke OpenCode (auth.json), Antigravity, dan ~/.termux_ai_env\n")

def cmd_add(args):
    # Syntax: add <name> [description]
    if not args:
        print(f"{RED}[ERROR] Nama profil wajib diisi.{RESET} Contoh: ai account add work \"Akun Kantor\"")
        sys.exit(1)

    name = args[0]
    desc = args[1] if len(args) > 1 else f"Profil {name}"
    reg = load_registry()
    profiles = reg.get("profiles", {})

    if name in profiles:
        print(f"{YELLOW}[WARN] Profil '{name}' sudah ada. Memperbarui metadata.{RESET}")
        profiles[name]["description"] = desc
    else:
        profiles[name] = {
            "name": name,
            "description": desc,
            "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
            "model": "",
            "providers": {}
        }

    save_registry(reg)
    print(f"{GREEN}[OK] Profil '{name}' berhasil didaftarkan.{RESET}")
    print(f"Gunakan 'ai account set-key {name} <provider> <api_key>' untuk menambah kredensial ke profil ini.")

def cmd_set_key(args):
    # Syntax: set-key <profile> <provider> <key> [model] [target] [baseURL]
    if len(args) < 3:
        print(f"{RED}[ERROR] Parameter kurang.{RESET} Format: ai account set-key <profil> <provider> <key> [model] [target]")
        sys.exit(1)

    prof_name = args[0]
    provider = args[1].lower()
    key = args[2]
    model = args[3] if len(args) > 3 and args[3] != "-" else ""
    target = args[4] if len(args) > 4 and args[4] != "-" else "all"
    base_url = args[5] if len(args) > 5 and args[5] != "-" else ""

    reg = load_registry()
    if prof_name not in reg.get("profiles", {}):
        print(f"{RED}[ERROR] Profil '{prof_name}' tidak ditemukan.{RESET}")
        sys.exit(1)

    prof = reg["profiles"][prof_name]
    if "providers" not in prof:
        prof["providers"] = {}

    prof["providers"][provider] = {
        "apiKey": key,
        "target": target
    }
    if model:
        prof["providers"][provider]["model"] = model
        if not prof.get("model"):
            prof["model"] = model
    if base_url:
        prof["providers"][provider]["baseURL"] = base_url

    save_registry(reg)
    print(f"{GREEN}[OK] Provider '{provider}' berhasil disimpan ke profil '{prof_name}'.{RESET}")

    # If this is the active profile, immediately sync
    if reg.get("active_profile") == prof_name:
        sync_active_profile_to_system(reg)
        print(f"{CYAN}[INFO] Profil aktif langsung disinkronkan ke sistem.{RESET}")

def cmd_remove(args):
    if not args:
        print(f"{RED}[ERROR] Masukkan nama profil yang akan dihapus.{RESET}")
        sys.exit(1)

    target_name = args[0]
    reg = load_registry()
    profiles = reg.get("profiles", {})

    if target_name not in profiles:
        print(f"{RED}[ERROR] Profil '{target_name}' tidak ditemukan.{RESET}")
        sys.exit(1)

    if target_name == "default" and len(profiles) == 1:
        print(f"{RED}[ERROR] Tidak dapat menghapus profil satu-satunya 'default'.{RESET}")
        sys.exit(1)

    del profiles[target_name]
    pool = reg.get("rotation_pool", [])
    if target_name in pool:
        pool.remove(target_name)

    if reg.get("active_profile") == target_name:
        new_active = list(profiles.keys())[0]
        reg["active_profile"] = new_active
        print(f"{YELLOW}[WARN] Profil aktif dihapus. Otomatis beralih ke '{new_active}'.{RESET}")
        sync_active_profile_to_system(reg)

    save_registry(reg)
    print(f"{GREEN}[OK] Profil '{target_name}' berhasil dihapus dari registry.{RESET}")

def cmd_pool(args):
    reg = load_registry()
    pool = reg.get("rotation_pool", [])
    profiles = reg.get("profiles", {})

    if not args or args[0] in ("list", "show"):
        print(f"\n{BOLD}{CYAN}=== Konfigurasi Failover Pool Rotasi Otomatis ==={RESET}")
        print(f"Urutan rotasi saat ini: {YELLOW}{' -> '.join(pool) if pool else '(kosong)'}{RESET}")
        print(f"\nProfil yang terdaftar:")
        for idx, p in enumerate(pool, 1):
            prov_count = len(profiles.get(p, {}).get("providers", {}))
            print(f"  {idx}. {BOLD}{p:<15}{RESET} ({prov_count} provider dikonfigurasi)")
        print(f"\n{DIM}Atur urutan rotasi: ai account pool set p1,p2,p3{RESET}\n")
        return

    sub = args[0]
    if sub == "set":
        if len(args) < 2:
            print(f"{RED}[ERROR] Tentukan daftar profil.{RESET} Contoh: ai account pool set personal,work,testing")
            sys.exit(1)
        raw_list = [x.strip() for x in args[1].replace(" ", ",").split(",") if x.strip()]
        valid_list = []
        for p in raw_list:
            if p in profiles:
                if p not in valid_list:
                    valid_list.append(p)
            else:
                print(f"{YELLOW}[WARN] Profil '{p}' dilewati karena tidak ada di registry.{RESET}")
        reg["rotation_pool"] = valid_list
        save_registry(reg)
        print(f"{GREEN}[OK] Pool rotasi diperbarui: {BOLD}{' -> '.join(valid_list)}{RESET}")
    elif sub in ("add", "+"):
        if len(args) < 2:
            print(f"{RED}[ERROR] Masukkan nama profil untuk ditambahkan ke pool.{RESET}")
            sys.exit(1)
        target = args[1]
        if target not in profiles:
            print(f"{RED}[ERROR] Profil '{target}' tidak ditemukan di registry.{RESET}")
            sys.exit(1)
        if target not in pool:
            pool.append(target)
            reg["rotation_pool"] = pool
            save_registry(reg)
            print(f"{GREEN}[OK] Profil '{target}' ditambahkan ke pool rotasi.{RESET}")
        else:
            print(f"{YELLOW}[WARN] Profil '{target}' sudah ada di pool.{RESET}")
    elif sub in ("del", "remove", "-"):
        if len(args) < 2:
            print(f"{RED}[ERROR] Masukkan nama profil untuk dihapus dari pool.{RESET}")
            sys.exit(1)
        target = args[1]
        if target in pool:
            pool.remove(target)
            reg["rotation_pool"] = pool
            save_registry(reg)
            print(f"{GREEN}[OK] Profil '{target}' dihapus dari pool rotasi.{RESET}")
        else:
            print(f"{YELLOW}[WARN] Profil '{target}' tidak ada di pool.{RESET}")

def cmd_rotate(args):
    reg = load_registry()
    pool = reg.get("rotation_pool", [])
    profiles = reg.get("profiles", {})
    active_name = reg.get("active_profile", "")

    if not pool:
        pool = list(profiles.keys())

    if not pool or len(pool) <= 1:
        print(f"{YELLOW}[WARN] Pool rotasi hanya memiliki 1 atau 0 profil. Tidak bisa rotasi.{RESET}")
        sys.exit(0)

    try:
        curr_idx = pool.index(active_name)
        next_idx = (curr_idx + 1) % len(pool)
    except ValueError:
        next_idx = 0

    next_profile = pool[next_idx]
    reg["active_profile"] = next_profile
    save_registry(reg)
    sync_active_profile_to_system(reg)

    print(f"\n{BOLD}{MAGENTA}🔄 [ROTASI OTOMATIS BERHASIL]{RESET}")
    print(f"  • Dari Profil : {DIM}{active_name}{RESET}")
    print(f"  • Ke Profil   : {GREEN}{BOLD}{next_profile}{RESET}")
    prof = profiles[next_profile]
    print(f"  • Model Aktif : {prof.get('model', '(default)')}")
    provs = list(prof.get('providers', {}).keys())
    print(f"  • Provider    : {', '.join(provs) if provs else '(none)'}\n")

def check_live_anthropic_headers(api_key):
    """Attempt a light probe to Anthropic /v1/models to fetch ratelimit headers"""
    headers = {
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01"
    }
    req = urllib.request.Request("https://api.anthropic.com/v1/models", headers=headers)
    ctx = get_ssl_context()
    try:
        with urllib.request.urlopen(req, timeout=5, context=ctx) as resp:
            rh = dict(resp.headers)
            return {
                "status": resp.status,
                "req_rem": rh.get("anthropic-ratelimit-requests-remaining"),
                "req_lim": rh.get("anthropic-ratelimit-requests-limit"),
                "req_reset": rh.get("anthropic-ratelimit-requests-reset"),
                "tok_rem": rh.get("anthropic-ratelimit-tokens-remaining"),
                "tok_lim": rh.get("anthropic-ratelimit-tokens-limit"),
                "tok_reset": rh.get("anthropic-ratelimit-tokens-reset")
            }
    except urllib.error.HTTPError as e:
        rh = dict(e.headers)
        return {
            "status": e.code,
            "req_rem": rh.get("anthropic-ratelimit-requests-remaining"),
            "req_lim": rh.get("anthropic-ratelimit-requests-limit"),
            "req_reset": rh.get("anthropic-ratelimit-requests-reset"),
            "tok_rem": rh.get("anthropic-ratelimit-tokens-remaining"),
            "tok_lim": rh.get("anthropic-ratelimit-tokens-limit"),
            "tok_reset": rh.get("anthropic-ratelimit-tokens-reset")
        }
    except Exception:
        return None

def check_live_openrouter(api_key):
    headers = {"Authorization": f"Bearer {api_key}"}
    req = urllib.request.Request("https://openrouter.ai/api/v1/auth/key", headers=headers)
    ctx = get_ssl_context()
    try:
        with urllib.request.urlopen(req, timeout=5, context=ctx) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            return data.get("data", {})
    except Exception:
        return None

def cmd_quota(args):
    reg = load_registry()
    target_prof = None
    show_all = False

    for a in args:
        if a in ("--all", "-a"):
            show_all = True
        elif not target_prof:
            target_prof = a

    profiles_to_check = []
    if show_all:
        profiles_to_check = list(reg.get("profiles", {}).keys())
    else:
        target_prof = target_prof or reg.get("active_profile", "")
        if target_prof not in reg.get("profiles", {}):
            print(f"{RED}[ERROR] Profil '{target_prof}' tidak ditemukan.{RESET}")
            sys.exit(1)
        profiles_to_check = [target_prof]

    now_utc = datetime.datetime.now(datetime.timezone.utc)
    tomorrow_utc = (now_utc + datetime.timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    diff_midnight = tomorrow_utc - now_utc
    hours_to_midnight = diff_midnight.seconds // 3600
    mins_to_midnight = (diff_midnight.seconds % 3600) // 60

    print(f"\n{BOLD}{CYAN}========================================================================================{RESET}")
    print(f"{BOLD}                        PEMANTAUAN KUOTA & STATUS RATE LIMIT                            {RESET}")
    print(f"{BOLD}{CYAN}========================================================================================{RESET}")
    print(f"⏰ Waktu Sekarang (UTC)     : {now_utc.strftime('%Y-%m-%d %H:%M:%S UTC')}")
    print(f"⏳ Reset Kuota Harian (00:00): {YELLOW}{hours_to_midnight} jam {mins_to_midnight} menit lagi{RESET}\n")

    for p_name in profiles_to_check:
        pdata = reg["profiles"][p_name]
        is_active = (p_name == reg.get("active_profile"))
        active_badge = f"{GREEN}[AKTIF]{RESET}" if is_active else ""
        print(f"{BOLD}▶ Profil: {CYAN}{p_name}{RESET} {active_badge} ({pdata.get('description', '')})")

        provs = pdata.get("providers", {})
        if not provs:
            print(f"  {DIM}Belum ada provider yang dikonfigurasi.{RESET}\n")
            continue

        for prov_id, pinfo in provs.items():
            key = pinfo.get("apiKey", "")
            target = pinfo.get("target", "all")
            model = pinfo.get("model", "") or pdata.get("model", "")
            print(f"  • {BOLD}{prov_id.upper()}{RESET} (Target: {target}, Model: {model or 'default'}):")

            if prov_id == "google":
                print(f"    - Jendela Kuota : {GREEN}15 RPM{RESET} (Free) / {GREEN}1,000 RPM{RESET} (Tier-1)")
                print(f"    - Batas Harian  : {GREEN}1,500 RPD{RESET} (Reset tiap 00:00 UTC)")
                print(f"    - Waktu Reset   : {YELLOW}{hours_to_midnight}j {mins_to_midnight}m lagi{RESET} (Countdown 00:00 UTC)")
                print(f"    - Status        : {GREEN}[ NORMAL / SIAP ]{RESET}")

            elif prov_id == "anthropic":
                print(f"    - Jendela Kuota : {YELLOW}Jendela Rolling 5-Jam & Kuota Mingguan{RESET}")
                print(f"    - Grup Model    : {CYAN}Claude 3.7 Sonnet / Claude 3.5 Haiku{RESET}")
                if key and len(key) > 10:
                    probe = check_live_anthropic_headers(key)
                    if probe:
                        st = probe.get("status")
                        if st == 200:
                            rem = probe.get("req_rem", "Tersedia")
                            lim = probe.get("req_lim", "-")
                            print(f"    - Sisa Permintaan: {GREEN}{rem} / {lim}{RESET}")
                            print(f"    - Status Live   : {GREEN}[ OK - 200 Tersambung ]{RESET}")
                        elif st == 429:
                            print(f"    - Status Live   : {RED}[ 429 RATE LIMIT EXCEEDED ]{RESET}")
                            print(f"    - Reset Di      : {YELLOW}{probe.get('req_reset', '5 jam')}{RESET}")
                        else:
                            print(f"    - Status HTTP   : {YELLOW}Respon HTTP {st}{RESET}")
                    else:
                        print(f"    - Status Live   : {DIM}(Offline/Probe timeout){RESET}")
                else:
                    print(f"    - Status        : {DIM}(API Key belum diisi){RESET}")

            elif prov_id == "openrouter":
                if key and len(key) > 10:
                    data = check_live_openrouter(key)
                    if data:
                        lbl = data.get("label", "Key")
                        usage = data.get("usage", 0)
                        lim = data.get("limit") or "Unlimited"
                        free = data.get("is_free_tier", False)
                        print(f"    - Label Akun    : {lbl}")
                        print(f"    - Saldo / Usage : {GREEN}${usage:.4f}{RESET} / {lim} (Free: {free})")
                        print(f"    - Status Live   : {GREEN}[ AKTIF - TERVERIFIKASI ]{RESET}")
                    else:
                        print(f"    - Status Live   : {YELLOW}[ Gagal memverifikasi saldo ]{RESET}")

            else:
                print(f"    - Tipe Provider : API Key Standar")
                print(f"    - Status Key    : {GREEN}[ TERPASANG: {mask_key(key)} ]{RESET}")

        print()

    # Query antigravity-swap (aswap) for live Google OAuth quota if available
    try:
        r = subprocess.run(["aswap", "list", "--json"], capture_output=True, text=True, timeout=5)
        if r.returncode == 0 and r.stdout.strip():
            aswap_data = json.loads(r.stdout.strip())
            accs = aswap_data.get("accounts", [])
            if accs:
                print(f"{BOLD}{MAGENTA}🪐 AKUN GOOGLE ANTIGRAVITY CLI (aswap live quota):{RESET}")
                for acc in accs:
                    num = acc.get("number")
                    email = acc.get("email", "unknown")
                    alias = acc.get("alias", "")
                    alias_str = f" [{alias}]" if alias else ""
                    is_active = acc.get("active", False)
                    badge = f" {GREEN}[AKTIF]{RESET}" if is_active else ""
                    print(f"  [{num}] {BOLD}{email}{RESET}{alias_str}{badge}:")
                    usage = acc.get("usage", {})
                    for bucket_id, bdata in usage.items():
                        used_pct = bdata.get("usedPct", 0.0)
                        resets_at = bdata.get("resetsAt", "")
                        bar_color = GREEN if used_pct < 60 else (YELLOW if used_pct < 85 else RED)
                        print(f"      • {bucket_id:<12}: {bar_color}{used_pct:>5.1f}% terpakai{RESET} (Reset: {resets_at})")
                print(f"{DIM}Kelola akun agy dengan: aswap switch / aswap add / aswap watch{RESET}\n")
    except Exception:
        pass

def cmd_backup(args):
    # Syntax: backup [output_file] [--password <pwd>]
    reg = load_registry()
    out_file = None
    password = None

    idx = 0
    while idx < len(args):
        a = args[idx]
        if a in ("--password", "-p") and idx + 1 < len(args):
            password = args[idx + 1]
            idx += 2
        elif not out_file and not a.startswith("-"):
            out_file = a
            idx += 1
        else:
            idx += 1

    if not out_file:
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        out_file = os.path.join(BACKUP_DIR, f"accounts-backup-{ts}.enc")

    if not password:
        if sys.stdin.isatty():
            import getpass
            try:
                p1 = getpass.getpass("Masukkan password enkripsi AES-256 (PBKDF2): ")
                p2 = getpass.getpass("Konfirmasi password: ")
                if p1 != p2:
                    print(f"{RED}[ERROR] Password konfirmasi tidak cocok!{RESET}")
                    sys.exit(1)
                password = p1
            except Exception:
                pass

    if not password:
        password = f"termux-ai-{os.uname().machine}-{os.path.expanduser('~')}"
        print(f"{YELLOW}[WARN] Menggunakan kunci pengaman lokal internal.{RESET}")

    # Prepare snapshot payload
    snapshot = {
        "format": "termux-ai-accounts-encrypted",
        "version": 1,
        "created_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "registry": reg,
        "files": {
            "auth.json": read_json_safe(AUTH_FILE),
            "opencode.jsonc": read_json_safe(CONFIG_FILE),
            "agy_settings.json": read_json_safe(AGY_SETTINGS_FILE)
        }
    }

    raw_json = json.dumps(snapshot).encode("utf-8")
    sha256_hash = hashlib.sha256(raw_json).hexdigest()
    signed_payload = json.dumps({"hash": sha256_hash, "payload": snapshot}).encode("utf-8")

    # Encrypt using openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -md sha256
    cmd = [
        "openssl", "enc", "-aes-256-cbc", "-pbkdf2", "-iter", "100000",
        "-md", "sha256", "-pass", f"pass:{password}", "-out", out_file
    ]
    try:
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate(input=signed_payload)
        if proc.returncode != 0:
            print(f"{RED}[ERROR] Gagal mengenkripsi snapshot OpenSSL: {err.decode()}{RESET}")
            sys.exit(1)

        os.chmod(out_file, 0o600)
        print(f"\n{GREEN}[OK] Snapshot kredensial berhasil dienkripsi!{RESET}")
        print(f"📁 Lokasi berkas: {BOLD}{out_file}{RESET}")
        print(f"🔒 Enkripsi     : AES-256-CBC + PBKDF2 (100.000 iterasi) + SHA256 Checksum\n")
    except Exception as e:
        print(f"{RED}[ERROR] Eksekusi enkripsi gagal: {e}{RESET}")
        sys.exit(1)

def cmd_restore(args):
    # Syntax: restore <input_file> [--password <pwd>]
    if not args:
        print(f"{RED}[ERROR] Masukkan berkas backup terenkripsi.{RESET} Contoh: ai account restore backup.enc")
        sys.exit(1)

    in_file = None
    password = None

    idx = 0
    while idx < len(args):
        a = args[idx]
        if a in ("--password", "-p") and idx + 1 < len(args):
            password = args[idx + 1]
            idx += 2
        elif not in_file and not a.startswith("-"):
            in_file = a
            idx += 1
        else:
            idx += 1

    if not in_file or not os.path.exists(in_file):
        print(f"{RED}[ERROR] Berkas backup '{in_file}' tidak ditemukan!{RESET}")
        sys.exit(1)

    if not password:
        if sys.stdin.isatty():
            import getpass
            try:
                password = getpass.getpass("Masukkan password dekripsi: ")
            except Exception:
                pass

    if not password:
        password = f"termux-ai-{os.uname().machine}-{os.path.expanduser('~')}"

    cmd = [
        "openssl", "enc", "-d", "-aes-256-cbc", "-pbkdf2", "-iter", "100000",
        "-md", "sha256", "-pass", f"pass:{password}", "-in", in_file
    ]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        out, err = proc.communicate()
        if proc.returncode != 0:
            print(f"{RED}[ERROR] Gagal mendekripsi berkas backup (password salah atau berkas korup): {err.decode()}{RESET}")
            sys.exit(1)

        outer = json.loads(out.decode("utf-8"))
        data = outer.get("payload", {})
        expected_hash = outer.get("hash", "")
        actual_hash = hashlib.sha256(json.dumps(data).encode("utf-8")).hexdigest()
        if expected_hash and actual_hash != expected_hash:
            print(f"{RED}[ERROR] Integritas backup rusak! Hash data tidak cocok dengan checksum.{RESET}")
            sys.exit(1)

        if data.get("format") != "termux-ai-accounts-encrypted":
            print(f"{RED}[ERROR] Format arsip bukan snapshot akun termux-ai yang valid!{RESET}")
            sys.exit(1)

        restored_reg = data.get("registry", {})
        if "profiles" in restored_reg:
            curr_reg = load_registry()
            for pname, pinfo in restored_reg.get("profiles", {}).items():
                curr_reg["profiles"][pname] = pinfo
            if "rotation_pool" in restored_reg:
                curr_reg["rotation_pool"] = restored_reg["rotation_pool"]
            save_registry(curr_reg)
            sync_active_profile_to_system(curr_reg)

            print(f"\n{GREEN}[OK] Berhasil memulihkan akun dari berkas terenkripsi!{RESET}")
            print(f"• Total profil dipulihkan: {len(restored_reg.get('profiles', {}))}")
            print(f"• Profil aktif saat ini  : {BOLD}{curr_reg.get('active_profile')}{RESET}\n")
    except Exception as e:
        print(f"{RED}[ERROR] Proses restore gagal: {e}{RESET}")
        sys.exit(1)

# Dispatch CLI command
if len(sys.argv) < 2:
    cmd_list([])
    sys.exit(0)

cmd = sys.argv[1].lower()
args = sys.argv[2:]

handlers = {
    "list": cmd_list,
    "show": cmd_list,
    "current": cmd_current,
    "info": cmd_current,
    "whoami": cmd_current,
    "switch": cmd_switch,
    "use": cmd_switch,
    "add": cmd_add,
    "set-key": cmd_set_key,
    "remove": cmd_remove,
    "rm": cmd_remove,
    "pool": cmd_pool,
    "rotate": cmd_rotate,
    "quota": cmd_quota,
    "limits": cmd_quota,
    "backup": cmd_backup,
    "restore": cmd_restore
}

if cmd in handlers:
    handlers[cmd](args)
else:
    print(f"{RED}[ERROR] Perintah '{cmd}' tidak dikenali.{RESET}")
    print("Daftar perintah yang tersedia: list, current, switch, add, set-key, remove, pool, rotate, quota, backup, restore")
    sys.exit(1)
EOF
}

# ------------------------------------------------------------------------------
# Interactive Menu (TUI)
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo -e "       ${BOLD}🔐 Termux AI Tools - Multi-Account & Quota Manager${RESET}             "
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"

        run_account_engine list

        echo -e "${BOLD}Aksi yang Tersedia:${RESET}"
        echo -e "  ${GREEN}1)${RESET} Beralih Profil Akun Aktif (Switch)"
        echo -e "  ${GREEN}2)${RESET} Tambah Profil Akun Baru (Personal / Work / Testing)"
        echo -e "  ${GREEN}3)${RESET} Atur API Key & Provider pada Profil"
        echo -e "  ${CYAN}4)${RESET} Pantau Kuota & Rate Limit (5 Jam / Mingguan / Reset Time)"
        echo -e "  ${CYAN}5)${RESET} Rotasi Akun Sekarang (Pindah ke Akun Berikutnya)"
        echo -e "  ${CYAN}6)${RESET} Konfigurasi Failover Pool Rotasi Otomatis"
        echo -e "  ${YELLOW}7)${RESET} Backup Kredensial Terenkripsi (AES-256-CBC + SHA256)"
        echo -e "  ${YELLOW}8)${RESET} Restore Kredensial dari Berkas .enc"
        echo -e "  ${RED}9)${RESET} Hapus Profil Akun"
        echo -e "  ${MAGENTA}10)${RESET} Antigravity (agy) Swapper (aswap: Google OAuth, Switch agy, Quota 5h/7d)"
        echo -e "  ${DIM}0)${RESET} Kembali / Keluar"
        echo ""

        read -r -p "Pilihan Anda [0-10]: " choice
        case "$choice" in
            1)
                echo ""
                read -r -p "Masukkan nama profil tujuan: " tgt
                [ -n "$tgt" ] && run_account_engine switch "$tgt"
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            2)
                echo ""
                read -r -p "Nama profil baru (misal: personal / work / test): " pname
                read -r -p "Deskripsi singkat: " pdesc
                if [ -n "$pname" ]; then
                    run_account_engine add "$pname" "$pdesc"
                fi
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            3)
                echo ""
                read -r -p "Nama profil: " pname
                read -r -p "Provider (google/anthropic/openai/openrouter/deepseek/dll): " pprov
                read -s -r -p "API Key: " pkey
                echo ""
                read -r -p "Default Model (opsional, tekan enter untuk lewati): " pmodel
                read -r -p "Target (all/opencode/agy, default all): " ptarget
                ptarget="${ptarget:-all}"
                if [ -n "$pname" ] && [ -n "$pprov" ] && [ -n "$pkey" ]; then
                    run_account_engine set-key "$pname" "$pprov" "$pkey" "${pmodel:--}" "$ptarget"
                fi
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            4)
                echo ""
                run_account_engine quota --all
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            5)
                echo ""
                run_account_engine rotate
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            6)
                echo ""
                run_account_engine pool list
                read -r -p "Atur pool baru (format: p1,p2,p3 atau kosongkan untuk batal): " npool
                if [ -n "$npool" ]; then
                    run_account_engine pool set "$npool"
                fi
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            7)
                echo ""
                run_account_engine backup
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            8)
                echo ""
                read -r -p "Path berkas backup (.enc): " enc_path
                if [ -n "$enc_path" ]; then
                    run_account_engine restore "$enc_path"
                fi
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            9)
                echo ""
                read -r -p "Nama profil yang ingin dihapus: " del_name
                if [ -n "$del_name" ]; then
                    read -r -p "Yakin ingin menghapus profil '$del_name'? [y/N]: " cfm
                    if [[ "$cfm" =~ ^[yY]$ ]]; then
                        run_account_engine remove "$del_name"
                    fi
                fi
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            10)
                echo ""
                if ! command -v aswap >/dev/null 2>&1; then
                    echo -e "${YELLOW}[WARN] antigravity-swap (aswap) belum terpasang. Memasang...${RESET}"
                    pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
                fi
                echo -e "${BOLD}${CYAN}=== Menu Antigravity Swapper (aswap) ===${RESET}"
                echo "1) aswap list   (Lihat semua akun & kuota 5h/7d)"
                echo "2) aswap add    (Daftarkan akun agy yang sedang aktif)"
                echo "3) aswap switch (Beralih ke akun Google agy lain)"
                echo "4) aswap watch  (Monitor kuota live secara real-time)"
                echo "5) aswap auto   (Jalankan background auto-switcher)"
                echo "0) Batal"
                read -r -p "Pilihan aswap [0-5]: " aopt
                case "$aopt" in
                    1) aswap list ;;
                    2) aswap add ;;
                    3)
                        read -r -p "Nomor / Email / Alias akun: " tgt_acc
                        [ -n "$tgt_acc" ] && aswap switch "$tgt_acc"
                        ;;
                    4) aswap watch ;;
                    5) aswap auto ;;
                    *) echo "Dibatalkan." ;;
                esac
                read -r -p "Tekan Enter untuk melanjutkan..." _
                ;;
            0|q|exit)
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
# CLI Dispatcher
# ------------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    interactive_menu
else
    case "$1" in
        list|ls)
            shift
            run_account_engine list "$@"
            ;;
        current|whoami)
            shift
            run_account_engine current "$@"
            ;;
        switch|use)
            shift
            run_account_engine switch "$@"
            ;;
        add)
            shift
            run_account_engine add "$@"
            ;;
        set-key)
            shift
            run_account_engine set-key "$@"
            ;;
        remove|rm|del)
            shift
            run_account_engine remove "$@"
            ;;
        pool)
            shift
            run_account_engine pool "$@"
            ;;
        rotate)
            shift
            run_account_engine rotate "$@"
            ;;
        quota|limits)
            shift
            run_account_engine quota "$@"
            ;;
        backup)
            shift
            run_account_engine backup "$@"
            ;;
        restore)
            shift
            run_account_engine restore "$@"
            ;;
        aswap|swap)
            shift
            if ! command -v aswap >/dev/null 2>&1; then
                pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            fi
            exec aswap "$@"
            ;;
        agy-add)
            shift
            if ! command -v aswap >/dev/null 2>&1; then
                pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            fi
            exec aswap add "$@"
            ;;
        agy-switch)
            shift
            if ! command -v aswap >/dev/null 2>&1; then
                pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            fi
            exec aswap switch "$@"
            ;;
        agy-list|agy-ls)
            shift
            if ! command -v aswap >/dev/null 2>&1; then
                pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            fi
            exec aswap list "$@"
            ;;
        agy-watch)
            shift
            if ! command -v aswap >/dev/null 2>&1; then
                pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            fi
            exec aswap watch "$@"
            ;;
        agy-auto)
            shift
            if ! command -v aswap >/dev/null 2>&1; then
                pip install --upgrade "antigravity-swap @ git+https://github.com/ngewa/antigravity-swap.git"
            fi
            exec aswap auto "$@"
            ;;
        help|--help|-h)
            echo -e "${BOLD}${CYAN}Termux AI Tools - Multi-Account & Quota Manager${RESET}"
            echo "Penggunaan:"
            echo "  ai account                           Buka menu interaktif TUI"
            echo "  ai account list                      Daftar semua profil & pool rotasi"
            echo "  ai account current                   Detail profil aktif saat ini"
            echo "  ai account switch <nama>             Ganti akun aktif secara instan"
            echo "  ai account add <nama> [deskripsi]    Daftarkan profil baru"
            echo "  ai account set-key <p> <prov> <key>  Simpan API key ke profil"
            echo "  ai account remove <nama>             Hapus profil dari registry"
            echo "  ai account quota [--all]             Pantau kuota 5h, mingguan, & reset"
            echo "  ai account rotate                    Putar ke akun berikutnya di pool"
            echo "  ai account pool [set p1,p2,p3]       Kelola daftar rotasi failover"
            echo "  ai account backup [file.enc]         Snapshot terenkripsi PBKDF2 AES-256"
            echo "  ai account restore <file.enc>        Pulihkan snapshot dari berkas"
            echo "  ai account aswap [args...]           Proxy langsung ke antigravity-swap (aswap)"
            echo "  ai account agy-add [alias]           Daftarkan akun agy aktif ke aswap"
            echo "  ai account agy-switch <acc>          Beralih akun Google agy via aswap"
            echo "  ai account agy-watch                 Live quota table Antigravity CLI"
            echo "  ai account agy-auto                  Jalankan background auto-switcher agy"
            exit 0
            ;;
        *)
            run_account_engine "$@"
            ;;
    esac
fi

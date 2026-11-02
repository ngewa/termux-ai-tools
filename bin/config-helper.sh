#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Interactive API Key & Provider Setup Wizard
# Manages:
#   - ~/.local/share/opencode/auth.json (API keys per provider & targets)
#   - ~/.config/opencode/opencode.jsonc (Default model & custom provider options)
#   - ~/.gemini/antigravity-cli/settings.json (Antigravity CLI model & providers)
#   - ~/.termux_ai_env (Exported shell environment variables)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
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

# Ensure python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    log_err "Python3 diperlukan untuk mengelola konfigurasi JSON dengan aman."
    echo "Jalankan: pkg install python"
    exit 1
fi

# Ensure parent dirs exist
mkdir -p "$HOME_DIR/.local/share/opencode"
mkdir -p "$HOME_DIR/.config/opencode"
mkdir -p "$HOME_DIR/.gemini/antigravity-cli"

# ------------------------------------------------------------------------------
# Python Helper Core
# ------------------------------------------------------------------------------
run_python_helper() {
    python3 - "$@" << 'EOF'
import sys, os, json, urllib.request, urllib.error, ssl

HOME = os.path.expanduser("~")
AUTH_PATH = os.path.join(HOME, ".local/share/opencode/auth.json")
CONFIG_PATH = os.path.join(HOME, ".config/opencode/opencode.jsonc")
AGY_SETTINGS_PATH = os.path.join(HOME, ".gemini/antigravity-cli/settings.json")
ENV_PATH = os.path.join(HOME, ".termux_ai_env")

KNOWN_PROVIDERS = {
    "google": {
        "name": "Google Gemini",
        "url": "https://aistudio.google.com/app/apikey",
        "env_var": "GEMINI_API_KEY",
        "base_url": "https://generativelanguage.googleapis.com/v1beta",
        "default_models": ["google/gemini-2.5-flash", "google/gemini-2.5-pro", "google/gemini-2.0-flash"],
        "default_mode": "auto",
        "test_url": "https://generativelanguage.googleapis.com/v1beta/models?key={key}",
        "test_headers": {}
    },
    "anthropic": {
        "name": "Anthropic Claude",
        "url": "https://console.anthropic.com/settings/keys",
        "env_var": "ANTHROPIC_API_KEY",
        "base_url": "https://api.anthropic.com/v1",
        "default_models": ["anthropic/claude-3-7-sonnet", "anthropic/claude-3-5-sonnet", "anthropic/claude-3-5-haiku"],
        "default_mode": "auto",
        "test_url": "https://api.anthropic.com/v1/models",
        "test_headers": {"x-api-key": "{key}", "anthropic-version": "2023-06-01"}
    },
    "openai": {
        "name": "OpenAI",
        "url": "https://platform.openai.com/api-keys",
        "env_var": "OPENAI_API_KEY",
        "base_url": "https://api.openai.com/v1",
        "default_models": ["openai/gpt-4.5-preview", "openai/gpt-4o", "openai/gpt-4o-mini", "openai/o3-mini"],
        "default_mode": "auto",
        "test_url": "https://api.openai.com/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "deepseek": {
        "name": "DeepSeek",
        "url": "https://platform.deepseek.com/api_keys",
        "env_var": "DEEPSEEK_API_KEY",
        "base_url": "https://api.deepseek.com/v1",
        "default_models": ["deepseek/deepseek-chat", "deepseek/deepseek-reasoner"],
        "default_mode": "chat_completions",
        "test_url": "https://api.deepseek.com/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "openrouter": {
        "name": "OpenRouter",
        "url": "https://openrouter.ai/keys",
        "env_var": "OPENROUTER_API_KEY",
        "base_url": "https://openrouter.ai/api/v1",
        "default_models": ["openrouter/auto", "openrouter/anthropic/claude-3.7-sonnet", "openrouter/deepseek/deepseek-r1"],
        "default_mode": "chat_completions",
        "test_url": "https://openrouter.ai/api/v1/auth/key",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "groq": {
        "name": "Groq",
        "url": "https://console.groq.com/keys",
        "env_var": "GROQ_API_KEY",
        "base_url": "https://api.groq.com/openai/v1",
        "default_models": ["groq/llama-3.3-70b-versatile", "groq/deepseek-r1-distill-llama-70b"],
        "default_mode": "chat_completions",
        "test_url": "https://api.groq.com/openai/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "mistral": {
        "name": "Mistral AI",
        "url": "https://console.mistral.ai/api-keys/",
        "env_var": "MISTRAL_API_KEY",
        "base_url": "https://api.mistral.ai/v1",
        "default_models": ["mistral/mistral-large-latest", "mistral/codestral-latest"],
        "default_mode": "chat_completions",
        "test_url": "https://api.mistral.ai/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "xai": {
        "name": "xAI (Grok)",
        "url": "https://console.x.ai/",
        "env_var": "XAI_API_KEY",
        "base_url": "https://api.x.ai/v1",
        "default_models": ["xai/grok-2-latest", "xai/grok-beta"],
        "default_mode": "chat_completions",
        "test_url": "https://api.x.ai/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "bynara": {
        "name": "NaraRouter",
        "url": "https://router.bynara.id",
        "env_var": "BYNARA_API_KEY",
        "base_url": "https://router.bynara.id/v1",
        "default_models": ["bynara/glm-5.3-flash", "bynara/glm-4.7", "bynara/claude-3-7-sonnet"],
        "default_mode": "chat_completions",
        "test_url": "https://router.bynara.id/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    }
}

API_MODES = {
    "auto": {
        "label": "Automatic",
        "desc": "Use the provider and model defaults"
    },
    "chat_completions": {
        "label": "Chat Completions",
        "desc": "Use /chat/completions for broad OpenAI-compatible support"
    },
    "responses": {
        "label": "Responses",
        "desc": "Use /responses for providers that support the Responses API"
    },
    "responses_compat": {
        "label": "Responses (Compat)",
        "desc": "Use /responses with legacy text chunks for strict gateways"
    }
}

TARGET_TOOLS = {
    "all": "Universal (v1/v2/agy)",
    "opencode": "OpenCode (v1 & v2)",
    "agy": "Antigravity (agy)"
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

def load_auth():
    if os.path.exists(AUTH_PATH):
        try:
            with open(AUTH_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_auth(data):
    os.makedirs(os.path.dirname(AUTH_PATH), exist_ok=True)
    if os.path.exists(AUTH_PATH):
        try:
            with open(AUTH_PATH + ".bak", 'w', encoding='utf-8') as bak:
                with open(AUTH_PATH, 'r', encoding='utf-8') as src:
                    bak.write(src.read())
        except Exception:
            pass
    with open(AUTH_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)
    os.chmod(AUTH_PATH, 0o600)

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, 'r', encoding='utf-8') as f:
                return json.loads(strip_jsonc_comments(f.read()))
        except Exception:
            return {}
    return {}

def save_config(data):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    if "$schema" not in data:
        data["$schema"] = "https://opencode.ai/config.json"
    
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH + ".bak", 'w', encoding='utf-8') as bak:
                with open(CONFIG_PATH, 'r', encoding='utf-8') as src:
                    bak.write(src.read())
        except Exception:
            pass
    with open(CONFIG_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

def load_agy_settings():
    if os.path.exists(AGY_SETTINGS_PATH):
        try:
            with open(AGY_SETTINGS_PATH, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            return {}
    return {}

def save_agy_settings(data):
    os.makedirs(os.path.dirname(AGY_SETTINGS_PATH), exist_ok=True)
    if os.path.exists(AGY_SETTINGS_PATH):
        try:
            with open(AGY_SETTINGS_PATH + ".bak", 'w', encoding='utf-8') as bak:
                with open(AGY_SETTINGS_PATH, 'r', encoding='utf-8') as src:
                    bak.write(src.read())
        except Exception:
            pass
    with open(AGY_SETTINGS_PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2)

def save_config_model(model_name):
    data = load_config()
    data["model"] = model_name
    save_config(data)

def save_agy_model(model_name):
    data = load_agy_settings()
    data["model"] = model_name
    save_agy_settings(data)

def is_provider_disabled(pid, config_data, auth_data):
    dis_list = config_data.get("disabled_providers", [])
    if pid in dis_list:
        return True
    entry = auth_data.get(pid, {})
    if entry.get("disabled") is True:
        return True
    return False

def set_provider_disabled(pid, disabled=True):
    config_data = load_config()
    auth_data = load_auth()
    dis_list = list(config_data.get("disabled_providers", []))

    if disabled:
        if pid not in dis_list:
            dis_list.append(pid)
        config_data["disabled_providers"] = dis_list
        if pid in auth_data:
            auth_data[pid]["disabled"] = True
    else:
        if pid in dis_list:
            dis_list = [x for x in dis_list if x != pid]
        if dis_list:
            config_data["disabled_providers"] = dis_list
        else:
            config_data.pop("disabled_providers", None)
        if pid in auth_data:
            auth_data[pid].pop("disabled", None)

    save_config(config_data)
    if pid in auth_data:
        save_auth(auth_data)

def mask_key(key):
    if not key:
        return ""
    if len(key) <= 12:
        return key[:3] + "..." + key[-2:]
    return key[:8] + "..." + key[-4:]

def get_provider_details(pid, auth_data, config_data, agy_data):
    auth_entry = auth_data.get(pid, {})
    cfg_provider = config_data.get("provider", {}).get(pid, {}) if isinstance(config_data.get("provider"), dict) else {}
    cfg_options = cfg_provider.get("options", {}) if isinstance(cfg_provider, dict) else {}
    agy_providers = agy_data.get("providers", {}) if isinstance(agy_data.get("providers"), dict) else {}
    agy_provider = agy_providers.get(pid, {}) if isinstance(agy_providers, dict) else {}

    # Key
    key = auth_entry.get("key") or cfg_options.get("apiKey") or agy_provider.get("apiKey") or ""

    # Target
    target = auth_entry.get("target") or ""
    if not target:
        has_oc = bool(pid in auth_data or pid in config_data.get("provider", {}))
        has_agy = bool(pid in agy_providers)
        if has_oc and has_agy:
            target = "all"
        elif has_agy:
            target = "agy"
        elif has_oc:
            target = "opencode"
        else:
            target = "all"

    # Base URL
    base_url = auth_entry.get("baseURL") or cfg_options.get("baseURL") or agy_provider.get("baseURL") or KNOWN_PROVIDERS.get(pid, {}).get("base_url", "")

    # Default model
    model = auth_entry.get("model") or agy_provider.get("model") or ""
    if not model and isinstance(cfg_provider.get("models"), dict) and cfg_provider["models"]:
        model = list(cfg_provider["models"].keys())[0]
    if not model and pid in KNOWN_PROVIDERS and KNOWN_PROVIDERS[pid].get("default_models"):
        model = KNOWN_PROVIDERS[pid]["default_models"][0]

    # API Mode
    api_mode = auth_entry.get("apiMode") or cfg_options.get("apiMode") or agy_provider.get("apiMode") or KNOWN_PROVIDERS.get(pid, {}).get("default_mode", "auto")
    if api_mode not in API_MODES:
        api_mode = "auto"

    # Name
    name = KNOWN_PROVIDERS.get(pid, {}).get("name") or cfg_provider.get("name") or pid.capitalize()

    return {
        "id": pid,
        "name": name,
        "key": key,
        "target": target,
        "base_url": base_url,
        "model": model,
        "api_mode": api_mode
    }

# ------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------
cmd = sys.argv[1] if len(sys.argv) > 1 else "list"

if cmd in ("list", "status"):
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    current_model = config_data.get("model", "(Belum diatur / default bawaan)")
    current_agy_model = agy_data.get("model", "Gemini 3.8 Flash (Medium)")

    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                       DAFTAR PROVIDER & STATUS API KEY TERPASANG                       \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m")
    print(f"\033[1m🎯 Model OpenCode (v1 & v2):\033[0m \033[32m{current_model}\033[0m")
    print(f"\033[1m🎯 Model Antigravity (agy) :\033[0m \033[35m{current_agy_model}\033[0m\n")
    print(f"{'PROVIDER':<12} {'NAMA':<18} {'STATUS':<12} {'TARGET':<12} {'API MODE':<16} {'API KEY (MASKED)':<18}")
    print("-" * 90)

    def format_status(is_dis, has_k):
        if is_dis:
            return "\033[31m[ NONAKTIF ]\033[0m"
        elif has_k:
            return "\033[32m[ AKTIF ]   \033[0m"
        else:
            return "\033[33m[ BELUM ]   \033[0m"

    # Collect unique list of all providers
    all_pids = list(KNOWN_PROVIDERS.keys())
    custom_sources = (
        set(auth_data.keys()) |
        set(config_data.get("provider", {}).keys() if isinstance(config_data.get("provider"), dict) else []) |
        set(agy_data.get("providers", {}).keys() if isinstance(agy_data.get("providers"), dict) else []) |
        set(config_data.get("disabled_providers", []))
    )
    for p in sorted(custom_sources):
        if p not in all_pids:
            all_pids.append(p)

    custom_details = []
    for pid in all_pids:
        details = get_provider_details(pid, auth_data, config_data, agy_data)
        has_key = bool(details["key"])
        is_dis = is_provider_disabled(pid, config_data, auth_data)
        st_str = format_status(is_dis, has_key)

        if not has_key and not is_dis and pid in KNOWN_PROVIDERS:
            tgt_display = "-"
            mode_display = "-"
        else:
            tgt_display = "Universal" if details["target"] == "all" else ("OpenCode" if details["target"] == "opencode" else "AGY")
            mode_lbl = API_MODES.get(details["api_mode"], {}).get("label", details["api_mode"])
            if details["api_mode"] == "chat_completions":
                mode_display = "Chat Compl."
            elif details["api_mode"] == "responses_compat":
                mode_display = "Resp (Compat)"
            else:
                mode_display = mode_lbl

        masked = mask_key(details["key"]) if has_key else "-"
        name_str = details["name"] if pid in KNOWN_PROVIDERS else f"{details['name']} (Custom)"
        print(f"{pid:<12} {name_str[:17]:<18} {st_str} {tgt_display:<12} {mode_display:<16} {masked:<18}")

        if has_key or is_dis or pid not in KNOWN_PROVIDERS:
            base_show = details["base_url"] or "(bawaan provider)"
            mod_show = details["model"] or "(bawaan provider)"
            mode_full = API_MODES.get(details["api_mode"], {}).get("label", details["api_mode"])
            custom_details.append(f"  • \033[1m{pid:<10}\033[0m: Target=\033[36m{tgt_display}\033[0m | BaseURL=\033[33m{base_show}\033[0m | Model=\033[32m{mod_show}\033[0m | Mode=\033[35m{mode_full}\033[0m")

    print("-" * 90)
    if custom_details:
        print("\n\033[1m🌐 Detail Konfigurasi Endpoint & Parameter Provider:\033[0m")
        for cd in custom_details:
            print(cd)

elif cmd == "get":
    if len(sys.argv) < 3:
        print("Usage: get <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)
    if details["key"]:
        m = mask_key(details["key"])
        if is_provider_disabled(provider, config_data, auth_data):
            print(f"{m} (NONAKTIF)")
        else:
            print(m)
    else:
        print("")

elif cmd == "info":
    if len(sys.argv) < 3:
        print("Usage: info <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)
    is_dis = is_provider_disabled(provider, config_data, auth_data)
    status_str = "NONAKTIF" if is_dis else ("AKTIF" if details["key"] else "BELUM_DIATUR")
    mode_info = API_MODES.get(details["api_mode"], {"label": details["api_mode"], "desc": ""})
    target_name = TARGET_TOOLS.get(details["target"], details["target"])

    print(f"ID:{details['id']}")
    print(f"NAMA:{details['name']}")
    print(f"STATUS:{status_str}")
    print(f"TARGET:{details['target']}:{target_name}")
    print(f"BASE_URL:{details['base_url']}")
    print(f"MODEL:{details['model']}")
    print(f"API_MODE:{details['api_mode']}:{mode_info['label']}")
    print(f"API_KEY:{mask_key(details['key'])}")

elif cmd == "set":
    # Arguments:
    # 2: provider
    # 3: key
    # 4: target (optional: all, opencode, agy; default: all)
    # 5: baseURL (optional)
    # 6: model (optional)
    # 7: apiMode (optional: auto, chat_completions, responses, responses_compat; default: auto)
    if len(sys.argv) < 4:
        print("Usage: set <provider> <key> [target] [baseURL] [model] [apiMode]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    key = sys.argv[3].strip()
    if not key:
        print("Error: API Key tidak boleh kosong.")
        sys.exit(1)

    target = sys.argv[4].lower() if len(sys.argv) > 4 and sys.argv[4].strip() else "all"
    if target not in TARGET_TOOLS:
        target = "all"

    base_url = sys.argv[5].strip() if len(sys.argv) > 5 else ""
    if not base_url and provider in KNOWN_PROVIDERS:
        base_url = KNOWN_PROVIDERS[provider].get("base_url", "")

    model = sys.argv[6].strip() if len(sys.argv) > 6 else ""
    if not model and provider in KNOWN_PROVIDERS and KNOWN_PROVIDERS[provider].get("default_models"):
        model = KNOWN_PROVIDERS[provider]["default_models"][0]

    api_mode = sys.argv[7].lower() if len(sys.argv) > 7 and sys.argv[7].strip() else ""
    if not api_mode or api_mode not in API_MODES:
        api_mode = KNOWN_PROVIDERS.get(provider, {}).get("default_mode", "auto")

    # 1. Update auth.json
    auth_data = load_auth()
    auth_entry = auth_data.get(provider, {})
    auth_entry["type"] = "api"
    auth_entry["key"] = key
    auth_entry["target"] = target
    auth_entry["baseURL"] = base_url
    auth_entry["model"] = model
    auth_entry["apiMode"] = api_mode
    auth_entry.pop("disabled", None)
    auth_data[provider] = auth_entry
    save_auth(auth_data)

    # 2. Update opencode.jsonc if target is all or opencode
    config_data = load_config()
    if target in ("all", "opencode"):
        providers_dict = config_data.get("provider", {})
        if not isinstance(providers_dict, dict):
            providers_dict = {}
        prov_item = providers_dict.get(provider, {})
        prov_name = KNOWN_PROVIDERS.get(provider, {}).get("name") or prov_item.get("name") or provider.capitalize()
        prov_item["name"] = prov_name
        prov_item["npm"] = "@ai-sdk/openai-compatible"
        prov_options = prov_item.get("options", {})
        prov_options["baseURL"] = base_url
        prov_options["apiKey"] = key
        prov_options["apiMode"] = api_mode
        prov_item["options"] = prov_options
        if model:
            models_dict = prov_item.get("models", {})
            if not isinstance(models_dict, dict):
                models_dict = {}
            short_model = model.split("/", 1)[-1] if "/" in model else model
            models_dict[short_model] = {"name": short_model}
            prov_item["models"] = models_dict
        providers_dict[provider] = prov_item
        config_data["provider"] = providers_dict

    # 3. Update agy settings if target is all or agy
    agy_data = load_agy_settings()
    if target in ("all", "agy"):
        agy_providers = agy_data.get("providers", {})
        if not isinstance(agy_providers, dict):
            agy_providers = {}
        agy_entry = agy_providers.get(provider, {})
        agy_entry["apiKey"] = key
        agy_entry["baseURL"] = base_url
        agy_entry["model"] = model
        agy_entry["apiMode"] = api_mode
        agy_providers[provider] = agy_entry
        agy_data["providers"] = agy_providers
        save_agy_settings(agy_data)

    # 4. Enable provider
    set_provider_disabled(provider, disabled=False)
    save_config(config_data)

    print(f"OK:{mask_key(key)}:{target}:{api_mode}")

elif cmd == "configured-list":
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    configured = []
    all_pids = list(KNOWN_PROVIDERS.keys())
    custom_sources = (
        set(auth_data.keys()) |
        set(config_data.get("provider", {}).keys() if isinstance(config_data.get("provider"), dict) else []) |
        set(agy_data.get("providers", {}).keys() if isinstance(agy_data.get("providers"), dict) else [])
    )
    for p in sorted(custom_sources):
        if p not in all_pids:
            all_pids.append(p)
    for pid in all_pids:
        details = get_provider_details(pid, auth_data, config_data, agy_data)
        has_k = bool(details["key"])
        has_cfg = (isinstance(config_data.get("provider"), dict) and pid in config_data["provider"]) or (isinstance(agy_data.get("providers"), dict) and pid in agy_data["providers"])
        if has_k or has_cfg:
            mode_lbl = API_MODES.get(details["api_mode"], {}).get("label", details["api_mode"])
            configured.append(f"{pid}|{details['name']}|{details['target']}|{mode_lbl}|{details['model']}|{details['base_url']}")
    print("\n".join(configured))

elif cmd == "edit":
    # Usage: edit <provider> [target] [baseURL] [model] [apiMode] [key]
    if len(sys.argv) < 3:
        print("Usage: edit <provider> [target] [baseURL] [model] [apiMode] [key]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)

    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() and sys.argv[3].strip() != "__KEEP__" else details["target"]
    if target not in TARGET_TOOLS:
        target = details["target"] or "all"

    base_url = sys.argv[4].strip() if len(sys.argv) > 4 and sys.argv[4].strip() != "__KEEP__" else details["base_url"]
    model = sys.argv[5].strip() if len(sys.argv) > 5 and sys.argv[5].strip() != "__KEEP__" else details["model"]
    api_mode = sys.argv[6].lower() if len(sys.argv) > 6 and sys.argv[6].strip() and sys.argv[6].strip() != "__KEEP__" else details["api_mode"]
    if api_mode not in API_MODES:
        api_mode = details["api_mode"] or "auto"

    key = sys.argv[7].strip() if len(sys.argv) > 7 and sys.argv[7].strip() != "__KEEP__" else details["key"]

    # 1. Update auth.json
    auth_entry = auth_data.get(provider, {})
    auth_entry["type"] = "api"
    auth_entry["key"] = key
    auth_entry["target"] = target
    auth_entry["baseURL"] = base_url
    auth_entry["model"] = model
    auth_entry["apiMode"] = api_mode
    auth_data[provider] = auth_entry
    save_auth(auth_data)

    # 2. Update opencode.jsonc
    if target in ("all", "opencode"):
        providers_dict = config_data.get("provider", {})
        if not isinstance(providers_dict, dict):
            providers_dict = {}
        prov_item = providers_dict.get(provider, {})
        prov_name = KNOWN_PROVIDERS.get(provider, {}).get("name") or prov_item.get("name") or provider.capitalize()
        prov_item["name"] = prov_name
        prov_item["npm"] = "@ai-sdk/openai-compatible"
        prov_options = prov_item.get("options", {})
        prov_options["baseURL"] = base_url
        prov_options["apiKey"] = key
        prov_options["apiMode"] = api_mode
        prov_item["options"] = prov_options
        if model:
            models_dict = prov_item.get("models", {})
            if not isinstance(models_dict, dict):
                models_dict = {}
            short_model = model.split("/", 1)[-1] if "/" in model else model
            models_dict[short_model] = {"name": short_model}
            prov_item["models"] = models_dict
        providers_dict[provider] = prov_item
        config_data["provider"] = providers_dict
    elif target == "agy":
        if isinstance(config_data.get("provider"), dict) and provider in config_data["provider"] and provider not in KNOWN_PROVIDERS:
            del config_data["provider"][provider]
    save_config(config_data)

    # 3. Update agy settings.json
    if target in ("all", "agy"):
        agy_providers = agy_data.get("providers", {})
        if not isinstance(agy_providers, dict):
            agy_providers = {}
        agy_entry = agy_providers.get(provider, {})
        agy_entry["apiKey"] = key
        agy_entry["baseURL"] = base_url
        agy_entry["model"] = model
        agy_entry["apiMode"] = api_mode
        agy_providers[provider] = agy_entry
        agy_data["providers"] = agy_providers
        save_agy_settings(agy_data)
    elif target == "opencode":
        if isinstance(agy_data.get("providers"), dict) and provider in agy_data["providers"]:
            del agy_data["providers"][provider]
            save_agy_settings(agy_data)

    print(f"OK_EDIT:{mask_key(key)}:{target}:{api_mode}:{model}:{base_url}")

elif cmd in ("del", "remove", "rm"):
    if len(sys.argv) < 3:
        print("Usage: remove <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    found = False

    # Remove from auth.json
    auth_data = load_auth()
    if provider in auth_data:
        del auth_data[provider]
        save_auth(auth_data)
        found = True

    # Remove from opencode.jsonc
    config_data = load_config()
    dis_list = config_data.get("disabled_providers", [])
    if provider in dis_list:
        dis_list = [x for x in dis_list if x != provider]
        if dis_list:
            config_data["disabled_providers"] = dis_list
        else:
            config_data.pop("disabled_providers", None)
        found = True
    if isinstance(config_data.get("provider"), dict) and provider in config_data["provider"]:
        del config_data["provider"][provider]
        found = True
    save_config(config_data)

    # Remove from agy settings.json
    agy_data = load_agy_settings()
    if isinstance(agy_data.get("providers"), dict) and provider in agy_data["providers"]:
        del agy_data["providers"][provider]
        save_agy_settings(agy_data)
        found = True

    if found:
        print(f"DELETED:{provider}")
    else:
        print(f"NOT_FOUND:{provider}")

elif cmd == "enable":
    if len(sys.argv) < 3:
        print("Usage: enable <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    config_data = load_config()
    auth_data = load_auth()
    if not is_provider_disabled(provider, config_data, auth_data):
        print(f"ALREADY_ENABLED:{provider}")
    else:
        set_provider_disabled(provider, disabled=False)
        print(f"ENABLED:{provider}")

elif cmd == "disable":
    if len(sys.argv) < 3:
        print("Usage: disable <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    config_data = load_config()
    auth_data = load_auth()
    if is_provider_disabled(provider, config_data, auth_data):
        print(f"ALREADY_DISABLED:{provider}")
    else:
        set_provider_disabled(provider, disabled=True)
        print(f"DISABLED:{provider}")

elif cmd == "toggle":
    if len(sys.argv) < 3:
        print("Usage: toggle <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    config_data = load_config()
    auth_data = load_auth()
    if is_provider_disabled(provider, config_data, auth_data):
        set_provider_disabled(provider, disabled=False)
        print(f"ENABLED:{provider}")
    else:
        set_provider_disabled(provider, disabled=True)
        print(f"DISABLED:{provider}")

elif cmd == "is_disabled":
    if len(sys.argv) < 3:
        print("0")
        sys.exit(0)
    provider = sys.argv[2].lower()
    config_data = load_config()
    auth_data = load_auth()
    print("1" if is_provider_disabled(provider, config_data, auth_data) else "0")

elif cmd == "model":
    if len(sys.argv) >= 3:
        model_name = sys.argv[2].strip()
        save_config_model(model_name)
        print(f"MODEL_SAVED:{model_name}")
    else:
        config_data = load_config()
        print(config_data.get("model", ""))

elif cmd == "model-agy":
    if len(sys.argv) >= 3:
        model_name = sys.argv[2].strip()
        save_agy_model(model_name)
        print(f"AGY_MODEL_SAVED:{model_name}")
    else:
        agy_data = load_agy_settings()
        print(agy_data.get("model", "Gemini 3.8 Flash (Medium)"))

elif cmd == "sync-env":
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    lines = [
        "# ==============================================================================",
        "# Auto-generated environment variables by Termux AI Tools (config.sh)",
        "# Source this file in your ~/.bashrc: [ -f ~/.termux_ai_env ] && . ~/.termux_ai_env",
        "# =============================================================================="
    ]
    count = 0
    all_pids = set(auth_data.keys()) | set(config_data.get("provider", {}).keys() if isinstance(config_data.get("provider"), dict) else [])
    for pid in sorted(all_pids):
        details = get_provider_details(pid, auth_data, config_data, agy_data)
        k = details["key"]
        if not k:
            continue
        env_var = KNOWN_PROVIDERS.get(pid, {}).get("env_var", f"{pid.upper()}_API_KEY")
        base_url = details["base_url"]
        mode = details["api_mode"]
        model = details["model"]
        is_dis = is_provider_disabled(pid, config_data, auth_data)

        if is_dis:
            lines.append(f"# export {env_var}=\"{k}\" # (STATUS: NONAKTIF)")
            continue

        lines.append(f"export {env_var}=\"{k}\"")
        if base_url:
            lines.append(f"export {pid.upper()}_BASE_URL=\"{base_url}\"")
        if mode:
            lines.append(f"export {pid.upper()}_API_MODE=\"{mode}\"")
        if model:
            lines.append(f"export {pid.upper()}_MODEL=\"{model}\"")

        # Specific compatibility aliases
        if pid == "google":
            lines.append(f"export GOOGLE_API_KEY=\"{k}\"")
        elif pid == "openai":
            if base_url:
                lines.append(f"export OPENAI_BASE_URL=\"{base_url}\"")
                lines.append(f"export OPENAI_API_BASE=\"{base_url}\"")
        elif pid == "anthropic":
            if base_url:
                lines.append(f"export ANTHROPIC_BASE_URL=\"{base_url}\"")
        count += 1

    with open(ENV_PATH, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(ENV_PATH, 0o600)
    print(f"SYNC_COUNT:{count}")

elif cmd == "test":
    target = sys.argv[2].lower() if len(sys.argv) > 2 else "all"
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()

    def test_provider(pid):
        details = get_provider_details(pid, auth_data, config_data, agy_data)
        key = details["key"]
        if not key:
            return "SKIPPED: Belum ada API key terpasang"

        if is_provider_disabled(pid, config_data, auth_data):
            return "DISABLED: Provider dinonaktifkan (Gunakan 'enable' untuk mengaktifkan)"

        info = KNOWN_PROVIDERS.get(pid)
        test_url = info.get("test_url") if info else None
        headers = dict(info.get("test_headers", {})) if info else {}

        # If custom base_url exists for OpenAI-compatible
        if not test_url and details["base_url"]:
            test_url = details["base_url"].rstrip("/") + "/models"
            headers["Authorization"] = "Bearer {key}"
        elif not test_url:
            return "UNSUPPORTED: Pengujian otomatis belum tersedia untuk provider ini"

        url = test_url.format(key=key)
        final_headers = {k: v.format(key=key) for k, v in headers.items()}
        final_headers["User-Agent"] = "TermuxAITools/1.0"

        try:
            req = urllib.request.Request(url, headers=final_headers)
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, timeout=7, context=ctx) as resp:
                if resp.status in (200, 204):
                    return "SUCCESS: 200 OK (Koneksi & API Key Valid)"
                return f"RESPONSE: {resp.status}"
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):
                return f"FAILED: {e.code} Unauthorized (API Key salah / tidak valid)"
            return f"HTTP_ERR: {e.code} ({e.reason})"
        except urllib.error.URLError as e:
            return f"NET_ERR: {e.reason}"
        except Exception as e:
            return f"ERR: {e}"

    if target == "all":
        for pid in KNOWN_PROVIDERS:
            res = test_provider(pid)
            if not res.startswith("SKIPPED"):
                print(f"{pid}:{res}")
    else:
        res = test_provider(target)
        print(f"{target}:{res}")

EOF
}

# ------------------------------------------------------------------------------
# Interactive Menu Wizard
# ------------------------------------------------------------------------------
edit_provider_menu() {
    local p_id="$1"
    while true; do
        clear 2>/dev/null || true
        local p_info
        p_info=$(run_python_helper "info" "$p_id")

        local cur_name cur_status cur_target cur_target_name cur_base cur_model cur_mode cur_mode_name cur_key
        cur_name=$(echo "$p_info" | grep "^NAMA:" | cut -d':' -f2-)
        cur_status=$(echo "$p_info" | grep "^STATUS:" | cut -d':' -f2-)
        cur_target=$(echo "$p_info" | grep "^TARGET:" | cut -d':' -f2)
        cur_target_name=$(echo "$p_info" | grep "^TARGET:" | cut -d':' -f3)
        cur_base=$(echo "$p_info" | grep "^BASE_URL:" | cut -d':' -f2-)
        cur_model=$(echo "$p_info" | grep "^MODEL:" | cut -d':' -f2-)
        cur_mode=$(echo "$p_info" | grep "^API_MODE:" | cut -d':' -f2)
        cur_mode_name=$(echo "$p_info" | grep "^API_MODE:" | cut -d':' -f3)
        cur_key=$(echo "$p_info" | grep "^API_KEY:" | cut -d':' -f2-)

        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo -e "${BOLD}         ✏️  EDIT KONFIGURASI PROVIDER: ${p_id} (${cur_name:-$p_id})          ${RESET}"
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo -e "  • Status Provider : ${GREEN}${cur_status}${RESET}"
        echo -e "  • Target Integrasi: ${CYAN}${cur_target_name:-Universal}${RESET} (${cur_target:-all})"
        echo -e "  • Base URL        : ${YELLOW}${cur_base:-(default bawaan)}${RESET}"
        echo -e "  • Default Model   : ${GREEN}${cur_model:-(default bawaan)}${RESET}"
        echo -e "  • API Mode        : ${MAGENTA}${cur_mode_name:-Automatic} (${cur_mode:-auto})${RESET}"
        echo -e "  • Masked API Key  : ${GREEN}${cur_key:-(belum ada)}${RESET}"
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo ""
        echo -e "${BOLD}Pilih Bagian yang Ingin Diubah:${RESET}"
        echo -e "  ${CYAN}1)${RESET} Ubah Target Integrasi (OpenCode v1/v2 / Antigravity agy / Universal)"
        echo -e "  ${YELLOW}2)${RESET} Ubah Base URL Endpoint"
        echo -e "  ${GREEN}3)${RESET} Ubah Default Model"
        echo -e "  ${MAGENTA}4)${RESET} Ubah API Mode (Automatic / Chat Completions / Responses / Compat)"
        echo -e "  ${GREEN}5)${RESET} Ganti API Key"
        echo -e "  ${BOLD}${CYAN}6)${RESET} 🔄 Edit Seluruh Konfigurasi (Wizard Lengkap)"
        echo -e "  ${GREEN}7)${RESET} Uji Koneksi Provider Sekarang"
        echo -e "  ${YELLOW}0)${RESET} Selesai / Kembali ke Menu Utama"
        echo ""
        read -r -p "Pilihan Anda [0-7]: " edit_field_choice

        case "$edit_field_choice" in
            1)
                echo ""
                echo -e "${BOLD}Pilih Target Integrasi AI Baru:${RESET}"
                echo -e "  ${GREEN}1)${RESET} OpenCode (v1 & v2)      (Simpan ke ~/.config/opencode)"
                echo -e "  ${GREEN}2)${RESET} Antigravity CLI (agy)   (Simpan ke ~/.gemini/antigravity-cli)"
                echo -e "  ${GREEN}3)${RESET} Keduanya / Universal    (Disinkronkan ke OpenCode & agy)"
                read -r -p "Pilih target [1-3, Enter untuk tetap]: " n_t_choice
                new_tgt=""
                case "$n_t_choice" in
                    1) new_tgt="opencode" ;;
                    2) new_tgt="agy" ;;
                    3) new_tgt="all" ;;
                    *) new_tgt="$cur_target" ;;
                esac
                run_python_helper "edit" "$p_id" "$new_tgt" "__KEEP__" "__KEEP__" "__KEEP__" "__KEEP__" >/dev/null
                log_ok "Target integrasi untuk '$p_id' diperbarui ke '$new_tgt'!"
                sleep 1
                ;;
            2)
                echo ""
                echo -e "Base URL saat ini: ${YELLOW}${cur_base:-(default)}${RESET}"
                read -r -p "Masukkan Base URL baru (Tekan Enter untuk tetap): " new_base
                if [ -n "$new_base" ]; then
                    run_python_helper "edit" "$p_id" "__KEEP__" "$new_base" "__KEEP__" "__KEEP__" "__KEEP__" >/dev/null
                    log_ok "Base URL untuk '$p_id' berhasil diubah ke '$new_base'!"
                    sleep 1
                fi
                ;;
            3)
                echo ""
                echo -e "Model saat ini: ${GREEN}${cur_model:-(default)}${RESET}"
                read -r -p "Masukkan Model ID baru (Tekan Enter untuk tetap): " new_mod
                if [ -n "$new_mod" ]; then
                    run_python_helper "edit" "$p_id" "__KEEP__" "__KEEP__" "$new_mod" "__KEEP__" "__KEEP__" >/dev/null
                    log_ok "Default model untuk '$p_id' berhasil diubah ke '$new_mod'!"

                    read -r -p "Jadikan '$new_mod' sebagai model aktif saat ini? (Y/n): " set_act
                    if [[ ! "$set_act" =~ ^[Nn]$ ]]; then
                        run_python_helper "model" "$new_mod" >/dev/null 2>&1 || true
                        run_python_helper "model-agy" "$new_mod" >/dev/null 2>&1 || true
                        log_ok "Model aktif OpenCode & AGY diperbarui!"
                    fi
                    sleep 1
                fi
                ;;
            4)
                echo ""
                echo -e "API Mode saat ini: ${MAGENTA}${cur_mode_name:-Automatic} (${cur_mode:-auto})${RESET}"
                echo -e "${BOLD}Pilih API Mode Baru:${RESET}"
                echo -e "  ❯ ${GREEN}1. Automatic ✔${RESET}         Use the provider and model defaults (auto)"
                echo -e "    ${GREEN}2. Chat Completions${RESET}    Use /chat/completions for broad OpenAI-compatible support"
                echo -e "    ${GREEN}3. Responses${RESET}           Use /responses for providers that support the Responses API"
                echo -e "    ${GREEN}4. Responses (Compat)${RESET}  Use /responses with legacy text chunks for strict gateways"
                read -r -p "Pilihan API mode [1-4, Enter untuk tetap]: " n_m_choice
                new_mode=""
                case "$n_m_choice" in
                    1) new_mode="auto" ;;
                    2) new_mode="chat_completions" ;;
                    3) new_mode="responses" ;;
                    4) new_mode="responses_compat" ;;
                    *) new_mode="$cur_mode" ;;
                esac
                run_python_helper "edit" "$p_id" "__KEEP__" "__KEEP__" "__KEEP__" "$new_mode" "__KEEP__" >/dev/null
                log_ok "API Mode untuk '$p_id' berhasil diubah ke '$new_mode'!"
                sleep 1
                ;;
            5)
                echo ""
                echo -e "Masukkan API Key baru untuk ${BOLD}${CYAN}$p_id${RESET}:"
                echo -e "${DIM}(Input disembunyikan untuk privasi. Tekan Enter jika batal)${RESET}"
                read -r -s new_key
                echo ""
                if [ -n "$new_key" ]; then
                    run_python_helper "edit" "$p_id" "__KEEP__" "__KEEP__" "__KEEP__" "__KEEP__" "$new_key" >/dev/null
                    log_ok "API Key untuk '$p_id' berhasil diperbarui!"
                    sleep 1
                fi
                ;;
            6)
                echo ""
                echo -e "${BOLD}Target saat ini: ${cur_target}${RESET}"
                echo -e "  [1] OpenCode (v1 & v2)  [2] Antigravity (agy)  [3] Universal"
                read -r -p "Target baru [1-3, Enter untuk tetap]: " all_t
                all_target="$cur_target"
                case "$all_t" in
                    1) all_target="opencode" ;;
                    2) all_target="agy" ;;
                    3) all_target="all" ;;
                esac

                read -r -p "Base URL baru [Enter untuk tetap '$cur_base']: " all_base
                [ -z "$all_base" ] && all_base="$cur_base"

                read -r -p "Default Model baru [Enter untuk tetap '$cur_model']: " all_model
                [ -z "$all_model" ] && all_model="$cur_model"

                echo -e "API Mode: [1] Auto, [2] Chat Completions, [3] Responses, [4] Responses (Compat)"
                read -r -p "Pilihan mode [1-4, Enter untuk tetap]: " all_m
                all_mode="$cur_mode"
                case "$all_m" in
                    1) all_mode="auto" ;;
                    2) all_mode="chat_completions" ;;
                    3) all_mode="responses" ;;
                    4) all_mode="responses_compat" ;;
                esac

                echo -e "Ganti API Key? [Enter untuk tetap, ketik key jika ingin ganti]:"
                read -r -s all_key
                echo ""
                [ -z "$all_key" ] && all_key="__KEEP__"

                res=$(run_python_helper "edit" "$p_id" "$all_target" "$all_base" "$all_model" "$all_mode" "$all_key")
                log_ok "Seluruh konfigurasi '$p_id' berhasil diperbarui!"
                read -r -p "Tekan ENTER untuk lanjut..." _
                ;;
            7)
                echo ""
                echo -e "${CYAN}Menguji koneksi ke $p_id...${RESET}"
                t_res=$(run_python_helper "test" "$p_id")
                echo -e "Hasil: $t_res"
                read -r -p "Tekan ENTER untuk lanjut..." _
                ;;
            0)
                break
                ;;
        esac
    done
}

wizard_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo -e "${BOLD}         🔑 Termux AI Tools - Config Wizard (OpenCode & AGY)          ${RESET}"
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"

        run_python_helper "status"
        echo ""
        echo -e "${BOLD}Pilihan Menu:${RESET}"
        echo -e "  ${GREEN}1)${RESET} Tambah / Perbarui API Key Provider (Quick Setup)"
        echo -e "  ${MAGENTA}2)${RESET} 🚀 Setup Provider Lanjutan (Target OpenCode/AGY, Base URL, Model, Mode)"
        echo -e "  ${CYAN}3)${RESET} ✏️  Edit / Ubah Konfigurasi Provider Terpasang"
        echo -e "  ${CYAN}4)${RESET} Aktifkan / Nonaktifkan Provider (Enable / Disable)"
        echo -e "  ${GREEN}5)${RESET} Pilih Default Model (OpenCode & Antigravity agy)"
        echo -e "  ${CYAN}6)${RESET} Uji Koneksi & Validasi API Key"
        echo -e "  ${CYAN}7)${RESET} Detail Lengkap Provider (Inspect Config & Parameter)"
        echo -e "  ${CYAN}8)${RESET} Sinkronkan ke Shell Environment (~/.termux_ai_env)"
        echo -e "  ${RED}9)${RESET} Hapus API Key / Konfigurasi Provider"
        echo -e "  ${YELLOW}0)${RESET} Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-9]: " menu_choice

        case "$menu_choice" in
            1)
                echo ""
                echo -e "${BOLD}Pilih Provider yang ingin dikonfigurasi:${RESET}"
                echo -e "  ${GREEN}1)${RESET} Google Gemini     (Dapatkan di: https://aistudio.google.com/app/apikey)"
                echo -e "  ${GREEN}2)${RESET} Anthropic Claude  (Dapatkan di: https://console.anthropic.com/settings/keys)"
                echo -e "  ${GREEN}3)${RESET} OpenAI            (Dapatkan di: https://platform.openai.com/api-keys)"
                echo -e "  ${GREEN}4)${RESET} DeepSeek          (Dapatkan di: https://platform.deepseek.com/api_keys)"
                echo -e "  ${GREEN}5)${RESET} OpenRouter        (Dapatkan di: https://openrouter.ai/keys)"
                echo -e "  ${GREEN}6)${RESET} Groq              (Dapatkan di: https://console.groq.com/keys)"
                echo -e "  ${GREEN}7)${RESET} Mistral AI        (Dapatkan di: https://console.mistral.ai/)"
                echo -e "  ${GREEN}8)${RESET} xAI / Grok        (Dapatkan di: https://console.x.ai/)"
                echo -e "  ${CYAN}9)${RESET} NaraRouter / bynara (https://router.bynara.id)"
                echo -e "  ${CYAN}10)${RESET} Provider Kustom Lainnya"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilih provider [0-10]: " p_choice

                prov_id=""
                case "$p_choice" in
                    1) prov_id="google" ;;
                    2) prov_id="anthropic" ;;
                    3) prov_id="openai" ;;
                    4) prov_id="deepseek" ;;
                    5) prov_id="openrouter" ;;
                    6) prov_id="groq" ;;
                    7) prov_id="mistral" ;;
                    8) prov_id="xai" ;;
                    9) prov_id="bynara" ;;
                    10)
                        read -r -p "Masukkan ID provider (contoh: together, ollama, cohere): " prov_id
                        prov_id=$(echo "$prov_id" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                        ;;
                    *) prov_id="" ;;
                esac

                if [ -n "$prov_id" ]; then
                    echo ""
                    echo -e "${BOLD}Pilih Target Integrasi AI:${RESET}"
                    echo -e "  ${GREEN}1)${RESET} OpenCode (v1 & v2)      (Simpan ke ~/.config/opencode)"
                    echo -e "  ${GREEN}2)${RESET} Antigravity CLI (agy)   (Simpan ke ~/.gemini/antigravity-cli)"
                    echo -e "  ${GREEN}3)${RESET} Keduanya / Universal    (Direkomendasikan - OpenCode & agy)"
                    read -r -p "Pilih target [1-3, default 3]: " t_choice
                    case "$t_choice" in
                        1) target_tool="opencode" ;;
                        2) target_tool="agy" ;;
                        *) target_tool="all" ;;
                    esac

                    echo ""
                    echo -e "Masukkan API Key untuk ${BOLD}${CYAN}$prov_id${RESET}:"
                    echo -e "${DIM}(Input disembunyikan untuk privasi. Tekan Enter jika selesai)${RESET}"
                    read -r -s input_key
                    echo ""
                    if [ -n "$input_key" ]; then
                        res=$(run_python_helper "set" "$prov_id" "$input_key" "$target_tool")
                        if [[ "$res" == OK:* ]]; then
                            masked=$(echo "$res" | cut -d':' -f2)
                            tgt_saved=$(echo "$res" | cut -d':' -f3)
                            log_ok "API Key untuk '$prov_id' berhasil disimpan ($masked) [Target: $tgt_saved]"

                            read -r -p "Uji validitas koneksi API key sekarang? (y/N): " test_now
                            if [[ "$test_now" =~ ^[Yy]$ ]]; then
                                echo -e "${CYAN}Menguji koneksi ke $prov_id...${RESET}"
                                t_res=$(run_python_helper "test" "$prov_id")
                                echo -e "Hasil: $t_res"
                            fi
                        else
                            log_err "Gagal menyimpan key: $res"
                        fi
                    else
                        log_warn "Input dibatalkan (API key kosong)."
                    fi
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;

            2)
                # Advanced Provider Setup: Target, Base URL, Model, API Mode
                echo ""
                echo -e "${BOLD}${MAGENTA}======================================================================${RESET}"
                echo -e "${BOLD}     🚀 Konfigurasi Lanjutan Provider (Base URL, Model & API Mode)    ${RESET}"
                echo -e "${BOLD}${MAGENTA}======================================================================${RESET}"
                echo ""
                echo -e "${BOLD}Pilih Provider yang ingin dikonfigurasi secara mendalam:${RESET}"
                echo -e "  ${GREEN}1)${RESET} Google Gemini     (google)"
                echo -e "  ${GREEN}2)${RESET} Anthropic Claude  (anthropic)"
                echo -e "  ${GREEN}3)${RESET} OpenAI            (openai)"
                echo -e "  ${GREEN}4)${RESET} DeepSeek          (deepseek)"
                echo -e "  ${GREEN}5)${RESET} OpenRouter        (openrouter)"
                echo -e "  ${GREEN}6)${RESET} Groq              (groq)"
                echo -e "  ${GREEN}7)${RESET} Mistral AI        (mistral)"
                echo -e "  ${GREEN}8)${RESET} xAI / Grok        (xai)"
                echo -e "  ${CYAN}9)${RESET} NaraRouter        (bynara)"
                echo -e "  ${CYAN}10)${RESET} Provider Kustom (Input manual ID)"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilih provider [0-10]: " adv_p_choice

                adv_prov=""
                case "$adv_p_choice" in
                    1) adv_prov="google" ;;
                    2) adv_prov="anthropic" ;;
                    3) adv_prov="openai" ;;
                    4) adv_prov="deepseek" ;;
                    5) adv_prov="openrouter" ;;
                    6) adv_prov="groq" ;;
                    7) adv_prov="mistral" ;;
                    8) adv_prov="xai" ;;
                    9) adv_prov="bynara" ;;
                    10)
                        read -r -p "Masukkan ID provider kustom: " adv_prov
                        adv_prov=$(echo "$adv_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                        ;;
                    *) adv_prov="" ;;
                esac

                if [ -n "$adv_prov" ]; then
                    # 1. Pilih Target
                    echo ""
                    echo -e "${BOLD}1. Target Integrasi AI:${RESET}"
                    echo -e "  ${GREEN}1)${RESET} OpenCode (v1 & v2)      (Simpan ke ~/.config/opencode/opencode.jsonc)"
                    echo -e "  ${GREEN}2)${RESET} Antigravity CLI (agy)   (Simpan ke ~/.gemini/antigravity-cli/settings.json)"
                    echo -e "  ${GREEN}3)${RESET} Keduanya / Universal    (Disinkronkan ke OpenCode & Antigravity agy)"
                    read -r -p "Pilih target [1-3, default 3]: " adv_t_choice
                    case "$adv_t_choice" in
                        1) adv_target="opencode" ;;
                        2) adv_target="agy" ;;
                        *) adv_target="all" ;;
                    esac

                    # 2. Input API Key (atau gunakan yang sudah ada)
                    cur_key=$(run_python_helper "get" "$adv_prov")
                    echo ""
                    echo -e "${BOLD}2. API Key Provider ($adv_prov):${RESET}"
                    if [ -n "$cur_key" ]; then
                        echo -e "Key saat ini: ${GREEN}$cur_key${RESET}"
                        echo -e "${DIM}(Tekan Enter langsung untuk mempertahankan key saat ini, atau ketik key baru)${RESET}"
                    else
                        echo -e "${DIM}(Input disembunyikan untuk privasi. Tekan Enter jika selesai)${RESET}"
                    fi
                    read -r -s adv_key
                    echo ""
                    if [ -z "$adv_key" ]; then
                        if [ -n "$cur_key" ]; then
                            # Keep existing key by reading info
                            adv_info=$(run_python_helper "info" "$adv_prov")
                            adv_key=$(python3 -c "import json, os; p=os.path.expanduser('~/.local/share/opencode/auth.json'); d=json.load(open(p)) if os.path.exists(p) else {}; print(d.get('$adv_prov', {}).get('key', ''))")
                        fi
                    fi

                    if [ -z "$adv_key" ]; then
                        log_err "API Key diperlukan untuk mengonfigurasi provider."
                        read -r -p "Tekan ENTER untuk kembali..." _
                        continue
                    fi

                    # 3. Base URL
                    echo ""
                    echo -e "${BOLD}3. Base URL (API Endpoint):${RESET}"
                    def_base=""
                    case "$adv_prov" in
                        google) def_base="https://generativelanguage.googleapis.com/v1beta" ;;
                        anthropic) def_base="https://api.anthropic.com/v1" ;;
                        openai) def_base="https://api.openai.com/v1" ;;
                        deepseek) def_base="https://api.deepseek.com/v1" ;;
                        openrouter) def_base="https://openrouter.ai/api/v1" ;;
                        groq) def_base="https://api.groq.com/openai/v1" ;;
                        mistral) def_base="https://api.mistral.ai/v1" ;;
                        xai) def_base="https://api.x.ai/v1" ;;
                        bynara) def_base="https://router.bynara.id/v1" ;;
                        *) def_base="https://api.openai.com/v1" ;;
                    esac
                    echo -e "Default / Rekomendasi: ${CYAN}$def_base${RESET}"
                    read -r -p "Masukkan Base URL [Tekan Enter untuk gunakan default]: " adv_base
                    [ -z "$adv_base" ] && adv_base="$def_base"

                    # 4. Default Model
                    echo ""
                    echo -e "${BOLD}4. Default Model:${RESET}"
                    def_mod=""
                    case "$adv_prov" in
                        google) def_mod="google/gemini-2.5-flash" ;;
                        anthropic) def_mod="anthropic/claude-3-7-sonnet" ;;
                        openai) def_mod="openai/gpt-4o" ;;
                        deepseek) def_mod="deepseek/deepseek-chat" ;;
                        openrouter) def_mod="openrouter/auto" ;;
                        groq) def_mod="groq/llama-3.3-70b-versatile" ;;
                        mistral) def_mod="mistral/mistral-large-latest" ;;
                        xai) def_mod="xai/grok-2-latest" ;;
                        bynara) def_mod="bynara/glm-5.3-flash" ;;
                        *) def_mod="$adv_prov/default-model" ;;
                    esac
                    echo -e "Default / Rekomendasi: ${GREEN}$def_mod${RESET}"
                    read -r -p "Masukkan ID Model [Tekan Enter untuk gunakan default]: " adv_model
                    [ -z "$adv_model" ] && adv_model="$def_mod"

                    # 5. API Mode
                    echo ""
                    echo -e "${BOLD}5. API Mode:${RESET}"
                    echo -e "  ❯ ${GREEN}1. Automatic ✔${RESET}         Use the provider and model defaults (auto)"
                    echo -e "    ${GREEN}2. Chat Completions${RESET}    Use /chat/completions for broad OpenAI-compatible support"
                    echo -e "    ${GREEN}3. Responses${RESET}           Use /responses for providers that support the Responses API"
                    echo -e "    ${GREEN}4. Responses (Compat)${RESET}  Use /responses with legacy text chunks for strict gateways"
                    echo ""
                    read -r -p "Pilihan mode [1-4, default 1]: " adv_m_choice
                    case "$adv_m_choice" in
                        2) adv_mode="chat_completions" ;;
                        3) adv_mode="responses" ;;
                        4) adv_mode="responses_compat" ;;
                        *) adv_mode="auto" ;;
                    esac

                    # Simpan seluruh parameter
                    echo ""
                    log_info "Menyimpan konfigurasi lengkap untuk provider '$adv_prov'..."
                    res=$(run_python_helper "set" "$adv_prov" "$adv_key" "$adv_target" "$adv_base" "$adv_model" "$adv_mode")
                    if [[ "$res" == OK:* ]]; then
                        masked=$(echo "$res" | cut -d':' -f2)
                        log_ok "Konfigurasi provider '$adv_prov' berhasil disimpan!"
                        echo -e "  • Target    : ${CYAN}$adv_target${RESET}"
                        echo -e "  • Base URL  : ${YELLOW}$adv_base${RESET}"
                        echo -e "  • Model     : ${GREEN}$adv_model${RESET}"
                        echo -e "  • API Mode  : ${MAGENTA}$adv_mode${RESET}"
                        echo -e "  • API Key   : ${GREEN}$masked${RESET}"

                        # Tawaran jadikan default model
                        echo ""
                        read -r -p "Jadikan model '$adv_model' sebagai Default Model aktif saat ini? (Y/n): " set_def
                        if [[ ! "$set_def" =~ ^[Nn]$ ]]; then
                            if [ "$adv_target" = "opencode" ] || [ "$adv_target" = "all" ]; then
                                run_python_helper "model" "$adv_model" >/dev/null
                                log_ok "Model default OpenCode diatur ke '$adv_model'"
                            fi
                            if [ "$adv_target" = "agy" ] || [ "$adv_target" = "all" ]; then
                                run_python_helper "model-agy" "$adv_model" >/dev/null
                                log_ok "Model default Antigravity (agy) diatur ke '$adv_model'"
                            fi
                        fi

                        # Tawaran uji koneksi
                        read -r -p "Uji koneksi ke endpoint provider sekarang? (y/N): " test_now
                        if [[ "$test_now" =~ ^[Yy]$ ]]; then
                            echo -e "${CYAN}Menguji koneksi ke $adv_prov...${RESET}"
                            t_res=$(run_python_helper "test" "$adv_prov")
                            echo -e "Hasil: $t_res"
                        fi
                    else
                        log_err "Gagal menyimpan konfigurasi: $res"
                    fi
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;

            3)
                # Edit / Ubah Konfigurasi Provider Terpasang
                echo ""
                echo -e "${BOLD}${CYAN}======================================================================${RESET}"
                echo -e "${BOLD}         ✏️  Edit / Ubah Konfigurasi Provider (OpenCode & AGY)        ${RESET}"
                echo -e "${BOLD}${CYAN}======================================================================${RESET}"
                echo ""

                cfg_list=$(run_python_helper "configured-list")

                if [ -z "$cfg_list" ]; then
                    log_warn "Belum ada provider yang terkonfigurasi. Silakan tambah provider terlebih dahulu melalui Menu 1 atau 2."
                    read -r -p "Tekan ENTER untuk kembali..." _
                    continue
                fi

                echo -e "${BOLD}Pilih Provider yang ingin diubah pengaturannya:${RESET}"
                i=1
                declare -A prov_map
                while IFS='|' read -r p_id p_name p_tgt p_mode p_model p_url; do
                    [ -z "$p_id" ] && continue
                    prov_map[$i]="$p_id"
                    echo -e "  ${GREEN}$i)${RESET} ${BOLD}$p_id${RESET} ($p_name) - [Target: ${CYAN}$p_tgt${RESET}, Mode: ${MAGENTA}$p_mode${RESET}]"
                    i=$((i + 1))
                done <<< "$cfg_list"
                echo -e "  ${CYAN}C)${RESET} Masukkan ID Provider Kustom Lainnya"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilihan Anda [0-$((i-1)) / C]: " e_pick

                selected_edit_prov=""
                if [[ "$e_pick" =~ ^[0-9]+$ ]] && [ "$e_pick" -gt 0 ] && [ "$e_pick" -lt "$i" ]; then
                    selected_edit_prov="${prov_map[$e_pick]}"
                elif [[ "$e_pick" =~ ^[Cc]$ ]]; then
                    read -r -p "Masukkan ID provider: " selected_edit_prov
                    selected_edit_prov=$(echo "$selected_edit_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                fi

                if [ -n "$selected_edit_prov" ]; then
                    edit_provider_menu "$selected_edit_prov"
                fi
                ;;

            4)
                echo ""
                echo -e "${BOLD}Pilih Provider untuk mengubah status (Enable / Disable):${RESET}"
                echo -e "  ${GREEN}1)${RESET} Google Gemini     (google)"
                echo -e "  ${GREEN}2)${RESET} Anthropic Claude  (anthropic)"
                echo -e "  ${GREEN}3)${RESET} OpenAI            (openai)"
                echo -e "  ${GREEN}4)${RESET} DeepSeek          (deepseek)"
                echo -e "  ${GREEN}5)${RESET} OpenRouter        (openrouter)"
                echo -e "  ${GREEN}6)${RESET} Groq              (groq)"
                echo -e "  ${GREEN}7)${RESET} Mistral AI        (mistral)"
                echo -e "  ${GREEN}8)${RESET} xAI / Grok        (xai)"
                echo -e "  ${CYAN}9)${RESET} NaraRouter        (bynara)"
                echo -e "  ${CYAN}10)${RESET} Provider Kustom Lainnya"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilih provider [0-10]: " t_choice

                target_prov=""
                case "$t_choice" in
                    1) target_prov="google" ;;
                    2) target_prov="anthropic" ;;
                    3) target_prov="openai" ;;
                    4) target_prov="deepseek" ;;
                    5) target_prov="openrouter" ;;
                    6) target_prov="groq" ;;
                    7) target_prov="mistral" ;;
                    8) target_prov="xai" ;;
                    9) target_prov="bynara" ;;
                    10)
                        read -r -p "Masukkan ID provider: " target_prov
                        target_prov=$(echo "$target_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                        ;;
                    *) target_prov="" ;;
                esac

                if [ -n "$target_prov" ]; then
                    is_dis=$(run_python_helper "is_disabled" "$target_prov")
                    echo ""
                    if [ "$is_dis" = "1" ]; then
                        echo -e "Status saat ini: ${RED}[ NONAKTIF ]${RESET}"
                        read -r -p "Aktifkan kembali provider '$target_prov'? (Y/n): " confirm_act
                        if [[ ! "$confirm_act" =~ ^[Nn]$ ]]; then
                            res=$(run_python_helper "enable" "$target_prov")
                            log_ok "Provider '$target_prov' berhasil diaktifkan kembali!"
                        fi
                    else
                        echo -e "Status saat ini: ${GREEN}[ AKTIF / SIAP ]${RESET}"
                        read -r -p "Nonaktifkan provider '$target_prov'? (y/N): " confirm_dis
                        if [[ "$confirm_dis" =~ ^[Yy]$ ]]; then
                            res=$(run_python_helper "disable" "$target_prov")
                            log_ok "Provider '$target_prov' berhasil dinonaktifkan."
                            cur_mod=$(run_python_helper "model")
                            if [[ "$cur_mod" == "$target_prov/"* ]]; then
                                log_warn "Perhatian: Model default aktif OpenCode saat ini ($cur_mod) menggunakan provider '$target_prov'."
                                log_warn "Disarankan untuk mengganti default model melalui Menu 5."
                            fi
                        fi
                    fi
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;

            5)
                echo ""
                echo -e "${BOLD}Pilih Tool yang ingin diatur Default Model-nya:${RESET}"
                echo -e "  ${GREEN}1)${RESET} OpenCode (v1 & v2)      (opencode.jsonc)"
                echo -e "  ${MAGENTA}2)${RESET} Antigravity CLI (agy)   (settings.json)"
                echo -e "  ${CYAN}3)${RESET} Keduanya Sekaligus"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilihan tool [0-3]: " tool_target_choice

                if [ "$tool_target_choice" = "1" ] || [ "$tool_target_choice" = "2" ] || [ "$tool_target_choice" = "3" ]; then
                    echo ""
                    echo -e "${BOLD}Pilih Preset Model Rekomendasi:${RESET}"
                    echo -e "  ${GREEN}1)${RESET} bynara/glm-5.3-flash          (NaraRouter / Cepat & Terjangkau)"
                    echo -e "  ${GREEN}2)${RESET} google/gemini-2.5-flash       (Cepat & Hemat Token)"
                    echo -e "  ${GREEN}3)${RESET} google/gemini-2.5-pro         (Penalaran Tinggi & Akurat)"
                    echo -e "  ${GREEN}4)${RESET} anthropic/claude-3-7-sonnet   (Paling Andal Coding & Refactoring)"
                    echo -e "  ${GREEN}5)${RESET} anthropic/claude-3-5-sonnet   (Andal & Stabil)"
                    echo -e "  ${GREEN}6)${RESET} deepseek/deepseek-chat        (Sangat Murah & Cerdas)"
                    echo -e "  ${GREEN}7)${RESET} deepseek/deepseek-reasoner    (Model Berpikir / R1)"
                    echo -e "  ${GREEN}8)${RESET} openai/gpt-4o                 (Multimodal Cepat)"
                    echo -e "  ${GREEN}9)${RESET} openrouter/auto               (Rute Otomatis Model Terbaik)"
                    echo -e "  ${CYAN}10)${RESET} Input Manual ID Model Kustom"
                    echo -e "  ${YELLOW}0)${RESET} Batal"
                    echo ""
                    read -r -p "Pilihan model [0-10]: " m_choice

                    selected_model=""
                    case "$m_choice" in
                        1) selected_model="bynara/glm-5.3-flash" ;;
                        2) selected_model="google/gemini-2.5-flash" ;;
                        3) selected_model="google/gemini-2.5-pro" ;;
                        4) selected_model="anthropic/claude-3-7-sonnet" ;;
                        5) selected_model="anthropic/claude-3-5-sonnet" ;;
                        6) selected_model="deepseek/deepseek-chat" ;;
                        7) selected_model="deepseek/deepseek-reasoner" ;;
                        8) selected_model="openai/gpt-4o" ;;
                        9) selected_model="openrouter/auto" ;;
                        10)
                            read -r -p "Masukkan model ID lengkap (contoh: provider/model-name): " selected_model
                            ;;
                        *) selected_model="" ;;
                    esac

                    if [ -n "$selected_model" ]; then
                        if [ "$tool_target_choice" = "1" ] || [ "$tool_target_choice" = "3" ]; then
                            run_python_helper "model" "$selected_model" >/dev/null
                            log_ok "Default model OpenCode diatur ke '$selected_model' di opencode.jsonc"
                        fi
                        if [ "$tool_target_choice" = "2" ] || [ "$tool_target_choice" = "3" ]; then
                            run_python_helper "model-agy" "$selected_model" >/dev/null
                            log_ok "Default model Antigravity (agy) diatur ke '$selected_model' di settings.json"
                        fi
                        echo ""
                        read -r -p "Tekan ENTER untuk kembali..." _
                    fi
                fi
                ;;

            6)
                echo ""
                log_info "Memeriksa dan menguji validitas seluruh provider aktif..."
                run_python_helper "test" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;

            7)
                echo ""
                read -r -p "Masukkan ID provider yang ingin diinspeksi (contoh: bynara, google, openai): " inspect_prov
                inspect_prov=$(echo "$inspect_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                if [ -n "$inspect_prov" ]; then
                    echo ""
                    echo -e "${BOLD}${CYAN}==================================================${RESET}"
                    echo -e "${BOLD}      Detail Konfigurasi Provider: $inspect_prov  ${RESET}"
                    echo -e "${BOLD}${CYAN}==================================================${RESET}"
                    run_python_helper "info" "$inspect_prov"
                    echo -e "${BOLD}${CYAN}==================================================${RESET}"
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;

            8)
                echo ""
                log_info "Mengekspor API Key & Endpoint ke $ENV_FILE..."
                res=$(run_python_helper "sync-env")
                count="${res#SYNC_COUNT:}"
                log_ok "Berhasil mengekspor $count variabel provider ke $ENV_FILE"

                BASHRC="$HOME_DIR/.bashrc"
                if [ -f "$BASHRC" ]; then
                    if ! grep -q "termux_ai_env" "$BASHRC" 2>/dev/null; then
                        read -r -p "Tambahkan auto-load ke ~/.bashrc? (Y/n): " add_bashrc
                        if [[ ! "$add_bashrc" =~ ^[Nn]$ ]]; then
                            echo -e "\n# Load Termux AI Tools Environment\n[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\"" >> "$BASHRC"
                            log_ok "Ditambahkan ke ~/.bashrc! Sekarang perintah lain (curl, python, agy, opencode) juga dapat membaca API Key."
                        fi
                    else
                        log_ok "Auto-load sudah terpasang di ~/.bashrc."
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;

            9)
                echo ""
                read -r -p "Masukkan nama provider yang ingin dihapus (contoh: openai): " del_prov
                del_prov=$(echo "$del_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                if [ -n "$del_prov" ]; then
                    read -r -p "Apakah Anda yakin ingin menghapus konfigurasi provider '$del_prov'? (y/N): " confirm_del
                    if [[ "$confirm_del" =~ ^[Yy]$ ]]; then
                        res=$(run_python_helper "remove" "$del_prov")
                        if [[ "$res" == DELETED:* ]]; then
                            log_ok "Provider '$del_prov' berhasil dihapus dari sistem (auth.json, opencode.jsonc, settings.json)"
                        else
                            log_warn "Provider '$del_prov' tidak ditemukan dalam sistem"
                        fi
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;

            0)
                echo "Keluar dari wizard."
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
case "$1" in
    list|status|ls)
        run_python_helper "list"
        ;;
    get)
        run_python_helper "get" "$2"
        ;;
    info)
        run_python_helper "info" "$2"
        ;;
    edit)
        # Usage: config.sh edit <provider> [target] [baseURL] [model] [apiMode] [key]
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh edit <provider> [target] [baseURL] [model] [apiMode] [key]"
            exit 1
        fi
        res=$(run_python_helper "edit" "$2" "${3:-__KEEP__}" "${4:-__KEEP__}" "${5:-__KEEP__}" "${6:-__KEEP__}" "${7:-__KEEP__}")
        if [[ "$res" == OK_EDIT:* ]]; then
            masked=$(echo "$res" | cut -d':' -f2)
            tgt=$(echo "$res" | cut -d':' -f3)
            mode=$(echo "$res" | cut -d':' -f4)
            log_ok "Konfigurasi provider '$2' berhasil diperbarui ($masked) [Target: $tgt, Mode: $mode]"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    edit-field)
        # Usage: config.sh edit-field <provider> <target|baseurl|model|mode|key> <value>
        if [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
            log_err "Penggunaan: config.sh edit-field <provider> <target|baseurl|model|mode|key> <value>"
            exit 1
        fi
        prov="$2"
        field="$3"
        val="$4"
        case "$field" in
            target) res=$(run_python_helper "edit" "$prov" "$val" "__KEEP__" "__KEEP__" "__KEEP__" "__KEEP__") ;;
            baseurl|baseURL|url) res=$(run_python_helper "edit" "$prov" "__KEEP__" "$val" "__KEEP__" "__KEEP__" "__KEEP__") ;;
            model) res=$(run_python_helper "edit" "$prov" "__KEEP__" "__KEEP__" "$val" "__KEEP__" "__KEEP__") ;;
            mode|apimode|apiMode) res=$(run_python_helper "edit" "$prov" "__KEEP__" "__KEEP__" "__KEEP__" "$val" "__KEEP__") ;;
            key|apikey|apiKey) res=$(run_python_helper "edit" "$prov" "__KEEP__" "__KEEP__" "__KEEP__" "__KEEP__" "$val") ;;
            *) log_err "Field tidak valid. Pilih: target, baseurl, model, mode, key"; exit 1 ;;
        esac
        if [[ "$res" == OK_EDIT:* ]]; then
            log_ok "Field '$field' untuk provider '$prov' berhasil diubah!"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    set)
        # Usage: config.sh set <provider> <key> [target] [baseURL] [model] [apiMode]
        if [ -n "$3" ]; then
            key="$3"
        else
            echo -e "Masukkan API Key untuk ${BOLD}${CYAN}$2${RESET}:"
            read -r -s key
            echo ""
        fi
        target="${4:-all}"
        base_url="${5:-}"
        model="${6:-}"
        api_mode="${7:-auto}"

        res=$(run_python_helper "set" "$2" "$key" "$target" "$base_url" "$model" "$api_mode")
        if [[ "$res" == OK:* ]]; then
            masked=$(echo "$res" | cut -d':' -f2)
            tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "API Key untuk '$2' disimpan ($masked) [Target: $tgt]"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    set-advanced)
        # Direct CLI helper for advanced provider setup
        if [ -z "$2" ] || [ -z "$3" ]; then
            log_err "Penggunaan: config.sh set-advanced <provider> <key> [target] [baseURL] [model] [apiMode]"
            exit 1
        fi
        res=$(run_python_helper "set" "$2" "$3" "${4:-all}" "${5:-}" "${6:-}" "${7:-auto}")
        if [[ "$res" == OK:* ]]; then
            masked=$(echo "$res" | cut -d':' -f2)
            log_ok "Konfigurasi advanced provider '$2' disimpan ($masked)"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    enable)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh enable <provider>"
            exit 1
        fi
        res=$(run_python_helper "enable" "$2")
        if [[ "$res" == ENABLED:* ]]; then
            log_ok "Provider '${res#ENABLED:}' berhasil diaktifkan"
        elif [[ "$res" == ALREADY_ENABLED:* ]]; then
            log_info "Provider '${res#ALREADY_ENABLED:}' sudah dalam status AKTIF"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    disable)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh disable <provider>"
            exit 1
        fi
        res=$(run_python_helper "disable" "$2")
        if [[ "$res" == DISABLED:* ]]; then
            log_ok "Provider '${res#DISABLED:}' berhasil dinonaktifkan"
        elif [[ "$res" == ALREADY_DISABLED:* ]]; then
            log_info "Provider '${res#ALREADY_DISABLED:}' sudah dalam status NONAKTIF"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    toggle)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh toggle <provider>"
            exit 1
        fi
        res=$(run_python_helper "toggle" "$2")
        if [[ "$res" == ENABLED:* ]]; then
            log_ok "Provider '${res#ENABLED:}' diaktifkan"
        elif [[ "$res" == DISABLED:* ]]; then
            log_ok "Provider '${res#DISABLED:}' dinonaktifkan"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    remove|del|rm)
        res=$(run_python_helper "remove" "$2")
        if [[ "$res" == DELETED:* ]]; then
            log_ok "Provider '$2' berhasil dihapus"
        else
            log_warn "Provider '$2' tidak ditemukan"
        fi
        ;;
    model)
        if [ -n "$2" ]; then
            run_python_helper "model" "$2"
            log_ok "Default model OpenCode diatur ke '$2'"
        else
            m=$(run_python_helper "model")
            echo "Default model OpenCode saat ini: ${m:-Belum diatur}"
        fi
        ;;
    model-agy)
        if [ -n "$2" ]; then
            run_python_helper "model-agy" "$2"
            log_ok "Default model Antigravity (agy) diatur ke '$2'"
        else
            m=$(run_python_helper "model-agy")
            echo "Default model Antigravity (agy) saat ini: ${m:-Belum diatur}"
        fi
        ;;
    sync-env|sync)
        res=$(run_python_helper "sync-env")
        count="${res#SYNC_COUNT:}"
        log_ok "Sinkronisasi selesai: $count API key & parameter diekspor ke $ENV_FILE"
        ;;
    test)
        run_python_helper "test" "${2:-all}"
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - Config Helper Usage:${RESET}"
        echo "  bash config.sh                     Buka Wizard interaktif (OpenCode & AGY)"
        echo "  bash config.sh list                Tampilkan status provider, target & API Key"
        echo "  bash config.sh info <provider>     Tampilkan detail lengkap endpoint & mode provider"
        echo "  bash config.sh set <provider> <key> [target] [baseURL] [model] [apiMode]"
        echo "                                     Simpan API key dan konfigurasi lanjutan"
        echo "  bash config.sh edit <provider> [target] [baseURL] [model] [apiMode] [key]"
        echo "                                     Edit konfigurasi provider yang terpasang"
        echo "  bash config.sh edit-field <provider> <target|baseurl|model|mode|key> <val>"
        echo "                                     Edit nilai spesifik parameter provider"
        echo "  bash config.sh get <provider>      Tampilkan masked key provider"
        echo "  bash config.sh enable <provider>   Aktifkan provider (hapus dari disabled_providers)"
        echo "  bash config.sh disable <provider>  Nonaktifkan provider (tambahkan ke disabled_providers)"
        echo "  bash config.sh toggle <provider>   Beralih status aktif/nonaktif provider"
        echo "  bash config.sh remove <provider>   Hapus konfigurasi provider dari sistem"
        echo "  bash config.sh model [model_id]    Tampilkan atau set default model OpenCode"
        echo "  bash config.sh model-agy [model_id]Tampilkan atau set default model Antigravity (agy)"
        echo "  bash config.sh sync-env            Sinkronkan key & endpoint ke ~/.termux_ai_env"
        echo "  bash config.sh test [provider]     Uji validitas koneksi & API key"
        exit 0
        ;;
    *)
        wizard_menu
        ;;
esac

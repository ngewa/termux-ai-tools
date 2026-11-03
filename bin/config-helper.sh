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

def is_provider_disabled_opencode(pid, config_data, auth_data):
    if pid in config_data.get("disabled_providers", []):
        return True
    entry = auth_data.get(pid, {})
    if entry.get("disabled") is True or entry.get("disabled_opencode") is True:
        return True
    return False

def is_provider_disabled_agy(pid, agy_data, auth_data):
    if pid in agy_data.get("disabled_providers", []):
        return True
    agy_prov = agy_data.get("providers", {}).get(pid, {})
    if agy_prov.get("disabled") is True:
        return True
    entry = auth_data.get(pid, {})
    if entry.get("disabled") is True or entry.get("disabled_agy") is True:
        return True
    return False

def is_provider_disabled(pid, config_data, auth_data, agy_data=None, target="auto"):
    if agy_data is None:
        agy_data = load_agy_settings()
    entry = auth_data.get(pid, {})
    prov_target = entry.get("target", "all")

    if target == "opencode":
        return is_provider_disabled_opencode(pid, config_data, auth_data)
    elif target == "agy":
        return is_provider_disabled_agy(pid, agy_data, auth_data)
    elif target == "all":
        dis_oc = is_provider_disabled_opencode(pid, config_data, auth_data)
        dis_agy = is_provider_disabled_agy(pid, agy_data, auth_data)
        return dis_oc and dis_agy
    else:  # auto based on prov_target
        if prov_target == "opencode":
            return is_provider_disabled_opencode(pid, config_data, auth_data)
        elif prov_target == "agy":
            return is_provider_disabled_agy(pid, agy_data, auth_data)
        else:
            dis_oc = is_provider_disabled_opencode(pid, config_data, auth_data)
            dis_agy = is_provider_disabled_agy(pid, agy_data, auth_data)
            return dis_oc and dis_agy

def set_provider_disabled(pid, disabled=True, target="all"):
    config_data = load_config()
    auth_data = load_auth()
    agy_data = load_agy_settings()
    entry = auth_data.get(pid, {})

    if target in ("all", "opencode"):
        dis_list = list(config_data.get("disabled_providers", []))
        if disabled:
            if pid not in dis_list:
                dis_list.append(pid)
            config_data["disabled_providers"] = dis_list
            if pid in auth_data:
                if target == "all":
                    auth_data[pid]["disabled"] = True
                else:
                    auth_data[pid]["disabled_opencode"] = True
        else:
            if pid in dis_list:
                dis_list = [x for x in dis_list if x != pid]
            if dis_list:
                config_data["disabled_providers"] = dis_list
            else:
                config_data.pop("disabled_providers", None)
            if pid in auth_data:
                auth_data[pid].pop("disabled_opencode", None)
                if target == "all":
                    auth_data[pid].pop("disabled", None)
        save_config(config_data)

    if target in ("all", "agy"):
        agy_dis_list = list(agy_data.get("disabled_providers", []))
        if disabled:
            if pid not in agy_dis_list:
                agy_dis_list.append(pid)
            agy_data["disabled_providers"] = agy_dis_list
            if isinstance(agy_data.get("providers"), dict) and pid in agy_data["providers"]:
                agy_data["providers"][pid]["disabled"] = True
            if pid in auth_data:
                if target == "all":
                    auth_data[pid]["disabled"] = True
                else:
                    auth_data[pid]["disabled_agy"] = True
        else:
            if pid in agy_dis_list:
                agy_dis_list = [x for x in agy_dis_list if x != pid]
            if agy_dis_list:
                agy_data["disabled_providers"] = agy_dis_list
            else:
                agy_data.pop("disabled_providers", None)
            if isinstance(agy_data.get("providers"), dict) and pid in agy_data["providers"]:
                agy_data["providers"][pid].pop("disabled", None)
            if pid in auth_data:
                auth_data[pid].pop("disabled_agy", None)
                if target == "all":
                    auth_data[pid].pop("disabled", None)
        save_agy_settings(agy_data)

    if pid in auth_data:
        save_auth(auth_data)

def set_provider_target(pid, target):
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()

    details = get_provider_details(pid, auth_data, config_data, agy_data)
    key = details["key"]
    base_url = details["base_url"]
    model = details["model"]
    api_mode = details["api_mode"]
    name = details["name"]

    if target not in TARGET_TOOLS:
        target = "all"

    # 1. Update auth.json
    auth_entry = auth_data.get(pid, {})
    auth_entry["type"] = "api"
    auth_entry["key"] = key
    auth_entry["target"] = target
    auth_entry["baseURL"] = base_url
    auth_entry["model"] = model
    auth_entry["apiMode"] = api_mode
    auth_data[pid] = auth_entry
    save_auth(auth_data)

    # 2. Update opencode.jsonc
    providers_dict = config_data.get("provider", {})
    if not isinstance(providers_dict, dict):
        providers_dict = {}

    if target in ("all", "opencode"):
        prov_item = providers_dict.get(pid, {})
        prov_item["name"] = name
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
        providers_dict[pid] = prov_item
        config_data["provider"] = providers_dict
    else:  # target == "agy", remove from opencode config
        if pid in providers_dict:
            del providers_dict[pid]
            config_data["provider"] = providers_dict
        if pid in config_data.get("disabled_providers", []):
            config_data["disabled_providers"] = [x for x in config_data["disabled_providers"] if x != pid]
            if not config_data["disabled_providers"]:
                config_data.pop("disabled_providers", None)
    save_config(config_data)

    # 3. Update agy settings.json
    agy_providers = agy_data.get("providers", {})
    if not isinstance(agy_providers, dict):
        agy_providers = {}

    if target in ("all", "agy"):
        agy_entry = agy_providers.get(pid, {})
        agy_entry["apiKey"] = key
        agy_entry["baseURL"] = base_url
        agy_entry["model"] = model
        agy_entry["apiMode"] = api_mode
        agy_providers[pid] = agy_entry
        agy_data["providers"] = agy_providers
    else:  # target == "opencode", remove from agy
        if pid in agy_providers:
            del agy_providers[pid]
            agy_data["providers"] = agy_providers
        if pid in agy_data.get("disabled_providers", []):
            agy_data["disabled_providers"] = [x for x in agy_data["disabled_providers"] if x != pid]
            if not agy_data["disabled_providers"]:
                agy_data.pop("disabled_providers", None)
    save_agy_settings(agy_data)

def remove_provider(pid, target="all"):
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    found = False

    if target in ("all", "opencode"):
        if isinstance(config_data.get("provider"), dict) and pid in config_data["provider"]:
            del config_data["provider"][pid]
            found = True
        dis_list = config_data.get("disabled_providers", [])
        if pid in dis_list:
            config_data["disabled_providers"] = [x for x in dis_list if x != pid]
            if not config_data["disabled_providers"]:
                config_data.pop("disabled_providers", None)
            found = True
        save_config(config_data)

    if target in ("all", "agy"):
        if isinstance(agy_data.get("providers"), dict) and pid in agy_data["providers"]:
            del agy_data["providers"][pid]
            found = True
        agy_dis_list = agy_data.get("disabled_providers", [])
        if pid in agy_dis_list:
            agy_data["disabled_providers"] = [x for x in agy_dis_list if x != pid]
            if not agy_data["disabled_providers"]:
                agy_data.pop("disabled_providers", None)
            found = True
        save_agy_settings(agy_data)

    if pid in auth_data:
        cur_target = auth_data[pid].get("target", "all")
        if target == "all" or cur_target == target:
            del auth_data[pid]
            found = True
        elif target == "opencode" and cur_target == "all":
            auth_data[pid]["target"] = "agy"
            auth_data[pid].pop("disabled_opencode", None)
            found = True
        elif target == "agy" and cur_target == "all":
            auth_data[pid]["target"] = "opencode"
            auth_data[pid].pop("disabled_agy", None)
            found = True
        save_auth(auth_data)

    return found

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
        is_dis_oc = is_provider_disabled_opencode(pid, config_data, auth_data)
        is_dis_agy = is_provider_disabled_agy(pid, agy_data, auth_data)
        is_dis = is_provider_disabled(pid, config_data, auth_data, agy_data, target=details["target"])
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
            st_oc_txt = "\033[31mNONAKTIF\033[0m" if is_dis_oc else "\033[32mAKTIF\033[0m"
            st_agy_txt = "\033[31mNONAKTIF\033[0m" if is_dis_agy else "\033[32mAKTIF\033[0m"
            custom_details.append(f"  • \033[1m{pid:<10}\033[0m: Target=\033[36m{tgt_display}\033[0m [OC:{st_oc_txt}|AGY:{st_agy_txt}] | BaseURL=\033[33m{base_show}\033[0m | Model=\033[32m{mod_show}\033[0m | Mode=\033[35m{mode_full}\033[0m")

    print("-" * 90)
    if custom_details:
        print("\n\033[1m🌐 Detail Konfigurasi Endpoint & Parameter Provider:\033[0m")
        for cd in custom_details:
            print(cd)

elif cmd == "get":
    if len(sys.argv) < 3:
        print("Usage: get <provider> [target]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() else "auto"
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)
    if details["key"]:
        m = mask_key(details["key"])
        if is_provider_disabled(provider, config_data, auth_data, agy_data, target=target):
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
    is_dis_oc = is_provider_disabled_opencode(provider, config_data, auth_data)
    is_dis_agy = is_provider_disabled_agy(provider, agy_data, auth_data)
    is_dis = is_provider_disabled(provider, config_data, auth_data, agy_data, target=details["target"])
    status_str = "NONAKTIF" if is_dis else ("AKTIF" if details["key"] else "BELUM_DIATUR")
    status_oc_str = "NONAKTIF" if is_dis_oc else ("AKTIF" if details["key"] else "BELUM_DIATUR")
    status_agy_str = "NONAKTIF" if is_dis_agy else ("AKTIF" if details["key"] else "BELUM_DIATUR")
    mode_info = API_MODES.get(details["api_mode"], {"label": details["api_mode"], "desc": ""})
    target_name = TARGET_TOOLS.get(details["target"], details["target"])

    print(f"ID:{details['id']}")
    print(f"NAMA:{details['name']}")
    print(f"STATUS:{status_str}")
    print(f"STATUS_OPENCODE:{status_oc_str}")
    print(f"STATUS_AGY:{status_agy_str}")
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
    auth_entry.pop("disabled_opencode", None)
    auth_entry.pop("disabled_agy", None)
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
    elif target == "agy":
        if isinstance(config_data.get("provider"), dict) and provider in config_data["provider"]:
            del config_data["provider"][provider]
    save_config(config_data)

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
        agy_entry.pop("disabled", None)
        agy_providers[provider] = agy_entry
        agy_data["providers"] = agy_providers
        save_agy_settings(agy_data)
    elif target == "opencode":
        if isinstance(agy_data.get("providers"), dict) and provider in agy_data["providers"]:
            del agy_data["providers"][provider]
            save_agy_settings(agy_data)

    # 4. Enable provider for target
    set_provider_disabled(provider, disabled=False, target=target)

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

elif cmd in ("tool-list", "tool_list", "list-tool"):
    if len(sys.argv) < 3:
        print("Usage: tool-list <opencode|agy>")
        sys.exit(1)
    tool = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()

    all_pids = list(KNOWN_PROVIDERS.keys())
    custom_sources = (
        set(auth_data.keys()) |
        set(config_data.get("provider", {}).keys() if isinstance(config_data.get("provider"), dict) else []) |
        set(agy_data.get("providers", {}).keys() if isinstance(agy_data.get("providers"), dict) else [])
    )
    for p in sorted(custom_sources):
        if p not in all_pids:
            all_pids.append(p)

    results = []
    for pid in all_pids:
        details = get_provider_details(pid, auth_data, config_data, agy_data)
        has_k = bool(details["key"])

        is_conn = False
        if tool == "opencode":
            has_cfg = isinstance(config_data.get("provider"), dict) and pid in config_data["provider"]
            is_conn = (details["target"] in ("all", "opencode")) and (has_k or has_cfg)
            is_dis = is_provider_disabled_opencode(pid, config_data, auth_data)
        else:  # agy
            has_agy = isinstance(agy_data.get("providers"), dict) and pid in agy_data["providers"]
            is_conn = (details["target"] in ("all", "agy")) and (has_k or has_agy)
            is_dis = is_provider_disabled_agy(pid, agy_data, auth_data)

        if is_conn:
            st = "NONAKTIF" if is_dis else "AKTIF"
            mode_lbl = API_MODES.get(details["api_mode"], {}).get("label", details["api_mode"])
            m_key = mask_key(details["key"]) if has_k else "(belum ada key)"
            m_mod = details["model"] or "(bawaan)"
            m_url = details["base_url"] or "(default)"
            results.append(f"{pid}|{details['name']}|{st}|{details['target']}|{mode_lbl}|{m_key}|{m_mod}|{m_url}")

    if results:
        print("\n".join(results))
    else:
        print("")

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
        if isinstance(config_data.get("provider"), dict) and provider in config_data["provider"]:
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

elif cmd == "target":
    # Usage: target <provider> <opencode|agy|all>
    if len(sys.argv) < 4:
        print("Usage: target <provider> <opencode|agy|all>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    target = sys.argv[3].lower()
    if target not in TARGET_TOOLS:
        print(f"Error: Target tidak valid '{target}'. Pilih: opencode, agy, all")
        sys.exit(1)
    set_provider_target(provider, target)
    print(f"TARGET_SET:{provider}:{target}")

elif cmd in ("del", "remove", "rm"):
    if len(sys.argv) < 3:
        print("Usage: remove <provider> [target]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() else "all"
    if target not in TARGET_TOOLS:
        target = "all"
    found = remove_provider(provider, target)
    if found:
        print(f"DELETED:{provider}:{target}")
    else:
        print(f"NOT_FOUND:{provider}")

elif cmd == "enable":
    if len(sys.argv) < 3:
        print("Usage: enable <provider> [target]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)
    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() else details["target"]
    if target not in TARGET_TOOLS:
        target = details["target"] or "all"

    if not is_provider_disabled(provider, config_data, auth_data, agy_data, target=target):
        print(f"ALREADY_ENABLED:{provider}:{target}")
    else:
        set_provider_disabled(provider, disabled=False, target=target)
        print(f"ENABLED:{provider}:{target}")

elif cmd == "disable":
    if len(sys.argv) < 3:
        print("Usage: disable <provider> [target]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)
    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() else details["target"]
    if target not in TARGET_TOOLS:
        target = details["target"] or "all"

    if is_provider_disabled(provider, config_data, auth_data, agy_data, target=target):
        print(f"ALREADY_DISABLED:{provider}:{target}")
    else:
        set_provider_disabled(provider, disabled=True, target=target)
        print(f"DISABLED:{provider}:{target}")

elif cmd == "toggle":
    if len(sys.argv) < 3:
        print("Usage: toggle <provider> [target]")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    details = get_provider_details(provider, auth_data, config_data, agy_data)
    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() else details["target"]
    if target not in TARGET_TOOLS:
        target = details["target"] or "all"

    if is_provider_disabled(provider, config_data, auth_data, agy_data, target=target):
        set_provider_disabled(provider, disabled=False, target=target)
        print(f"ENABLED:{provider}:{target}")
    else:
        set_provider_disabled(provider, disabled=True, target=target)
        print(f"DISABLED:{provider}:{target}")

elif cmd == "is_disabled":
    if len(sys.argv) < 3:
        print("0")
        sys.exit(0)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    config_data = load_config()
    agy_data = load_agy_settings()
    target = sys.argv[3].lower() if len(sys.argv) > 3 and sys.argv[3].strip() else "auto"
    print("1" if is_provider_disabled(provider, config_data, auth_data, agy_data, target=target) else "0")

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
        is_dis = is_provider_disabled(pid, config_data, auth_data, agy_data, target=details["target"])

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

        if is_provider_disabled(pid, config_data, auth_data, agy_data, target=details["target"]):
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

        local cur_name cur_status cur_st_oc cur_st_agy cur_target cur_target_name cur_base cur_model cur_mode cur_mode_name cur_key
        cur_name=$(echo "$p_info" | grep "^NAMA:" | cut -d':' -f2-)
        cur_status=$(echo "$p_info" | grep "^STATUS:" | cut -d':' -f2-)
        cur_st_oc=$(echo "$p_info" | grep "^STATUS_OPENCODE:" | cut -d':' -f2)
        cur_st_agy=$(echo "$p_info" | grep "^STATUS_AGY:" | cut -d':' -f2)
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
        echo -e "  • Status Provider : ${GREEN}${cur_status}${RESET} (OpenCode: ${CYAN}${cur_st_oc}${RESET}, Antigravity agy: ${MAGENTA}${cur_st_agy}${RESET})"
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
        echo -e "  ${CYAN}8)${RESET} ⚡ Aktifkan / Nonaktifkan Provider Ini (OpenCode / AGY / Keduanya)"
        echo -e "  ${RED}9)${RESET} 🗑️  Hapus Provider Ini (OpenCode saja / AGY saja / Keduanya)"
        echo -e "  ${YELLOW}0)${RESET} Selesai / Kembali ke Menu Utama"
        echo ""
        read -r -p "Pilihan Anda [0-9]: " edit_field_choice

        case "$edit_field_choice" in
            1)
                echo ""
                echo -e "${BOLD}Pilih Target Integrasi AI Baru untuk '$p_id':${RESET}"
                echo -e "  ${GREEN}1)${RESET} OpenCode saja (v1 & v2)      (Terapkan ke ~/.config/opencode, hapus dari agy)"
                echo -e "  ${MAGENTA}2)${RESET} Antigravity CLI saja (agy)   (Terapkan ke ~/.gemini/antigravity-cli, hapus dari opencode)"
                echo -e "  ${CYAN}3)${RESET} Keduanya / Universal         (Disinkronkan ke OpenCode & agy)"
                read -r -p "Pilih target [1-3, Enter untuk tetap]: " n_t_choice
                new_tgt=""
                case "$n_t_choice" in
                    1) new_tgt="opencode" ;;
                    2) new_tgt="agy" ;;
                    3) new_tgt="all" ;;
                    *) new_tgt="$cur_target" ;;
                esac
                run_python_helper "target" "$p_id" "$new_tgt" >/dev/null
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
            8)
                echo ""
                echo -e "${BOLD}Pilih Lingkup untuk Mengubah Status (Enable / Disable):${RESET}"
                echo -e "  ${GREEN}1)${RESET} OpenCode saja"
                echo -e "  ${MAGENTA}2)${RESET} Antigravity CLI (agy) saja"
                echo -e "  ${CYAN}3)${RESET} Keduanya (Semua)"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                read -r -p "Pilihan target [0-3]: " tog_tgt_pick
                t_scope=""
                case "$tog_tgt_pick" in
                    1) t_scope="opencode" ;;
                    2) t_scope="agy" ;;
                    3) t_scope="all" ;;
                    *) t_scope="" ;;
                esac
                if [ -n "$t_scope" ]; then
                    res=$(run_python_helper "toggle" "$p_id" "$t_scope")
                    log_ok "Status '$p_id' berhasil diubah: $res"
                    sleep 1
                fi
                ;;
            9)
                echo ""
                echo -e "${BOLD}${RED}Pilih Lingkup Penghapusan Provider '$p_id':${RESET}"
                echo -e "  ${YELLOW}1)${RESET} Hapus dari OpenCode saja (Tetap ada di Antigravity agy)"
                echo -e "  ${YELLOW}2)${RESET} Hapus dari Antigravity (agy) saja (Tetap ada di OpenCode)"
                echo -e "  ${RED}3)${RESET} Hapus dari Keduanya / Seluruhnya (Hapus Total)"
                echo -e "  ${GREEN}0)${RESET} Batal"
                read -r -p "Pilihan penghapusan [0-3]: " del_pick
                del_tgt=""
                case "$del_pick" in
                    1) del_tgt="opencode" ;;
                    2) del_tgt="agy" ;;
                    3) del_tgt="all" ;;
                    *) del_tgt="" ;;
                esac
                if [ -n "$del_tgt" ]; then
                    read -r -p "Yakin ingin menghapus provider '$p_id' [Target: $del_tgt]? (y/N): " c_del
                    if [[ "$c_del" =~ ^[Yy]$ ]]; then
                        res=$(run_python_helper "remove" "$p_id" "$del_tgt")
                        log_ok "Provider '$p_id' berhasil dihapus [Target: $del_tgt]"
                        sleep 1
                        break
                    fi
                fi
                ;;
            0)
                break
                ;;
        esac
    done
}

manage_tool_providers_menu() {
    local tool="$1"
    local tool_title
    local tool_model
    local tool_loc

    while true; do
        clear 2>/dev/null || true
        if [ "$tool" = "opencode" ]; then
            tool_title="OpenCode (v1 & v2)"
            tool_model=$(run_python_helper "model")
            tool_loc="~/.config/opencode/opencode.jsonc & auth.json"
        else
            tool_title="Antigravity CLI (agy)"
            tool_model=$(run_python_helper "model-agy")
            tool_loc="~/.gemini/antigravity-cli/settings.json"
        fi

        echo -e "${BOLD}${CYAN}========================================================================================${RESET}"
        echo -e "${BOLD}         🎛️  MANAJEMEN PROVIDER & KONEKSI: ${tool_title}         ${RESET}"
        echo -e "${BOLD}${CYAN}========================================================================================${RESET}"
        echo -e "  🎯 Default Model Aktif : ${GREEN}${tool_model:-Belum diatur}${RESET}"
        echo -e "  📁 Berkas Konfigurasi  : ${YELLOW}${tool_loc}${RESET}"
        echo -e "${BOLD}${CYAN}----------------------------------------------------------------------------------------${RESET}"
        echo -e "${BOLD}Daftar Provider yang Terhubung ke ${tool_title}:${RESET}"
        echo ""

        local raw_list
        raw_list=$(run_python_helper "tool-list" "$tool")

        declare -A prov_idx_map
        declare -A prov_name_map
        declare -A prov_stat_map
        declare -A prov_tgt_map
        local count=0

        if [ -z "$raw_list" ]; then
            echo -e "  ${YELLOW}(Belum ada provider yang terhubung ke ${tool_title})${RESET}"
            echo -e "  ${DIM}Gunakan pilihan [1] di bawah untuk menambahkan API Key provider baru ke ${tool_title}.${RESET}"
        else
            printf "  ${BOLD}%-4s %-12s %-18s %-14s %-14s %-18s %s${RESET}\n" "NO" "PROVIDER" "NAMA" "STATUS" "API MODE" "KEY (MASKED)" "MODEL"
            echo "  --------------------------------------------------------------------------------------------"
            while IFS='|' read -r p_id p_name p_stat p_tgt p_mode p_key p_mod p_url; do
                [ -z "$p_id" ] && continue
                count=$((count + 1))
                prov_idx_map[$count]="$p_id"
                prov_name_map[$count]="$p_name"
                prov_stat_map[$count]="$p_stat"
                prov_tgt_map[$count]="$p_tgt"
                local st_colored
                if [ "$p_stat" = "AKTIF" ]; then
                    st_colored="${GREEN}[ AKTIF ]   ${RESET}"
                else
                    st_colored="${RED}[ NONAKTIF ]${RESET}"
                fi
                printf "  ${CYAN}%-4s${RESET} %-12s %-18s %b %-14s %-18s %s\n" \
                    "$count)" "$p_id" "${p_name:0:17}" "$st_colored" "${p_mode:0:13}" "$p_key" "$p_mod"
            done <<< "$raw_list"
        fi

        echo ""
        echo -e "${BOLD}${CYAN}----------------------------------------------------------------------------------------${RESET}"
        echo -e "${BOLD}Pilihan Aksi untuk ${tool_title}:${RESET}"
        echo -e "  ${GREEN}1)${RESET} ➕ ${BOLD}Tambah Provider Baru ke ${tool_title}${RESET} (Add Provider)"
        echo -e "  ${RED}2)${RESET} 🗑️  ${BOLD}Hapus Provider dari ${tool_title}${RESET} (Apus Provider)"
        echo -e "  ${CYAN}3)${RESET} ⚡ Aktifkan / Nonaktifkan Provider (Enable / Disable)"
        echo -e "  ${MAGENTA}4)${RESET} 🎯 Ubah Default Model untuk ${tool_title}"
        echo -e "  ${YELLOW}5)${RESET} ✏️  Edit Detail Parameter Provider (Base URL, Key, Mode)"
        echo -e "  ${GREEN}6)${RESET} 🔍 Uji Koneksi Provider di ${tool_title}"
        echo -e "  ${YELLOW}0)${RESET} ↩️  Kembali"
        echo ""
        read -r -p "Pilihan Anda [0-6]: " act_choice

        case "$act_choice" in
            1)
                echo ""
                echo -e "${BOLD}${GREEN}======================================================================${RESET}"
                echo -e "${BOLD}         ➕ Tambah Provider Baru ke ${tool_title}                      ${RESET}"
                echo -e "${BOLD}${GREEN}======================================================================${RESET}"
                echo -e "Pilih Provider yang ingin dikoneksikan ke ${tool_title}:"
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
                read -r -p "Pilih provider [0-10]: " add_p_choice

                new_pid=""
                case "$add_p_choice" in
                    1) new_pid="google" ;;
                    2) new_pid="anthropic" ;;
                    3) new_pid="openai" ;;
                    4) new_pid="deepseek" ;;
                    5) new_pid="openrouter" ;;
                    6) new_pid="groq" ;;
                    7) new_pid="mistral" ;;
                    8) new_pid="xai" ;;
                    9) new_pid="bynara" ;;
                    10)
                        read -r -p "Masukkan ID provider (contoh: together, ollama, cohere): " new_pid
                        new_pid=$(echo "$new_pid" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                        ;;
                    *) new_pid="" ;;
                esac

                if [ -n "$new_pid" ]; then
                    cur_key=$(run_python_helper "get" "$new_pid")
                    echo ""
                    echo -e "Masukkan API Key untuk ${BOLD}${CYAN}$new_pid${RESET}:"
                    if [ -n "$cur_key" ]; then
                        echo -e "Key tersimpan saat ini: ${GREEN}$cur_key${RESET}"
                        echo -e "${DIM}(Tekan Enter langsung jika ingin menggunakan key ini, atau ketik key baru)${RESET}"
                    else
                        echo -e "${DIM}(Input disembunyikan untuk privasi. Tekan Enter jika selesai)${RESET}"
                    fi
                    read -r -s in_key
                    echo ""
                    if [ -z "$in_key" ] && [ -n "$cur_key" ]; then
                        in_key=$(python3 -c "import json, os; p=os.path.expanduser('~/.local/share/opencode/auth.json'); d=json.load(open(p)) if os.path.exists(p) else {}; print(d.get('$new_pid', {}).get('key', ''))")
                    fi

                    if [ -z "$in_key" ]; then
                        log_warn "Penambahan dibatalkan (API key kosong)."
                        sleep 1
                        continue
                    fi

                    echo ""
                    echo -e "${BOLD}Target Penerapan Provider:${RESET}"
                    echo -e "  ${GREEN}1)${RESET} ${tool_title} saja (Hanya aktif di tool ini)"
                    echo -e "  ${CYAN}2)${RESET} Keduanya / Universal (OpenCode & Antigravity agy)"
                    read -r -p "Pilih target [1-2, default 1]: " in_tgt_pick
                    target_to_save="$tool"
                    [ "$in_tgt_pick" = "2" ] && target_to_save="all"

                    res=$(run_python_helper "set" "$new_pid" "$in_key" "$target_to_save")
                    if [[ "$res" == OK:* ]]; then
                        log_ok "Provider '$new_pid' berhasil ditambahkan ke ${tool_title}!"
                        read -r -p "Uji koneksi API key sekarang? (y/N): " t_now
                        if [[ "$t_now" =~ ^[Yy]$ ]]; then
                            echo -e "${CYAN}Menguji koneksi ke $new_pid...${RESET}"
                            run_python_helper "test" "$new_pid"
                            echo ""
                        fi
                    else
                        log_err "Gagal menambahkan provider: $res"
                    fi
                    sleep 1
                fi
                ;;

            2)
                # Apus / Hapus Provider dari Tool ini
                if [ "$count" -eq 0 ]; then
                    echo ""
                    log_warn "Belum ada provider yang terhubung ke ${tool_title} untuk dihapus."
                    read -r -p "Tekan ENTER untuk kembali..." _
                else
                    echo ""
                    echo -e "${BOLD}${RED}======================================================================${RESET}"
                    echo -e "${BOLD}         🗑️  Hapus Provider dari ${tool_title}                        ${RESET}"
                    echo -e "${BOLD}${RED}======================================================================${RESET}"
                    echo -e "Pilih Provider yang ingin dihapus dari ${tool_title}:"
                    for idx in $(seq 1 "$count"); do
                        local p_item="${prov_idx_map[$idx]}"
                        local p_name_item="${prov_name_map[$idx]}"
                        local p_tgt_item="${prov_tgt_map[$idx]}"
                        echo -e "  ${RED}$idx)${RESET} ${BOLD}$p_item${RESET} ($p_name_item) - Target: ${CYAN}$p_tgt_item${RESET}"
                    done
                    echo -e "  ${YELLOW}0)${RESET} Batal"
                    echo ""
                    read -r -p "Pilih nomor provider [0-$count]: " del_pick_num

                    if [[ "$del_pick_num" =~ ^[0-9]+$ ]] && [ "$del_pick_num" -gt 0 ] && [ "$del_pick_num" -le "$count" ]; then
                        local target_del_pid="${prov_idx_map[$del_pick_num]}"
                        echo ""
                        echo -e "Provider terpilih: ${BOLD}${CYAN}$target_del_pid${RESET}"
                        read -r -p "Yakin ingin menghapus '$target_del_pid' dari ${tool_title}? (y/N): " confirm_del_tool
                        if [[ "$confirm_del_tool" =~ ^[Yy]$ ]]; then
                            res=$(run_python_helper "remove" "$target_del_pid" "$tool")
                            if [[ "$res" == DELETED:* ]]; then
                                log_ok "Provider '$target_del_pid' berhasil dihapus dari ${tool_title}!"
                            else
                                log_warn "Gagal menghapus provider: $res"
                            fi
                            sleep 1
                        fi
                    fi
                fi
                ;;

            3)
                # Toggle / Enable / Disable Provider
                if [ "$count" -eq 0 ]; then
                    echo ""
                    log_warn "Belum ada provider yang terhubung ke ${tool_title}."
                    read -r -p "Tekan ENTER untuk kembali..." _
                else
                    echo ""
                    echo -e "${BOLD}${CYAN}Pilih Provider untuk beralih status (Aktif <-> Nonaktif) di ${tool_title}:${RESET}"
                    for idx in $(seq 1 "$count"); do
                        local p_item="${prov_idx_map[$idx]}"
                        local st_item="${prov_stat_map[$idx]}"
                        echo -e "  ${CYAN}$idx)${RESET} ${BOLD}$p_item${RESET} (Status: $st_item)"
                    done
                    echo -e "  ${YELLOW}0)${RESET} Batal"
                    echo ""
                    read -r -p "Pilih nomor [0-$count]: " tog_pick_num

                    if [[ "$tog_pick_num" =~ ^[0-9]+$ ]] && [ "$tog_pick_num" -gt 0 ] && [ "$tog_pick_num" -le "$count" ]; then
                        local target_tog_pid="${prov_idx_map[$tog_pick_num]}"
                        res=$(run_python_helper "toggle" "$target_tog_pid" "$tool")
                        log_ok "Status '$target_tog_pid' di ${tool_title} berhasil diubah: $res"
                        sleep 1
                    fi
                fi
                ;;

            4)
                # Ubah Default Model
                echo ""
                echo -e "${BOLD}Pilih Preset Model Rekomendasi untuk ${tool_title}:${RESET}"
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
                read -r -p "Pilihan model [0-10]: " mod_choice

                sel_m=""
                case "$mod_choice" in
                    1) sel_m="bynara/glm-5.3-flash" ;;
                    2) sel_m="google/gemini-2.5-flash" ;;
                    3) sel_m="google/gemini-2.5-pro" ;;
                    4) sel_m="anthropic/claude-3-7-sonnet" ;;
                    5) sel_m="anthropic/claude-3-5-sonnet" ;;
                    6) sel_m="deepseek/deepseek-chat" ;;
                    7) sel_m="deepseek/deepseek-reasoner" ;;
                    8) sel_m="openai/gpt-4o" ;;
                    9) sel_m="openrouter/auto" ;;
                    10)
                        read -r -p "Masukkan model ID lengkap (contoh: provider/model-name): " sel_m
                        ;;
                    *) sel_m="" ;;
                esac

                if [ -n "$sel_m" ]; then
                    if [ "$tool" = "opencode" ]; then
                        run_python_helper "model" "$sel_m" >/dev/null
                        log_ok "Default model OpenCode berhasil diatur ke '$sel_m'!"
                    else
                        run_python_helper "model-agy" "$sel_m" >/dev/null
                        log_ok "Default model Antigravity (agy) berhasil diatur ke '$sel_m'!"
                    fi
                    sleep 1
                fi
                ;;

            5)
                # Edit Detail Provider
                if [ "$count" -eq 0 ]; then
                    echo ""
                    log_warn "Belum ada provider yang terhubung ke ${tool_title}."
                    read -r -p "Tekan ENTER untuk kembali..." _
                else
                    echo ""
                    echo -e "${BOLD}Pilih Provider yang ingin diedit parameternya:${RESET}"
                    for idx in $(seq 1 "$count"); do
                        local p_item="${prov_idx_map[$idx]}"
                        echo -e "  ${CYAN}$idx)${RESET} $p_item"
                    done
                    echo -e "  ${YELLOW}0)${RESET} Batal"
                    echo ""
                    read -r -p "Pilih nomor [0-$count]: " ed_pick_num

                    if [[ "$ed_pick_num" =~ ^[0-9]+$ ]] && [ "$ed_pick_num" -gt 0 ] && [ "$ed_pick_num" -le "$count" ]; then
                        local target_ed_pid="${prov_idx_map[$ed_pick_num]}"
                        edit_provider_menu "$target_ed_pid"
                    fi
                fi
                ;;

            6)
                # Uji Koneksi
                if [ "$count" -eq 0 ]; then
                    echo ""
                    log_warn "Belum ada provider yang terhubung ke ${tool_title}."
                    read -r -p "Tekan ENTER untuk kembali..." _
                else
                    echo ""
                    echo -e "${CYAN}Menguji koneksi seluruh provider aktif di ${tool_title}...${RESET}"
                    for idx in $(seq 1 "$count"); do
                        local test_pid="${prov_idx_map[$idx]}"
                        echo -e "• Menguji $test_pid..."
                        run_python_helper "test" "$test_pid"
                    done
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;

            0)
                break
                ;;

            *)
                echo -e "${RED}Pilihan tidak valid!${RESET}"
                sleep 1
                ;;
        esac
    done
}

select_tool_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo -e "${BOLD}         🎛️  PILIH TOOL AI UNTUK MENGELOLA PROVIDER & API KEY          ${RESET}"
        echo -e "${BOLD}${CYAN}======================================================================${RESET}"
        echo ""
        echo -e "Silakan pilih Tool AI yang ingin Anda kelola provider-nya:"
        echo ""
        echo -e "  ${GREEN}1)${RESET} 🤖 ${BOLD}OpenCode (v1 & v2)${RESET}"
        echo -e "      Kelola provider yang terhubung ke OpenCode CLI & Web"
        echo -e "      (Berkas: ~/.config/opencode/opencode.jsonc & auth.json)"
        echo ""
        echo -e "  ${MAGENTA}2)${RESET} 🪐 ${BOLD}Antigravity CLI (agy)${RESET}"
        echo -e "      Kelola provider yang terhubung ke Antigravity CLI"
        echo -e "      (Berkas: ~/.gemini/antigravity-cli/settings.json)"
        echo ""
        echo -e "  ${YELLOW}0)${RESET} ↩️  Kembali ke Menu Utama"
        echo ""
        read -r -p "Pilihan Anda [0-2]: " tool_choice

        case "$tool_choice" in
            1) manage_tool_providers_menu "opencode" ;;
            2) manage_tool_providers_menu "agy" ;;
            0) break ;;
            *) echo -e "${RED}Pilihan tidak valid!${RESET}"; sleep 1 ;;
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
        echo -e "  ${BOLD}${GREEN}1)${RESET} 🎛️  ${BOLD}Kelola Provider per Tool AI${RESET} (Pilih OpenCode atau AGY -> Cek Konek, Add, Apus)"
        echo -e "  ${GREEN}2)${RESET} 🔑 Tambah / Perbarui API Key Provider (Quick Setup)"
        echo -e "  ${MAGENTA}3)${RESET} 🚀 Setup Provider Lanjutan (Target OpenCode/AGY, Base URL, Model, Mode)"
        echo -e "  ${CYAN}4)${RESET} ✏️  Edit / Ubah Konfigurasi Provider Terpasang"
        echo -e "  ${CYAN}5)${RESET} ⚡ Aktifkan / Nonaktifkan Provider (Enable / Disable per Target / Keduanya)"
        echo -e "  ${GREEN}6)${RESET} 🎯 Pilih Default Model (OpenCode & Antigravity agy)"
        echo -e "  ${CYAN}7)${RESET} 🧪 Uji Koneksi & Validasi API Key"
        echo -e "  ${CYAN}8)${RESET} 🔍 Detail Lengkap Provider (Inspect Config & Parameter)"
        echo -e "  ${CYAN}9)${RESET} 🔄 Sinkronkan ke Shell Environment (~/.termux_ai_env)"
        echo -e "  ${RED}10)${RESET} 🗑️  Hapus API Key / Provider (OpenCode saja / AGY saja / Keduanya)"
        echo -e "  ${BOLD}${CYAN}11)${RESET} 🔀 Atur Target Integrasi Provider (Terapkan ke OpenCode / AGY / Keduanya)"
        echo -e "  ${YELLOW}0)${RESET} Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-11, oc, agy]: " menu_choice

        case "$menu_choice" in
            1|tool|tools|t)
                select_tool_menu
                ;;
            oc|opencode)
                manage_tool_providers_menu "opencode"
                ;;
            agy|antigravity)
                manage_tool_providers_menu "agy"
                ;;
            2)
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

            3)
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

            4)
                # Edit / Ubah Konfigurasi Provider Terpasang
                echo ""
                echo -e "${BOLD}${CYAN}======================================================================${RESET}"
                echo -e "${BOLD}         ✏️  Edit / Ubah Konfigurasi Provider (OpenCode & AGY)        ${RESET}"
                echo -e "${BOLD}${CYAN}======================================================================${RESET}"
                echo ""

                cfg_list=$(run_python_helper "configured-list")

                if [ -z "$cfg_list" ]; then
                    log_warn "Belum ada provider yang terkonfigurasi. Silakan tambah provider terlebih dahulu melalui Menu 1, 2, atau 3."
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

            5)
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
                    local p_stat_info cur_st_oc cur_st_agy cur_tgt_info
                    p_stat_info=$(run_python_helper "info" "$target_prov")
                    cur_st_oc=$(echo "$p_stat_info" | grep "^STATUS_OPENCODE:" | cut -d':' -f2)
                    cur_st_agy=$(echo "$p_stat_info" | grep "^STATUS_AGY:" | cut -d':' -f2)
                    cur_tgt_info=$(echo "$p_stat_info" | grep "^TARGET:" | cut -d':' -f2)

                    echo ""
                    echo -e "${BOLD}Status Provider '$target_prov' (Target saat ini: ${CYAN}${cur_tgt_info}${RESET}):${RESET}"
                    echo -e "  • OpenCode (v1/v2)       : ${cur_st_oc:-BELUM_DIATUR}"
                    echo -e "  • Antigravity CLI (agy)  : ${cur_st_agy:-BELUM_DIATUR}"
                    echo ""
                    echo -e "${BOLD}Pilih Lingkup Aksi Status:${RESET}"
                    echo -e "  ${GREEN}1)${RESET} OpenCode saja"
                    echo -e "  ${MAGENTA}2)${RESET} Antigravity CLI (agy) saja"
                    echo -e "  ${CYAN}3)${RESET} Keduanya (Universal)"
                    echo -e "  ${YELLOW}0)${RESET} Batal"
                    read -r -p "Pilihan lingkup [0-3, default 3]: " l_choice
                    target_scope="all"
                    case "$l_choice" in
                        1) target_scope="opencode" ;;
                        2) target_scope="agy" ;;
                        3) target_scope="all" ;;
                        0) target_scope="" ;;
                        *) target_scope="all" ;;
                    esac

                    if [ -n "$target_scope" ]; then
                        is_dis=$(run_python_helper "is_disabled" "$target_prov" "$target_scope")
                        echo ""
                        if [ "$is_dis" = "1" ]; then
                            echo -e "Status [$target_scope]: ${RED}[ NONAKTIF ]${RESET}"
                            read -r -p "Aktifkan provider '$target_prov' untuk [$target_scope]? (Y/n): " confirm_act
                            if [[ ! "$confirm_act" =~ ^[Nn]$ ]]; then
                                res=$(run_python_helper "enable" "$target_prov" "$target_scope")
                                log_ok "Provider '$target_prov' berhasil diaktifkan [Target: $target_scope]!"
                            fi
                        else
                            echo -e "Status [$target_scope]: ${GREEN}[ AKTIF / SIAP ]${RESET}"
                            read -r -p "Nonaktifkan provider '$target_prov' untuk [$target_scope]? (y/N): " confirm_dis
                            if [[ "$confirm_dis" =~ ^[Yy]$ ]]; then
                                res=$(run_python_helper "disable" "$target_prov" "$target_scope")
                                log_ok "Provider '$target_prov' berhasil dinonaktifkan [Target: $target_scope]."
                                cur_mod=$(run_python_helper "model")
                                if [[ "$cur_mod" == "$target_prov/"* ]] && [ "$target_scope" != "agy" ]; then
                                    log_warn "Perhatian: Model default aktif OpenCode saat ini ($cur_mod) menggunakan provider '$target_prov'."
                                    log_warn "Disarankan untuk mengganti default model melalui Menu 6."
                                fi
                            fi
                        fi
                    fi
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;

            6)
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

            7)
                echo ""
                log_info "Memeriksa dan menguji validitas seluruh provider aktif..."
                run_python_helper "test" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;

            8)
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

            9)
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

            10)
                echo ""
                read -r -p "Masukkan nama provider yang ingin dihapus (contoh: openai): " del_prov
                del_prov=$(echo "$del_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                if [ -n "$del_prov" ]; then
                    local p_del_info cur_del_target
                    p_del_info=$(run_python_helper "info" "$del_prov")
                    cur_del_target=$(echo "$p_del_info" | grep "^TARGET:" | cut -d':' -f2)
                    echo ""
                    echo -e "${BOLD}Target integrasi saat ini untuk '$del_prov': ${CYAN}${cur_del_target:-Universal}${RESET}"
                    echo -e "${BOLD}Pilih Lingkup Penghapusan Provider:${RESET}"
                    echo -e "  ${YELLOW}1)${RESET} Hapus dari OpenCode saja (Tetap ada di Antigravity agy)"
                    echo -e "  ${YELLOW}2)${RESET} Hapus dari Antigravity (agy) saja (Tetap ada di OpenCode)"
                    echo -e "  ${RED}3)${RESET} Hapus dari Keduanya / Seluruhnya (Hapus Total)"
                    echo -e "  ${GREEN}0)${RESET} Batal"
                    read -r -p "Pilihan penghapusan [0-3, default 3]: " del_scope_pick
                    del_scope="all"
                    case "$del_scope_pick" in
                        1) del_scope="opencode" ;;
                        2) del_scope="agy" ;;
                        3) del_scope="all" ;;
                        0) del_scope="" ;;
                        *) del_scope="all" ;;
                    esac
                    if [ -n "$del_scope" ]; then
                        read -r -p "Apakah Anda yakin ingin menghapus provider '$del_prov' [Lingkup: $del_scope]? (y/N): " confirm_del
                        if [[ "$confirm_del" =~ ^[Yy]$ ]]; then
                            res=$(run_python_helper "remove" "$del_prov" "$del_scope")
                            if [[ "$res" == DELETED:* ]]; then
                                log_ok "Provider '$del_prov' berhasil dihapus [Target: $del_scope]"
                            else
                                log_warn "Provider '$del_prov' tidak ditemukan dalam sistem"
                            fi
                        fi
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;

            11)
                echo ""
                echo -e "${BOLD}${CYAN}======================================================================${RESET}"
                echo -e "${BOLD}     🔀 Atur Target Integrasi Provider (OpenCode / AGY / Keduanya)    ${RESET}"
                echo -e "${BOLD}${CYAN}======================================================================${RESET}"
                echo ""
                cfg_list=$(run_python_helper "configured-list")
                if [ -z "$cfg_list" ]; then
                    log_warn "Belum ada provider yang terkonfigurasi. Tambah provider terlebih dahulu via Menu 1 atau 2."
                    read -r -p "Tekan ENTER untuk kembali..." _
                    continue
                fi
                echo -e "${BOLD}Pilih Provider yang ingin diatur target penerapannya:${RESET}"
                i=1
                declare -A tgt_prov_map
                while IFS='|' read -r p_id p_name p_tgt p_mode p_model p_url; do
                    [ -z "$p_id" ] && continue
                    tgt_prov_map[$i]="$p_id"
                    echo -e "  ${GREEN}$i)${RESET} ${BOLD}$p_id${RESET} ($p_name) - Target saat ini: ${CYAN}$p_tgt${RESET}"
                    i=$((i + 1))
                done <<< "$cfg_list"
                echo -e "  ${CYAN}C)${RESET} Masukkan ID Provider Kustom Lainnya"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilihan Anda [0-$((i-1)) / C]: " t_pick
                sel_tgt_prov=""
                if [[ "$t_pick" =~ ^[0-9]+$ ]] && [ "$t_pick" -gt 0 ] && [ "$t_pick" -lt "$i" ]; then
                    sel_tgt_prov="${tgt_prov_map[$t_pick]}"
                elif [[ "$t_pick" =~ ^[Cc]$ ]]; then
                    read -r -p "Masukkan ID provider: " sel_tgt_prov
                    sel_tgt_prov=$(echo "$sel_tgt_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                fi

                if [ -n "$sel_tgt_prov" ]; then
                    echo ""
                    echo -e "${BOLD}Pilih Target Integrasi Baru untuk '$sel_tgt_prov':${RESET}"
                    echo -e "  ${GREEN}1)${RESET} OpenCode saja (v1 & v2)      (Terapkan ke ~/.config/opencode, hapus dari agy)"
                    echo -e "  ${MAGENTA}2)${RESET} Antigravity CLI saja (agy)   (Terapkan ke ~/.gemini/antigravity-cli, hapus dari opencode)"
                    echo -e "  ${CYAN}3)${RESET} Keduanya / Universal         (Disinkronkan ke OpenCode & agy)"
                    echo -e "  ${YELLOW}0)${RESET} Batal"
                    read -r -p "Pilihan target baru [0-3]: " n_tgt_choice
                    n_tgt=""
                    case "$n_tgt_choice" in
                        1) n_tgt="opencode" ;;
                        2) n_tgt="agy" ;;
                        3) n_tgt="all" ;;
                        *) n_tgt="" ;;
                    esac
                    if [ -n "$n_tgt" ]; then
                        run_python_helper "target" "$sel_tgt_prov" "$n_tgt" >/dev/null
                        log_ok "Target integrasi untuk '$sel_tgt_prov' berhasil diatur ke '$n_tgt'!"
                    fi
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
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
    tool|tools|select-tool)
        select_tool_menu
        ;;
    opencode|oc)
        manage_tool_providers_menu "opencode"
        ;;
    agy|antigravity)
        manage_tool_providers_menu "agy"
        ;;
    tool-list|list-tool)
        run_python_helper "tool-list" "${2:-opencode}"
        ;;
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
    target|set-target)
        # Usage: config.sh target <provider> <opencode|agy|all>
        if [ -z "$2" ] || [ -z "$3" ]; then
            log_err "Penggunaan: config.sh target <provider> <opencode|agy|all>"
            exit 1
        fi
        res=$(run_python_helper "target" "$2" "$3")
        if [[ "$res" == TARGET_SET:* ]]; then
            p_tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "Target integrasi provider '$2' berhasil diatur ke '$p_tgt'"
        else
            log_err "Gagal mengatur target: $res"
            exit 1
        fi
        ;;
    enable)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh enable <provider> [opencode|agy|all]"
            exit 1
        fi
        target="${3:-}"
        res=$(run_python_helper "enable" "$2" "$target")
        if [[ "$res" == ENABLED:* ]]; then
            p_name=$(echo "$res" | cut -d':' -f2)
            p_tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "Provider '$p_name' berhasil diaktifkan [Target: ${p_tgt:-all}]"
        elif [[ "$res" == ALREADY_ENABLED:* ]]; then
            log_info "Provider '${res#ALREADY_ENABLED:}' sudah dalam status AKTIF"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    disable)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh disable <provider> [opencode|agy|all]"
            exit 1
        fi
        target="${3:-}"
        res=$(run_python_helper "disable" "$2" "$target")
        if [[ "$res" == DISABLED:* ]]; then
            p_name=$(echo "$res" | cut -d':' -f2)
            p_tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "Provider '$p_name' berhasil dinonaktifkan [Target: ${p_tgt:-all}]"
        elif [[ "$res" == ALREADY_DISABLED:* ]]; then
            log_info "Provider '${res#ALREADY_DISABLED:}' sudah dalam status NONAKTIF"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    toggle)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh toggle <provider> [opencode|agy|all]"
            exit 1
        fi
        target="${3:-}"
        res=$(run_python_helper "toggle" "$2" "$target")
        if [[ "$res" == ENABLED:* ]]; then
            p_name=$(echo "$res" | cut -d':' -f2)
            p_tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "Provider '$p_name' diaktifkan [Target: ${p_tgt:-all}]"
        elif [[ "$res" == DISABLED:* ]]; then
            p_name=$(echo "$res" | cut -d':' -f2)
            p_tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "Provider '$p_name' dinonaktifkan [Target: ${p_tgt:-all}]"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    remove|del|rm)
        if [ -z "$2" ]; then
            log_err "Penggunaan: config.sh remove <provider> [opencode|agy|all]"
            exit 1
        fi
        target="${3:-all}"
        res=$(run_python_helper "remove" "$2" "$target")
        if [[ "$res" == DELETED:* ]]; then
            p_name=$(echo "$res" | cut -d':' -f2)
            p_tgt=$(echo "$res" | cut -d':' -f3)
            log_ok "Provider '$p_name' berhasil dihapus [Target: ${p_tgt:-all}]"
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
        echo "  bash config.sh tool                Pilih Tool AI (OpenCode/AGY) untuk kelola provider"
        echo "  bash config.sh opencode            Kelola langsung provider yang konek ke OpenCode"
        echo "  bash config.sh agy                 Kelola langsung provider yang konek ke Antigravity CLI"
        echo "  bash config.sh tool-list [tool]    Daftar provider yang konek ke target (opencode/agy)"
        echo "  bash config.sh list                Tampilkan status provider, target & API Key"
        echo "  bash config.sh info <provider>     Tampilkan detail lengkap endpoint & mode provider"
        echo "  bash config.sh set <provider> <key> [target] [baseURL] [model] [apiMode]"
        echo "                                     Simpan API key dan konfigurasi lanjutan"
        echo "  bash config.sh target <provider> <opencode|agy|all>"
        echo "                                     Terapkan provider ke OpenCode aja, AGY aja, atau keduanya"
        echo "  bash config.sh edit <provider> [target] [baseURL] [model] [apiMode] [key]"
        echo "                                     Edit konfigurasi provider yang terpasang"
        echo "  bash config.sh edit-field <provider> <target|baseurl|model|mode|key> <val>"
        echo "                                     Edit nilai spesifik parameter provider"
        echo "  bash config.sh get <provider> [target]"
        echo "                                     Tampilkan masked key provider"
        echo "  bash config.sh enable <provider> [opencode|agy|all]"
        echo "                                     Aktifkan provider (spesifik OpenCode, AGY, atau keduanya)"
        echo "  bash config.sh disable <provider> [opencode|agy|all]"
        echo "                                     Nonaktifkan provider (spesifik OpenCode, AGY, atau keduanya)"
        echo "  bash config.sh toggle <provider> [opencode|agy|all]"
        echo "                                     Beralih status aktif/nonaktif provider pada target"
        echo "  bash config.sh remove <provider> [opencode|agy|all]"
        echo "                                     Hapus provider dari OpenCode saja, AGY saja, atau keduanya"
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

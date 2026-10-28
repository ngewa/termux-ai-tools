#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Interactive API Key & Provider Setup Wizard
# Manages:
#   - ~/.local/share/opencode/auth.json (API keys per provider)
#   - ~/.config/opencode/opencode.jsonc (Default model)
#   - ~/.termux_ai_env (Optional exported shell environment variables)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
AUTH_FILE="$HOME_DIR/.local/share/opencode/auth.json"
CONFIG_FILE="$HOME_DIR/.config/opencode/opencode.jsonc"
ENV_FILE="$HOME_DIR/.termux_ai_env"

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

# Ensure python3 is available
if ! command -v python3 >/dev/null 2>&1; then
    log_err "Python3 diperlukan untuk mengelola konfigurasi JSON dengan aman."
    echo "Jalankan: pkg install python"
    exit 1
fi

# Ensure parent dirs exist
mkdir -p "$HOME_DIR/.local/share/opencode"
mkdir -p "$HOME_DIR/.config/opencode"

# ------------------------------------------------------------------------------
# Python Helper Core
# ------------------------------------------------------------------------------
run_python_helper() {
    python3 - "$@" << 'EOF'
import sys, os, json, urllib.request, urllib.error, ssl

HOME = os.path.expanduser("~")
AUTH_PATH = os.path.join(HOME, ".local/share/opencode/auth.json")
CONFIG_PATH = os.path.join(HOME, ".config/opencode/opencode.jsonc")
ENV_PATH = os.path.join(HOME, ".termux_ai_env")

KNOWN_PROVIDERS = {
    "google": {
        "name": "Google Gemini",
        "url": "https://aistudio.google.com/app/apikey",
        "env_var": "GEMINI_API_KEY",
        "default_models": ["google/gemini-2.5-flash", "google/gemini-2.5-pro", "google/gemini-2.0-flash"],
        "test_url": "https://generativelanguage.googleapis.com/v1beta/models?key={key}",
        "test_headers": {}
    },
    "anthropic": {
        "name": "Anthropic Claude",
        "url": "https://console.anthropic.com/settings/keys",
        "env_var": "ANTHROPIC_API_KEY",
        "default_models": ["anthropic/claude-3-7-sonnet", "anthropic/claude-3-5-sonnet", "anthropic/claude-3-5-haiku"],
        "test_url": "https://api.anthropic.com/v1/models",
        "test_headers": {"x-api-key": "{key}", "anthropic-version": "2023-06-01"}
    },
    "openai": {
        "name": "OpenAI",
        "url": "https://platform.openai.com/api-keys",
        "env_var": "OPENAI_API_KEY",
        "default_models": ["openai/gpt-4.5-preview", "openai/gpt-4o", "openai/gpt-4o-mini", "openai/o3-mini"],
        "test_url": "https://api.openai.com/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "deepseek": {
        "name": "DeepSeek",
        "url": "https://platform.deepseek.com/api_keys",
        "env_var": "DEEPSEEK_API_KEY",
        "default_models": ["deepseek/deepseek-chat", "deepseek/deepseek-reasoner"],
        "test_url": "https://api.deepseek.com/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "openrouter": {
        "name": "OpenRouter",
        "url": "https://openrouter.ai/keys",
        "env_var": "OPENROUTER_API_KEY",
        "default_models": ["openrouter/auto", "openrouter/anthropic/claude-3.7-sonnet", "openrouter/deepseek/deepseek-r1"],
        "test_url": "https://openrouter.ai/api/v1/auth/key",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "groq": {
        "name": "Groq",
        "url": "https://console.groq.com/keys",
        "env_var": "GROQ_API_KEY",
        "default_models": ["groq/llama-3.3-70b-versatile", "groq/deepseek-r1-distill-llama-70b"],
        "test_url": "https://api.groq.com/openai/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "mistral": {
        "name": "Mistral AI",
        "url": "https://console.mistral.ai/api-keys/",
        "env_var": "MISTRAL_API_KEY",
        "default_models": ["mistral/mistral-large-latest", "mistral/codestral-latest"],
        "test_url": "https://api.mistral.ai/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
    },
    "xai": {
        "name": "xAI (Grok)",
        "url": "https://console.x.ai/",
        "env_var": "XAI_API_KEY",
        "default_models": ["xai/grok-2-latest", "xai/grok-beta"],
        "test_url": "https://api.x.ai/v1/models",
        "test_headers": {"Authorization": "Bearer {key}"}
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

def save_config_model(model_name):
    os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
    data = load_config()
    data["model"] = model_name
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

def mask_key(key):
    if not key:
        return ""
    if len(key) <= 12:
        return key[:3] + "..." + key[-2:]
    return key[:8] + "..." + key[-4:]

# ------------------------------------------------------------------------------
# Commands
# ------------------------------------------------------------------------------
cmd = sys.argv[1] if len(sys.argv) > 1 else "list"

if cmd in ("list", "status"):
    auth_data = load_auth()
    config_data = load_config()
    current_model = config_data.get("model", "(Belum diatur / default bawaan)")

    print("\033[1m\033[36m======================================================================\033[0m")
    print("\033[1m              DAFTAR PROVIDER & STATUS API KEY TERPASANG              \033[0m")
    print("\033[1m\033[36m======================================================================\033[0m")
    print(f"\033[1m🎯 Model Aktif (opencode.jsonc):\033[0m \033[32m{current_model}\033[0m\n")
    print(f"{'PROVIDER':<16} {'NAMA':<20} {'STATUS':<12} {'API KEY (MASKED)':<20}")
    print("-" * 70)

    # List known providers first
    for pid, info in KNOWN_PROVIDERS.items():
        entry = auth_data.get(pid, {})
        has_key = bool(entry.get("key"))
        masked = mask_key(entry.get("key", "")) if has_key else "-"
        status = "\033[32m[ AKTIF ]\033[0m" if has_key else "\033[33m[ BELUM ]\033[0m"
        print(f"{pid:<16} {info['name']:<20} {status:<21} {masked:<20}")

    # Custom providers in auth_data
    for pid, entry in auth_data.items():
        if pid not in KNOWN_PROVIDERS:
            has_key = bool(entry.get("key"))
            masked = mask_key(entry.get("key", "")) if has_key else "-"
            status = "\033[32m[ AKTIF ]\033[0m" if has_key else "\033[33m[ BELUM ]\033[0m"
            print(f"{pid:<16} {'(Custom)':<20} {status:<21} {masked:<20}")
    print("-" * 70)

elif cmd == "get":
    if len(sys.argv) < 3:
        print("Usage: get <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    if provider in auth_data:
        k = auth_data[provider].get("key", "")
        print(mask_key(k))
    else:
        print("")

elif cmd == "set":
    if len(sys.argv) < 4:
        print("Usage: set <provider> <key>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    key = sys.argv[3].strip()
    if not key:
        print("Error: API Key tidak boleh kosong.")
        sys.exit(1)
    auth_data = load_auth()
    auth_data[provider] = {
        "type": "api",
        "key": key
    }
    save_auth(auth_data)
    print(f"OK:{mask_key(key)}")

elif cmd in ("del", "remove", "rm"):
    if len(sys.argv) < 3:
        print("Usage: remove <provider>")
        sys.exit(1)
    provider = sys.argv[2].lower()
    auth_data = load_auth()
    if provider in auth_data:
        del auth_data[provider]
        save_auth(auth_data)
        print(f"DELETED:{provider}")
    else:
        print(f"NOT_FOUND:{provider}")

elif cmd == "model":
    if len(sys.argv) >= 3:
        model_name = sys.argv[2].strip()
        save_config_model(model_name)
        print(f"MODEL_SAVED:{model_name}")
    else:
        config_data = load_config()
        print(config_data.get("model", ""))

elif cmd == "sync-env":
    auth_data = load_auth()
    lines = [
        "# ==============================================================================",
        "# Auto-generated environment variables by Termux AI Tools (config.sh)",
        "# Source this file in your ~/.bashrc: [ -f ~/.termux_ai_env ] && . ~/.termux_ai_env",
        "# =============================================================================="
    ]
    count = 0
    for pid, entry in auth_data.items():
        k = entry.get("key")
        if not k:
            continue
        env_var = KNOWN_PROVIDERS.get(pid, {}).get("env_var", f"{pid.upper()}_API_KEY")
        lines.append(f"export {env_var}=\"{k}\"")
        count += 1
    
    with open(ENV_PATH, 'w', encoding='utf-8') as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(ENV_PATH, 0o600)
    print(f"SYNC_COUNT:{count}")

elif cmd == "test":
    target = sys.argv[2].lower() if len(sys.argv) > 2 else "all"
    auth_data = load_auth()
    
    def test_provider(pid):
        entry = auth_data.get(pid)
        if not entry or not entry.get("key"):
            return "SKIPPED: Belum ada API key terpasang"
        
        info = KNOWN_PROVIDERS.get(pid)
        if not info or not info.get("test_url"):
            return "UNSUPPORTED: Pengujian otomatis belum tersedia untuk provider ini"
        
        key = entry["key"]
        url = info["test_url"].format(key=key)
        headers = {k: v.format(key=key) for k, v in info.get("test_headers", {}).items()}
        headers["User-Agent"] = "TermuxAITools/1.0"
        
        try:
            req = urllib.request.Request(url, headers=headers)
            ctx = ssl.create_default_context()
            with urllib.request.urlopen(req, timeout=6, context=ctx) as resp:
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
wizard_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "        🔑 Termux AI Tools - Config Wizard        "
        echo -e "==================================================${RESET}"
        
        run_python_helper "status"
        echo ""
        echo -e "${BOLD}Pilihan Menu:${RESET}"
        echo -e "  ${GREEN}1)${RESET} Tambah / Perbarui API Key Provider"
        echo -e "  ${GREEN}2)${RESET} Pilih Default Model OpenCode"
        echo -e "  ${CYAN}3)${RESET} Uji Koneksi & Validasi API Key"
        echo -e "  ${CYAN}4)${RESET} Sinkronkan ke Shell Environment (~/.termux_ai_env)"
        echo -e "  ${RED}5)${RESET} Hapus API Key Provider"
        echo -e "  ${YELLOW}0)${RESET} Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-5]: " menu_choice

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
                echo -e "  ${CYAN}9)${RESET} Provider Kustom Lainnya"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilih provider [0-9]: " p_choice
                
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
                    9)
                        read -r -p "Masukkan ID provider (contoh: together, cohere, perplexity): " prov_id
                        prov_id=$(echo "$prov_id" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                        ;;
                    *)
                        prov_id=""
                        ;;
                esac

                if [ -n "$prov_id" ]; then
                    echo ""
                    echo -e "Masukkan API Key untuk ${BOLD}${CYAN}$prov_id${RESET}:"
                    echo -e "${DIM}(Input disembunyikan untuk privasi. Tekan Enter jika selesai)${RESET}"
                    read -r -s input_key
                    echo ""
                    if [ -n "$input_key" ]; then
                        res=$(run_python_helper "set" "$prov_id" "$input_key")
                        if [[ "$res" == OK:* ]]; then
                            masked="${res#OK:}"
                            log_ok "API Key untuk '$prov_id' berhasil disimpan ($masked) ke auth.json"
                            
                            # Ask to test immediately
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
                echo ""
                echo -e "${BOLD}Pilih Preset Model Default OpenCode:${RESET}"
                echo -e "  ${GREEN}1)${RESET} google/gemini-2.5-flash       (Cepat & Hemat Token)"
                echo -e "  ${GREEN}2)${RESET} google/gemini-2.5-pro         (Penalaran Tinggi & Akurat)"
                echo -e "  ${GREEN}3)${RESET} anthropic/claude-3-7-sonnet   (Paling Andal Coding & Refactoring)"
                echo -e "  ${GREEN}4)${RESET} anthropic/claude-3-5-sonnet   (Andal & Stabil)"
                echo -e "  ${GREEN}5)${RESET} deepseek/deepseek-chat        (Sangat Murah & Cerdas)"
                echo -e "  ${GREEN}6)${RESET} deepseek/deepseek-reasoner    (Model Berpikir / R1)"
                echo -e "  ${GREEN}7)${RESET} openai/gpt-4o                 (Multimodal Cepat)"
                echo -e "  ${GREEN}8)${RESET} openrouter/auto               (Rute Otomatis Model Terbaik)"
                echo -e "  ${CYAN}9)${RESET} Input Manual ID Model Kustom"
                echo -e "  ${YELLOW}0)${RESET} Batal"
                echo ""
                read -r -p "Pilihan model [0-9]: " m_choice

                selected_model=""
                case "$m_choice" in
                    1) selected_model="google/gemini-2.5-flash" ;;
                    2) selected_model="google/gemini-2.5-pro" ;;
                    3) selected_model="anthropic/claude-3-7-sonnet" ;;
                    4) selected_model="anthropic/claude-3-5-sonnet" ;;
                    5) selected_model="deepseek/deepseek-chat" ;;
                    6) selected_model="deepseek/deepseek-reasoner" ;;
                    7) selected_model="openai/gpt-4o" ;;
                    8) selected_model="openrouter/auto" ;;
                    9)
                        read -r -p "Masukkan model ID lengkap (contoh: provider/model-name): " selected_model
                        ;;
                    *)
                        selected_model=""
                        ;;
                esac

                if [ -n "$selected_model" ]; then
                    res=$(run_python_helper "model" "$selected_model")
                    log_ok "Default model berhasil diatur ke '$selected_model' di opencode.jsonc"
                    echo ""
                    read -r -p "Tekan ENTER untuk kembali..." _
                fi
                ;;
            3)
                echo ""
                log_info "Memeriksa dan menguji validitas seluruh provider aktif..."
                run_python_helper "test" "all"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                echo ""
                log_info "Mengekspor API Key ke $ENV_FILE..."
                res=$(run_python_helper "sync-env")
                count="${res#SYNC_COUNT:}"
                log_ok "Berhasil mengekspor $count variabel API key ke $ENV_FILE"
                
                # Check if ~/.bashrc sources ~/.termux_ai_env
                BASHRC="$HOME_DIR/.bashrc"
                if [ -f "$BASHRC" ]; then
                    if ! grep -q "termux_ai_env" "$BASHRC" 2>/dev/null; then
                        read -r -p "Tambahkan auto-load ke ~/.bashrc? (Y/n): " add_bashrc
                        if [[ ! "$add_bashrc" =~ ^[Nn]$ ]]; then
                            echo -e "\n# Load Termux AI Tools Environment\n[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\"" >> "$BASHRC"
                            log_ok "Ditambahkan ke ~/.bashrc! Sekarang perintah lain (curl, python, dll) juga dapat membaca API Key."
                        fi
                    else
                        log_ok "Auto-load sudah terpasang di ~/.bashrc."
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            5)
                echo ""
                read -r -p "Masukkan nama provider yang ingin dihapus (contoh: openai): " del_prov
                del_prov=$(echo "$del_prov" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]_-')
                if [ -n "$del_prov" ]; then
                    read -r -p "Apakah Anda yakin ingin menghapus API key untuk '$del_prov'? (y/N): " confirm_del
                    if [[ "$confirm_del" =~ ^[Yy]$ ]]; then
                        res=$(run_python_helper "remove" "$del_prov")
                        if [[ "$res" == DELETED:* ]]; then
                            log_ok "API Key untuk '$del_prov' berhasil dihapus dari auth.json"
                        else
                            log_warn "Provider '$del_prov' tidak ditemukan dalam auth.json"
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
    set)
        if [ -n "$3" ]; then
            key="$3"
        else
            echo -e "Masukkan API Key untuk ${BOLD}${CYAN}$2${RESET}:"
            read -r -s key
            echo ""
        fi
        res=$(run_python_helper "set" "$2" "$key")
        if [[ "$res" == OK:* ]]; then
            log_ok "API Key untuk '$2' disimpan (${res#OK:})"
        else
            log_err "Gagal: $res"
            exit 1
        fi
        ;;
    remove|del|rm)
        res=$(run_python_helper "remove" "$2")
        if [[ "$res" == DELETED:* ]]; then
            log_ok "API Key untuk '$2' dihapus"
        else
            log_warn "Provider '$2' tidak ditemukan"
        fi
        ;;
    model)
        if [ -n "$2" ]; then
            run_python_helper "model" "$2"
            log_ok "Default model diatur ke '$2'"
        else
            m=$(run_python_helper "model")
            echo "Default model saat ini: ${m:-Belum diatur}"
        fi
        ;;
    sync-env|sync)
        res=$(run_python_helper "sync-env")
        count="${res#SYNC_COUNT:}"
        log_ok "Sinkronisasi selesai: $count API key diekspor ke $ENV_FILE"
        ;;
    test)
        run_python_helper "test" "${2:-all}"
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - Config Helper Usage:${RESET}"
        echo "  bash config.sh                     Buka Wizard interaktif"
        echo "  bash config.sh list                Tampilkan status provider & API Key"
        echo "  bash config.sh set <provider> [key]Simpan API key untuk provider"
        echo "  bash config.sh get <provider>      Tampilkan masked key"
        echo "  bash config.sh remove <provider>   Hapus API key dari provider"
        echo "  bash config.sh model [model_id]    Tampilkan atau set default model OpenCode"
        echo "  bash config.sh sync-env            Sinkronkan key ke ~/.termux_ai_env"
        echo "  bash config.sh test [provider]     Uji validitas koneksi & API key"
        exit 0
        ;;
    *)
        wizard_menu
        ;;
esac

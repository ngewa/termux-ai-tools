#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for Config Helper & Provider Status
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_BIN="$TOOLS_DIR/config.sh"
HELPER_BIN="$TOOLS_DIR/bin/config-helper.sh"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
BOLD="\033[1m"
RESET="\033[0m"

PASSED=0
FAILED=0

clean_ansi() {
    echo "$1" | sed 's/\x1b\[[0-9;]*m//g'
}

assert_success() {
    local test_name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo -e "  [${GREEN}PASS${RESET}] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  [${RED}FAIL${RESET}] $test_name"
        FAILED=$((FAILED + 1))
    fi
}

assert_output_contains() {
    local test_name="$1"
    local expected="$2"
    shift 2
    local output
    output=$("$@") || true
    local clean_out
    clean_out=$(clean_ansi "$output")
    if [[ "$clean_out" == *"$expected"* ]]; then
        echo -e "  [${GREEN}PASS${RESET}] $test_name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  [${RED}FAIL${RESET}] $test_name"
        echo -e "         Expected to contain: '$expected'"
        echo -e "         Actual output: '$clean_out'"
        FAILED=$((FAILED + 1))
    fi
}

echo -e "\n${BOLD}${CYAN}=================================================="
echo "      🧪 Testing Suite: Config & Provider Manager "
echo -e "==================================================${RESET}\n"

# Test 1: Executable check
echo -e "${BOLD}1. Verifikasi File & Eksekusi:${RESET}"
assert_success "config.sh launcher dapat dieksekusi" test -x "$CONFIG_BIN"
assert_success "config-helper.sh dapat dieksekusi" test -x "$HELPER_BIN"

# Test 2: List & Header
echo -e "\n${BOLD}2. Pemeriksaan Output Status & Header:${RESET}"
assert_output_contains "config.sh list memuat header DAFTAR PROVIDER" "DAFTAR PROVIDER & STATUS API KEY TERPASANG" "$CONFIG_BIN" list
assert_output_contains "config.sh list menampilkan kolom STATUS" "STATUS" "$CONFIG_BIN" list
assert_output_contains "config.sh list menampilkan info lokasi setting manual" "Lokasi Berkas & Panduan Setting Manual" "$CONFIG_BIN" list
assert_output_contains "config.sh list memuat path auth.json" ".local/share/opencode/auth.json" "$CONFIG_BIN" list
assert_output_contains "config.sh list memuat path opencode.jsonc" ".config/opencode/opencode.jsonc" "$CONFIG_BIN" list
assert_output_contains "config.sh list memuat path settings.json" ".gemini/antigravity-cli/settings.json" "$CONFIG_BIN" list

# Test 2b: Manual Config Guide Command
echo -e "\n${BOLD}2b. Pemeriksaan Perintah Panduan Setting Manual (config.sh manual):${RESET}"
assert_output_contains "config.sh manual memuat judul panduan setting manual" "PANDUAN & LOKASI BERKAS SETTING MANUAL" bash -c "$CONFIG_BIN manual < /dev/null"
assert_output_contains "config.sh manual memuat panduan auth.json" "OpenCode Auth (API Key Per Provider)" bash -c "$CONFIG_BIN manual < /dev/null"
assert_output_contains "config.sh manual memuat panduan settings.json" "Antigravity CLI (agy Settings & Provider)" bash -c "$CONFIG_BIN manual < /dev/null"

# Test 3: Set & Get Dummy Provider
echo -e "\n${BOLD}3. Penambahan Kredensial Provider Pengujian:${RESET}"
TEST_PROV="groq"
TEST_KEY="gsk_testdummyapikey1234567890abcdef"
assert_output_contains "Set API Key untuk provider $TEST_PROV" "disimpan" "$CONFIG_BIN" set "$TEST_PROV" "$TEST_KEY"
assert_output_contains "Get masked key untuk provider $TEST_PROV" "gsk_test...cdef" "$CONFIG_BIN" get "$TEST_PROV"
assert_output_contains "Status $TEST_PROV sekarang AKTIF" "[ AKTIF ]" "$CONFIG_BIN" list

# Test 4: Disable Feature
echo -e "\n${BOLD}4. Fitur Disable Provider:${RESET}"
assert_output_contains "Disable provider $TEST_PROV" "berhasil dinonaktifkan" "$CONFIG_BIN" disable "$TEST_PROV"
assert_output_contains "Tampilan status $TEST_PROV menjadi NONAKTIF" "[ NONAKTIF ]" "$CONFIG_BIN" list
assert_output_contains "Get masked key menandai status NONAKTIF" "(NONAKTIF)" "$CONFIG_BIN" get "$TEST_PROV"
assert_output_contains "Test command menandai status DISABLED" "DISABLED" "$CONFIG_BIN" test "$TEST_PROV"

# Test 5: Sync Environment with Disabled Provider
echo -e "\n${BOLD}5. Pengujian Sinkronisasi Shell Env (~/.termux_ai_env):${RESET}"
"$CONFIG_BIN" sync-env >/dev/null 2>&1
ENV_FILE="$HOME_DIR/.termux_ai_env"
assert_success "File ~/.termux_ai_env terbentuk" test -f "$ENV_FILE"
assert_output_contains "Key dinonaktifkan diberi komentar status NONAKTIF" "STATUS: NONAKTIF" cat "$ENV_FILE"

# Test 6: Enable Feature
echo -e "\n${BOLD}6. Fitur Enable Provider:${RESET}"
assert_output_contains "Enable provider $TEST_PROV" "berhasil diaktifkan" "$CONFIG_BIN" enable "$TEST_PROV"
assert_output_contains "Tampilan status $TEST_PROV kembali AKTIF" "[ AKTIF ]" "$CONFIG_BIN" list

# Test 7: Toggle Feature
echo -e "\n${BOLD}7. Fitur Toggle Provider:${RESET}"
assert_output_contains "Toggle provider $TEST_PROV (aktif -> nonaktif)" "dinonaktifkan" "$CONFIG_BIN" toggle "$TEST_PROV"
assert_output_contains "Status hasil toggle 1 adalah NONAKTIF" "[ NONAKTIF ]" "$CONFIG_BIN" list
assert_output_contains "Toggle provider $TEST_PROV (nonaktif -> aktif)" "diaktifkan" "$CONFIG_BIN" toggle "$TEST_PROV"
assert_output_contains "Status hasil toggle 2 adalah AKTIF" "[ AKTIF ]" "$CONFIG_BIN" list

# Test 8: Advanced Provider Configuration (Target, Base URL, Model, API Mode)
echo -e "\n${BOLD}8. Konfigurasi Lanjutan Provider (Target, Base URL, Model & API Mode):${RESET}"
ADV_PROV="testendpoint"
ADV_KEY="sk-advtest1234567890abcdef"
ADV_BASE="https://api.testendpoint.ai/v1"
ADV_MODEL="testendpoint/fast-v1"
ADV_MODE="responses_compat"

assert_output_contains "Set konfigurasi provider lanjutan" "disimpan" "$CONFIG_BIN" set "$ADV_PROV" "$ADV_KEY" "all" "$ADV_BASE" "$ADV_MODEL" "$ADV_MODE"
assert_output_contains "Info command memuat Base URL" "BASE_URL:$ADV_BASE" "$CONFIG_BIN" info "$ADV_PROV"
assert_output_contains "Info command memuat Model" "MODEL:$ADV_MODEL" "$CONFIG_BIN" info "$ADV_PROV"
assert_output_contains "Info command memuat Mode" "API_MODE:$ADV_MODE" "$CONFIG_BIN" info "$ADV_PROV"
assert_output_contains "List menampilkan kolom API MODE" "Resp (Compat)" "$CONFIG_BIN" list
assert_output_contains "List menampilkan target Universal" "Universal" "$CONFIG_BIN" list

# Test 9: Fitur Edit Konfigurasi Provider (edit & edit-field)
echo -e "\n${BOLD}9. Fitur Edit Konfigurasi Provider (edit & edit-field):${RESET}"
assert_output_contains "Edit Base URL via edit-field" "berhasil diubah" "$CONFIG_BIN" edit-field "$ADV_PROV" baseurl "https://api.newurl.com/v1"
assert_output_contains "Verifikasi perubahan Base URL" "BASE_URL:https://api.newurl.com/v1" "$CONFIG_BIN" info "$ADV_PROV"
assert_output_contains "Edit API Mode via edit-field" "berhasil diubah" "$CONFIG_BIN" edit-field "$ADV_PROV" mode "chat_completions"
assert_output_contains "Verifikasi perubahan API Mode" "API_MODE:chat_completions" "$CONFIG_BIN" info "$ADV_PROV"
assert_output_contains "Edit lengkap via command edit" "berhasil diperbarui" "$CONFIG_BIN" edit "$ADV_PROV" "opencode" "https://api.edited.com/v1" "edited/model-v2" "responses" "__KEEP__"
assert_output_contains "Verifikasi target hasil edit" "TARGET:opencode" "$CONFIG_BIN" info "$ADV_PROV"
assert_output_contains "Verifikasi mode hasil edit" "API_MODE:responses" "$CONFIG_BIN" info "$ADV_PROV"

# Test 10: Model Settings for Antigravity agy
echo -e "\n${BOLD}10. Pengaturan Model Antigravity agy:${RESET}"
assert_output_contains "Set model Antigravity agy" "diatur ke" "$CONFIG_BIN" model-agy "Gemini 3.8 Pro"
assert_output_contains "Verifikasi model Antigravity agy" "Gemini 3.8 Pro" "$CONFIG_BIN" model-agy
# Test proteksi model tidak kompatibel untuk agy (gpt-6-luna & prefix provider)
"$CONFIG_BIN" model-agy "gpt-6-luna" >/dev/null 2>&1 || true
assert_output_contains "Proteksi: model gpt-6-luna ditolak dan tidak mengubah model agy" "Gemini 3.8 Pro" "$CONFIG_BIN" model-agy
"$CONFIG_BIN" model-agy "bynara/glm-5.3-flash" >/dev/null 2>&1 || true
assert_output_contains "Proteksi: model dengan prefix provider ditolak" "Gemini 3.8 Pro" "$CONFIG_BIN" model-agy
# Normalisasi identifier resmi agy (gemini-3.8-flash-high -> Gemini 3.8 Flash (High))
"$CONFIG_BIN" model-agy "gemini-3.8-flash-high" >/dev/null 2>&1
assert_output_contains "Normalisasi identifier resmi agy" "Gemini 3.8 Flash (High)" "$CONFIG_BIN" model-agy
# Restore model agy
"$CONFIG_BIN" model-agy "Gemini 3.8 Flash (High)" >/dev/null 2>&1

# Test 11: Pengaturan Target Integrasi Spesifik (opencode, agy, all)
echo -e "\n${BOLD}11. Pengaturan Target Integrasi Spesifik (opencode, agy, all):${RESET}"
TGT_PROV="mistral"
TGT_KEY="sk-mistral-target-test-12345678"
assert_output_contains "Set provider $TGT_PROV dengan target all" "disimpan" "$CONFIG_BIN" set "$TGT_PROV" "$TGT_KEY" "all"
assert_output_contains "Info $TGT_PROV menampilkan TARGET:all" "TARGET:all" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Ubah target $TGT_PROV ke opencode saja" "berhasil diatur ke 'opencode'" "$CONFIG_BIN" target "$TGT_PROV" "opencode"
assert_output_contains "Info $TGT_PROV menampilkan TARGET:opencode" "TARGET:opencode" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Ubah target $TGT_PROV ke agy saja" "berhasil diatur ke 'agy'" "$CONFIG_BIN" target "$TGT_PROV" "agy"
assert_output_contains "Info $TGT_PROV menampilkan TARGET:agy" "TARGET:agy" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Ubah target $TGT_PROV kembali ke all" "berhasil diatur ke 'all'" "$CONFIG_BIN" target "$TGT_PROV" "all"
assert_output_contains "Info $TGT_PROV kembali TARGET:all" "TARGET:all" "$CONFIG_BIN" info "$TGT_PROV"

# Test 12: Fitur Enable / Disable Berdasarkan Target (Per-Target Status)
echo -e "\n${BOLD}12. Fitur Enable / Disable Berdasarkan Target (Per-Target Status):${RESET}"
assert_output_contains "Disable $TGT_PROV di OpenCode saja" "berhasil dinonaktifkan [Target: opencode]" "$CONFIG_BIN" disable "$TGT_PROV" "opencode"
assert_output_contains "Info STATUS_OPENCODE adalah NONAKTIF" "STATUS_OPENCODE:NONAKTIF" "$CONFIG_BIN" info "$TGT_PROV"
assert_output_contains "Info STATUS_AGY tetap AKTIF" "STATUS_AGY:AKTIF" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Enable $TGT_PROV di OpenCode saja" "berhasil diaktifkan [Target: opencode]" "$CONFIG_BIN" enable "$TGT_PROV" "opencode"
assert_output_contains "Info STATUS_OPENCODE kembali AKTIF" "STATUS_OPENCODE:AKTIF" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Disable $TGT_PROV di AGY saja" "berhasil dinonaktifkan [Target: agy]" "$CONFIG_BIN" disable "$TGT_PROV" "agy"
assert_output_contains "Info STATUS_AGY adalah NONAKTIF" "STATUS_AGY:NONAKTIF" "$CONFIG_BIN" info "$TGT_PROV"
assert_output_contains "Info STATUS_OPENCODE tetap AKTIF" "STATUS_OPENCODE:AKTIF" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Enable $TGT_PROV di AGY saja" "berhasil diaktifkan [Target: agy]" "$CONFIG_BIN" enable "$TGT_PROV" "agy"
assert_output_contains "Info STATUS_AGY kembali AKTIF" "STATUS_AGY:AKTIF" "$CONFIG_BIN" info "$TGT_PROV"

# Test 13: Fitur Hapus Provider Parsial Berdasarkan Target (Per-Target Remove)
echo -e "\n${BOLD}13. Fitur Hapus Provider Parsial Berdasarkan Target (Per-Target Remove):${RESET}"
assert_output_contains "Hapus $TGT_PROV dari OpenCode saja" "berhasil dihapus [Target: opencode]" "$CONFIG_BIN" remove "$TGT_PROV" "opencode"
assert_output_contains "Info $TGT_PROV berubah target ke agy" "TARGET:agy" "$CONFIG_BIN" info "$TGT_PROV"
assert_output_contains "Status AGY masih AKTIF" "STATUS_AGY:AKTIF" "$CONFIG_BIN" info "$TGT_PROV"

assert_output_contains "Hapus $TGT_PROV dari AGY" "berhasil dihapus [Target: agy]" "$CONFIG_BIN" remove "$TGT_PROV" "agy"
assert_output_contains "Status $TGT_PROV kembali BELUM" "[ BELUM ]" "$CONFIG_BIN" list

# Test 14: Fitur Tool-List Filter Target (OpenCode vs AGY)
echo -e "\n${BOLD}14. Fitur Tool-List Filter Target (OpenCode vs AGY):${RESET}"
TL_PROV_OC="tooloc"
TL_PROV_AGY="toolagy"
assert_output_contains "Set provider $TL_PROV_OC ke target opencode" "disimpan" "$CONFIG_BIN" set "$TL_PROV_OC" "sk-test-oc-12345678" "opencode"
assert_output_contains "Set provider $TL_PROV_AGY ke target agy" "disimpan" "$CONFIG_BIN" set "$TL_PROV_AGY" "sk-test-agy-12345678" "agy"

assert_output_contains "Tool-list opencode menampilkan $TL_PROV_OC" "$TL_PROV_OC" "$CONFIG_BIN" tool-list "opencode"
assert_output_contains "Tool-list agy menampilkan $TL_PROV_AGY" "$TL_PROV_AGY" "$CONFIG_BIN" tool-list "agy"

assert_output_contains "Hapus provider $TL_PROV_OC" "dihapus" "$CONFIG_BIN" remove "$TL_PROV_OC" "opencode"
assert_output_contains "Hapus provider $TL_PROV_AGY" "dihapus" "$CONFIG_BIN" remove "$TL_PROV_AGY" "agy"

# Test 15: Cleanup & Remove
echo -e "\n${BOLD}15. Pembersihan Kredensial Pengujian:${RESET}"
assert_output_contains "Hapus kredensial pengujian $TEST_PROV" "dihapus" "$CONFIG_BIN" remove "$TEST_PROV"
assert_output_contains "Hapus provider advanced $ADV_PROV" "dihapus" "$CONFIG_BIN" remove "$ADV_PROV"
assert_output_contains "Status $TEST_PROV kembali BELUM" "[ BELUM ]" "$CONFIG_BIN" list

# Final Summary
echo -e "\n${BOLD}==================================================${RESET}"
echo -e "Total Pengujian: $((PASSED + FAILED))"
echo -e "  • ${GREEN}Lolos (Passed)${RESET} : $PASSED"
echo -e "  • ${RED}Gagal (Failed)${RESET} : $FAILED"
echo -e "${BOLD}==================================================${RESET}\n"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 Seluruh pengujian Fitur Enable & Disable Provider berhasil 100%!${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}❌ Ada $FAILED pengujian yang gagal!${RESET}\n"
    exit 1
fi

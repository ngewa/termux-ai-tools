#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for Plugin & MCP Installer
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_BIN="$TOOLS_DIR/plugin.sh"
INSTALLER_BIN="$TOOLS_DIR/bin/plugin-installer.sh"

AGY_SETTINGS="$HOME_DIR/.gemini/settings.json"
AGY_MCP_CONFIG="$HOME_DIR/.gemini/config/mcp_config.json"
OPENCODE_CONFIG="$HOME_DIR/.config/opencode/opencode.jsonc"

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
echo "    🧪 Testing Suite: Plugin & MCP Tool Installer  "
echo -e "==================================================${RESET}\n"

# Backup original configs for test safety
TMP_TEST_DIR="$PREFIX/tmp/plugin_test_$$"
mkdir -p "$TMP_TEST_DIR"
[ -f "$AGY_SETTINGS" ] && cp "$AGY_SETTINGS" "$TMP_TEST_DIR/settings.json"
[ -f "$AGY_MCP_CONFIG" ] && cp "$AGY_MCP_CONFIG" "$TMP_TEST_DIR/mcp_config.json"
[ -f "$OPENCODE_CONFIG" ] && cp "$OPENCODE_CONFIG" "$TMP_TEST_DIR/opencode.jsonc"

cleanup() {
    [ -f "$TMP_TEST_DIR/settings.json" ] && cp "$TMP_TEST_DIR/settings.json" "$AGY_SETTINGS"
    [ -f "$TMP_TEST_DIR/mcp_config.json" ] && cp "$TMP_TEST_DIR/mcp_config.json" "$AGY_MCP_CONFIG"
    [ -f "$TMP_TEST_DIR/opencode.jsonc" ] && cp "$TMP_TEST_DIR/opencode.jsonc" "$OPENCODE_CONFIG"
    rm -rf "$TMP_TEST_DIR"
}
trap cleanup EXIT

# Test 1: File Existence & Permissions
echo -e "${BOLD}1. Verifikasi File & Eksekusi:${RESET}"
assert_success "plugin.sh launcher dapat dieksekusi" test -x "$PLUGIN_BIN"
assert_success "bin/plugin-installer.sh dapat dieksekusi" test -x "$INSTALLER_BIN"

# Test 2: Status Output Structure & Clear Badging
echo -e "\n${BOLD}2. Pemeriksaan Tampilan Status & Pembeda MCP vs Plugin:${RESET}"
assert_output_contains "Header membedakan MCP Servers vs Plugins" "MCP SERVERS vs RUNTIME PLUGINS" "$PLUGIN_BIN" status
assert_output_contains "Kategori 1 mencantumkan MCP SERVERS" "KATEGORI 1: MODEL CONTEXT PROTOCOL (MCP) SERVERS" "$PLUGIN_BIN" status
assert_output_contains "Kategori 2 mencantumkan RUNTIME PLUGINS" "KATEGORI 2: RUNTIME PLUGINS & EXTENSIONS" "$PLUGIN_BIN" status
assert_output_contains "Menampilkan Matriks Status Platform" "Matriks Status Platform" "$PLUGIN_BIN" status
assert_output_contains "Memiliki badge [MCP]" "[MCP]" "$PLUGIN_BIN" status
assert_output_contains "Memiliki badge [PLUGIN]" "[PLUGIN]" "$PLUGIN_BIN" status

# Test 3: Target-Specific MCP Installation
echo -e "\n${BOLD}3. Uji Pasang MCP Target: AGY Only, OpenCode Only, Keduanya (All):${RESET}"
# Install to AGY only
assert_success "Pasang MCP 'fetch' ke AGY saja" "$PLUGIN_BIN" install fetch agy
assert_output_contains "fetch terdaftar di AGY mcp_config.json" "fetch" grep "fetch" "$AGY_MCP_CONFIG"
assert_output_contains "fetch terdaftar di AGY settings.json" "fetch" grep "fetch" "$AGY_SETTINGS"
if grep -q "fetch" "$OPENCODE_CONFIG" 2>/dev/null; then
    echo -e "  [${RED}FAIL${RESET}] fetch tidak boleh terpasang di OpenCode saat target=agy"
    FAILED=$((FAILED + 1))
else
    echo -e "  [${GREEN}PASS${RESET}] fetch tidak terpasang di OpenCode saat target=agy"
    PASSED=$((PASSED + 1))
fi

# Install to OpenCode only
assert_success "Pasang MCP 'sqlite' ke OpenCode saja" "$PLUGIN_BIN" install sqlite oc
assert_output_contains "sqlite terdaftar di OpenCode config" "sqlite" grep "sqlite" "$OPENCODE_CONFIG"
if grep -q "sqlite" "$AGY_MCP_CONFIG" 2>/dev/null; then
    echo -e "  [${RED}FAIL${RESET}] sqlite tidak boleh terpasang di AGY saat target=oc"
    FAILED=$((FAILED + 1))
else
    echo -e "  [${GREEN}PASS${RESET}] sqlite tidak terpasang di AGY saat target=oc"
    PASSED=$((PASSED + 1))
fi

# Install to Both
assert_success "Pasang MCP 'filesystem' ke Keduanya (all)" "$PLUGIN_BIN" install filesystem all
assert_output_contains "filesystem terpasang di AGY mcp_config.json" "filesystem" grep "filesystem" "$AGY_MCP_CONFIG"
assert_output_contains "filesystem terpasang di OpenCode" "filesystem" grep "filesystem" "$OPENCODE_CONFIG"

# Test 4: Custom MCP Installation
echo -e "\n${BOLD}4. Uji Pasang Custom MCP Server:${RESET}"
assert_success "Tambah Custom MCP server dummy-test ke AGY" "$PLUGIN_BIN" add-custom dummy-test agy python3 "-c print(1)"
assert_output_contains "dummy-test terdaftar di AGY mcp_config.json" "dummy-test" grep "dummy-test" "$AGY_MCP_CONFIG"

# Test 5: Target-Specific MCP Removal
echo -e "\n${BOLD}5. Uji Penghapusan MCP Berdasarkan Target:${RESET}"
# Remove filesystem from AGY only
assert_success "Hapus filesystem dari AGY saja" "$PLUGIN_BIN" remove filesystem agy
if grep -q "filesystem" "$AGY_MCP_CONFIG" 2>/dev/null; then
    echo -e "  [${RED}FAIL${RESET}] filesystem harusnya sudah terhapus dari AGY"
    FAILED=$((FAILED + 1))
else
    echo -e "  [${GREEN}PASS${RESET}] filesystem berhasil dihapus dari AGY"
    PASSED=$((PASSED + 1))
fi
assert_output_contains "filesystem masih ada di OpenCode" "filesystem" grep "filesystem" "$OPENCODE_CONFIG"

# Clean up remaining test entries
"$PLUGIN_BIN" remove filesystem oc >/dev/null 2>&1 || true
"$PLUGIN_BIN" remove fetch agy >/dev/null 2>&1 || true
"$PLUGIN_BIN" remove sqlite oc >/dev/null 2>&1 || true
"$PLUGIN_BIN" remove dummy-test agy >/dev/null 2>&1 || true

# Test 6: Test Command Validation
echo -e "\n${BOLD}6. Uji Perintah 'plugin.sh test':${RESET}"
assert_output_contains "Uji biner command 'termux-device' berhasil" "[PASS]" "$PLUGIN_BIN" test termux-device

echo -e "\n${BOLD}Hasil Pengujian:${RESET} Total: $((PASSED + FAILED)) | ${GREEN}Passed: $PASSED${RESET} | ${RED}Failed: $FAILED${RESET}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 Semua pengujian Plugin & MCP Installer berhasil dilalui!${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}❌ Ada pengujian yang gagal!${RESET}\n"
    exit 1
fi

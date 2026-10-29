#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for AI Persona & Subagent Manager
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_BIN="$TOOLS_DIR/agent.sh"
AI_BIN="$TOOLS_DIR/bin/ai-launcher.sh"

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
echo "    🧪 Testing Suite: AI Subagents & Personas     "
echo -e "==================================================${RESET}\n"

# Test 1: File Executable Check
echo -e "${BOLD}1. Verifikasi File & Eksekusi:${RESET}"
assert_success "agent.sh launcher dapat dieksekusi" test -x "$AGENT_BIN"
assert_success "agent-manager.sh dapat dieksekusi" test -x "$TOOLS_DIR/bin/agent-manager.sh"

# Test 2: Status & Existing Personas Discovery
echo -e "\n${BOLD}2. Pemeriksaan Status & Deteksi Persona:${RESET}"
assert_output_contains "agent.sh list menampilkan header status" "STATUS AI PERSONAS & SUBAGENTS TERPASANG" "$AGENT_BIN" list
assert_output_contains "agent.sh list mendeteksi roblox-engineer" "roblox-engineer" "$AGENT_BIN" list
assert_output_contains "agent.sh list mendeteksi toolkit-dev" "toolkit-dev" "$AGENT_BIN" list

# Test 3: Presets Catalog
echo -e "\n${BOLD}3. Katalog Template Preset:${RESET}"
assert_output_contains "agent.sh presets menampilkan code-reviewer" "code-reviewer" "$AGENT_BIN" presets
assert_output_contains "agent.sh presets menampilkan android-reverser" "android-reverser" "$AGENT_BIN" presets
assert_output_contains "agent.sh presets menampilkan fullstack-dev" "fullstack-dev" "$AGENT_BIN" presets

# Test 4: Creation & Dual-Platform Support
echo -e "\n${BOLD}4. Pembuatan Persona Baru (Dual Platform):${RESET}"
TEST_AGENT="test-suite-persona"
# Clean up if existing
"$AGENT_BIN" remove "$TEST_AGENT" >/dev/null 2>&1 || true

assert_output_contains "agent.sh create membuat persona di Antigravity" "Persona Antigravity dibuat" "$AGENT_BIN" create "$TEST_AGENT" --both
assert_output_contains "agent.sh create membuat persona di OpenCode" "Persona OpenCode dibuat" "$AGENT_BIN" create "$TEST_AGENT" --both
assert_success "File agent.md Antigravity ada" test -f "$HOME_DIR/.gemini/config/agents/$TEST_AGENT/agent.md"
assert_success "File .md OpenCode ada" test -f "$HOME_DIR/.config/opencode/agents/$TEST_AGENT.md"

# Test 5: Info & Inspection
echo -e "\n${BOLD}5. Inspeksi Detail Persona:${RESET}"
assert_output_contains "agent.sh info menampilkan Antigravity" "Platform    : Antigravity" "$AGENT_BIN" info "$TEST_AGENT"
assert_output_contains "agent.sh info menampilkan OpenCode" "Platform    : OpenCode" "$AGENT_BIN" info "$TEST_AGENT"

# Test 6: Doctor & Diagnostics
echo -e "\n${BOLD}6. Audit & Diagnostik Kepatuhan:${RESET}"
assert_output_contains "agent.sh doctor menjalankan audit" "AUDIT & DIAGNOSTIK KESEHATAN PERSONA" "$AGENT_BIN" doctor
assert_output_contains "test persona lolos audit PASS" "$TEST_AGENT" "$AGENT_BIN" doctor

# Test 7: Toggle (Disable & Enable)
echo -e "\n${BOLD}7. Manajemen Status (Active / Disabled):${RESET}"
assert_output_contains "agent.sh disable menonaktifkan persona" "dinonaktifkan" "$AGENT_BIN" disable "$TEST_AGENT"
assert_output_contains "agent.sh enable mengaktifkan kembali persona" "diaktifkan" "$AGENT_BIN" enable "$TEST_AGENT"

# Test 8: Cross-Platform Sync
echo -e "\n${BOLD}8. Sinkronisasi Silang Antar Platform:${RESET}"
assert_output_contains "agent.sh sync berjalan dengan sukses" "SINKRONISASI SILANG PERSONA" "$AGENT_BIN" sync

# Test 9: Removal Cleanup
echo -e "\n${BOLD}9. Penghapusan Persona:${RESET}"
assert_output_contains "agent.sh remove menghapus persona" "Berhasil menghapus" "$AGENT_BIN" remove "$TEST_AGENT"
assert_success "Folder persona Antigravity terhapus" test ! -d "$HOME_DIR/.gemini/config/agents/$TEST_AGENT"
assert_success "Berkas persona OpenCode terhapus" test ! -f "$HOME_DIR/.config/opencode/agents/$TEST_AGENT.md"

# Test 10: Global CLI Dispatcher Integration (ai agent)
echo -e "\n${BOLD}10. Integrasi Perintah Global 'ai agent':${RESET}"
assert_output_contains "ai agent list berjalan melalui ai-launcher" "STATUS AI PERSONAS & SUBAGENTS TERPASANG" "$AI_BIN" agent list
assert_output_contains "ai agent presets berjalan melalui ai-launcher" "KATALOG TEMPLATE PRESET" "$AI_BIN" agent presets

# Final Summary
echo -e "\n${BOLD}==================================================${RESET}"
echo -e "Total Pengujian: $((PASSED + FAILED))"
echo -e "  • ${GREEN}Lolos (Passed)${RESET} : $PASSED"
echo -e "  • ${RED}Gagal (Failed)${RESET} : $FAILED"
echo -e "${BOLD}==================================================${RESET}\n"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 Seluruh pengujian Persona Manager berhasil 100%!${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}❌ Ada $FAILED pengujian yang gagal!${RESET}\n"
    exit 1
fi

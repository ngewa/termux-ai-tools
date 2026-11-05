#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for AI Agent Skill Manager
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_BIN="$TOOLS_DIR/skill.sh"
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
echo "    🧪 Testing Suite: AI Agent Skill Manager       "
echo -e "==================================================${RESET}\n"

# Test 1: Binary Existence & Executable
echo -e "${BOLD}1. Verifikasi File & Eksekusi:${RESET}"
assert_success "skill.sh launcher dapat dieksekusi" test -x "$SKILL_BIN"
assert_success "skill-manager.sh dapat dieksekusi" test -x "$TOOLS_DIR/bin/skill-manager.sh"

# Test 2: List & Presets
echo -e "\n${BOLD}2. Pemeriksaan Status & Katalog Preset:${RESET}"
assert_output_contains "skill.sh list menampilkan header status" "STATUS AI AGENT SKILLS TERPASANG" "$SKILL_BIN" list
assert_output_contains "skill.sh presets menampilkan prompt-master" "prompt-master" "$SKILL_BIN" presets
assert_output_contains "skill.sh presets menampilkan antislop" "antislop" "$SKILL_BIN" presets
assert_output_contains "skill.sh presets menampilkan author miqdadbadjuber" "miqdadbadjuber" "$SKILL_BIN" presets

# Test 3: Create, Info, & Inspect
echo -e "\n${BOLD}3. Pembuatan & Inspeksi Skill Baru:${RESET}"
TEST_SKILL="test-agent-suite-skill"
# Cleanup if exists from previous run
"$SKILL_BIN" remove "$TEST_SKILL" >/dev/null 2>&1 || true

assert_output_contains "skill.sh create berhasil membuat template" "berhasil dibuat" "$SKILL_BIN" create "$TEST_SKILL"
assert_output_contains "skill.sh info menampilkan nama skill yang baru dibuat" "DETAIL AI AGENT SKILL: TEST-AGENT-SUITE-SKILL" "$SKILL_BIN" info "$TEST_SKILL"
assert_output_contains "SKILL.md berisi frontmatter valid" "Ringkasan Peran" cat "$HOME_DIR/.agents/skills/$TEST_SKILL/SKILL.md"

# Test 4: Doctor / Audit
echo -e "\n${BOLD}4. Audit & Diagnostik Integritas:${RESET}"
assert_output_contains "skill.sh doctor memvalidasi skill" "AUDIT & DIAGNOSTIK KESEHATAN SKILL" "$SKILL_BIN" doctor
assert_output_contains "test skill lolos audit doctor" "$TEST_SKILL" "$SKILL_BIN" doctor

# Test 5: Toggle (Disable & Enable)
echo -e "\n${BOLD}5. Manajemen Status (Toggle Active / Disabled):${RESET}"
assert_output_contains "skill.sh disable menonaktifkan skill" "dinonaktifkan" "$SKILL_BIN" disable "$TEST_SKILL"
assert_output_contains "skill.sh list menampilkan skill di daftar nonaktif" "Universal Disabled" "$SKILL_BIN" list
assert_output_contains "skill.sh enable mengaktifkan kembali skill" "diaktifkan" "$SKILL_BIN" enable "$TEST_SKILL"

# Test 6: Removal
echo -e "\n${BOLD}6. Penghapusan Skill:${RESET}"
assert_output_contains "skill.sh remove menghapus direktori skill" "Berhasil menghapus" "$SKILL_BIN" remove "$TEST_SKILL"
assert_success "Folder skill benar-benar terhapus" test ! -d "$HOME_DIR/.agents/skills/$TEST_SKILL"

# Test 7: CLI Dispatcher Integration (ai skill)
echo -e "\n${BOLD}7. Integrasi Perintah Global 'ai skill':${RESET}"
assert_output_contains "ai skill list berjalan melalui ai-launcher.sh" "STATUS AI AGENT SKILLS TERPASANG" "$AI_BIN" skill list
assert_output_contains "ai skill presets berjalan melalui ai-launcher.sh" "KATALOG PRESET" "$AI_BIN" skill presets

# Test 8: Pencarian Skill Resmi Claude (anthropics/claude-plugins-official)
echo -e "\n${BOLD}8. Pencarian Skill Resmi Claude (claude-plugins-official):${RESET}"
assert_output_contains "skill.sh search menampilkan katalog skill resmi Claude" "KATALOG SKILL RESMI CLAUDE" "$SKILL_BIN" search
assert_output_contains "skill.sh search mencantumkan sumber github resmi" "claude-plugins-official" "$SKILL_BIN" search
assert_output_contains "skill.sh search design menemukan frontend-design" "frontend-design" "$SKILL_BIN" search design
assert_output_contains "skill.sh search security menemukan claude-security" "claude-security" "$SKILL_BIN" search security
assert_output_contains "skill.sh cari kata kunci dev berfungsi" "DIDUKUNG" "$SKILL_BIN" cari dev
assert_output_contains "ai skill search berjalan melalui ai-launcher" "PENCARIAN SKILL RESMI CLAUDE" "$AI_BIN" skill search mcp

# Test 9: Deteksi Skill Global vs Workspace
echo -e "\n${BOLD}9. Deteksi Skill Global & Workspace:${RESET}"
WS_ROOT="${TMPDIR:-$PREFIX/tmp}/skill-ws-suite-$$"
mkdir -p "$WS_ROOT/.agents/skills/ws-suite-skill" "$WS_ROOT/.git"
cat > "$WS_ROOT/.agents/skills/ws-suite-skill/SKILL.md" <<'SKILLEOF'
---
name: ws-suite-skill
description: Skill uji deteksi workspace
---
# Workspace Test Skill
SKILLEOF

assert_output_contains "list menampilkan seksi GLOBAL SKILLS" "GLOBAL SKILLS" "$SKILL_BIN" list
assert_output_contains "list menampilkan seksi WORKSPACE SKILLS" "WORKSPACE SKILLS" "$SKILL_BIN" list
assert_output_contains "list mendeteksi skill workspace dari cwd proyek" "ws-suite-skill" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' list"
assert_output_contains "list menampilkan label lokasi workspace" "Workspace (./.agents/skills)" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' list"
assert_output_contains "filter --workspace hanya menampilkan cakupan workspace" "Workspace: 1" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' list --workspace"
assert_output_contains "filter --global menyembunyikan skill workspace" "Workspace: 0" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' list --global"
assert_output_contains "info menampilkan scope workspace" "Workspace (proyek ini)" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' info ws-suite-skill"
assert_output_contains "create --workspace membuat skill di proyek" "Scope: Workspace" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' create ws-created --workspace"
assert_success "SKILL.md skill workspace baru benar-benar dibuat" test -f "$WS_ROOT/.agents/skills/ws-created/SKILL.md"
assert_success "disable lalu enable skill workspace berhasil" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' disable ws-suite-skill >/dev/null && '$SKILL_BIN' enable ws-suite-skill >/dev/null"
assert_success "skill workspace kembali aktif setelah enable" test -d "$WS_ROOT/.agents/skills/ws-suite-skill"
assert_output_contains "remove menghapus skill workspace" "Berhasil menghapus" bash -c "cd '$WS_ROOT' && '$SKILL_BIN' remove ws-suite-skill"
assert_success "folder skill workspace benar-benar terhapus" test ! -d "$WS_ROOT/.agents/skills/ws-suite-skill"
rm -rf "$WS_ROOT"

# Final Summary
echo -e "\n${BOLD}==================================================${RESET}"
echo -e "Total Pengujian: $((PASSED + FAILED))"
echo -e "  • ${GREEN}Lolos (Passed)${RESET} : $PASSED"
echo -e "  • ${RED}Gagal (Failed)${RESET} : $FAILED"
echo -e "${BOLD}==================================================${RESET}\n"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 Seluruh pengujian Skill Manager berhasil 100%!${RESET}\n"
    exit 0
else
    echo -e "${RED}${BOLD}❌ Ada $FAILED pengujian yang gagal!${RESET}\n"
    exit 1
fi

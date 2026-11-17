#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Test Suite for Selective & Full Restore (bin/restore-config.sh)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPORT_BIN="$TOOLS_DIR/bin/export-config.sh"
RESTORE_BIN="$TOOLS_DIR/bin/restore-config.sh"
AI_BIN="$TOOLS_DIR/bin/ai-launcher.sh"

GREEN="\033[32m"
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
    output=$("$@" 2>&1) || true
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

TEST_ROOT=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/test-restore.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT

SRC_HOME="$TEST_ROOT/src_home"
mkdir -p \
    "$SRC_HOME/.config/opencode/agents" \
    "$SRC_HOME/.local/share/opencode/storage" \
    "$SRC_HOME/.gemini/antigravity-cli/brain/conv1" \
    "$SRC_HOME/.gemini/antigravity-cli/conversations" \
    "$SRC_HOME/.gemini/config/agents" \
    "$SRC_HOME/.gemini/skills/my-skill" \
    "$SRC_HOME/.agents/skills/univ-skill" \
    "$SRC_HOME/.local/share/termux-ai" \
    "$SRC_HOME/.config/termux-ai" \
    "$SRC_HOME/.local/share/antigravity-swap/credentials" \
    "$SRC_HOME/.config/antigravity"

cat > "$SRC_HOME/.config/opencode/opencode.jsonc" << 'EOF'
{
  // OpenCode config with JSONC comment
  "model": "google/gemini-2.5-pro",
  "mcp": {
    "termux-device": { "type": "local", "command": ["python3", "server.py"] }
  }
}
EOF
echo '{"v1":true}' > "$SRC_HOME/opencode.jsonc"
echo '{"cli":2}' > "$SRC_HOME/.config/opencode/cli.json"
echo '{"svc":2}' > "$SRC_HOME/.config/opencode/service.json"
echo "v1-session" > "$SRC_HOME/.local/share/opencode/storage/s1.json"
echo "dummy-opencode-db" > "$SRC_HOME/.local/share/opencode/opencode.db"
echo '{"token":"secret"}' > "$SRC_HOME/.local/share/opencode/auth.json"
echo "oc-agent" > "$SRC_HOME/.config/opencode/agents/helper.md"

cat > "$SRC_HOME/.gemini/config/mcp_config.json" << 'EOF'
{
  "mcpServers": {
    "code-review-graph": { "command": "python3", "args": ["-m", "code_review_graph", "serve"] }
  }
}
EOF
cat > "$SRC_HOME/.gemini/settings.json" << 'EOF'
{
  "theme": "dark",
  "mcpServers": {
    "fetch": { "command": "npx", "args": ["-y", "@modelcontextprotocol/server-fetch"] }
  }
}
EOF
echo "oauth-secret" > "$SRC_HOME/.gemini/antigravity-cli/antigravity-oauth-token"
echo "brain-data" > "$SRC_HOME/.gemini/antigravity-cli/brain/conv1/note.md"
echo "conv-data" > "$SRC_HOME/.gemini/antigravity-cli/conversations/c1.json"
echo "agy-agent" > "$SRC_HOME/.gemini/config/agents/agy-helper.md"
echo "agy-skill" > "$SRC_HOME/.gemini/skills/my-skill/SKILL.md"
echo "univ-skill" > "$SRC_HOME/.agents/skills/univ-skill/SKILL.md"
echo "sqlite-mem" > "$SRC_HOME/.local/share/termux-ai/memory.db"
echo '{"accounts":[]}' > "$SRC_HOME/.config/termux-ai/accounts.json"
echo '{"aswap":[]}' > "$SRC_HOME/.local/share/antigravity-swap/accounts.json"
echo "ENV=1" > "$SRC_HOME/.termux_ai_env"
echo "# AGENTS" > "$SRC_HOME/AGENTS.md"
cat > "$SRC_HOME/.mcp.json" << 'EOF'
{
  "mcpServers": {
    "global-mcp": { "command": "echo", "args": ["ok"] }
  }
}
EOF

ARCHIVE_FULL="$TEST_ROOT/backup-full.tar.gz"

echo -e "\n${BOLD}${CYAN}=================================================="
echo "    🧪 Testing Suite: Selective & Full Restore     "
echo -e "==================================================${RESET}\n"

echo -e "${BOLD}1. Syntax, Help & Archive Creation:${RESET}"
assert_success "bash -n bin/restore-config.sh valid" bash -n "$RESTORE_BIN"
assert_output_contains "ai restore --help menampilkan opsi --only & --full" "--only" "$AI_BIN" restore --help
assert_success "export-config.sh --full membuat arsip uji" env HOME="$SRC_HOME" bash "$EXPORT_BIN" --full "$ARCHIVE_FULL"
assert_output_contains "ai restore --list mendeteksi FULL BACKUP" "FULL BACKUP (--full)" "$AI_BIN" restore "$ARCHIVE_FULL" --list

echo -e "\n${BOLD}2. Selective Restore: MCP Only (--only mcp --yes):${RESET}"
DST_MCP="$TEST_ROOT/dst_mcp"
mkdir -p "$DST_MCP/.gemini" "$DST_MCP/.config/opencode"
echo '{"theme":"custom-user-theme"}' > "$DST_MCP/.gemini/settings.json"
echo '{"model":"existing-model","mcp":{"existing-mcp":{"type":"local"}}}' > "$DST_MCP/.config/opencode/opencode.jsonc"

assert_output_contains "Restore --only mcp berhasil" "Restore Selesai!" env HOME="$DST_MCP" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --only mcp --yes
assert_output_contains "MCP agy mcp_config.json ter-restore" "code-review-graph" cat "$DST_MCP/.gemini/config/mcp_config.json"
assert_output_contains "MCP agy settings.json ter-merge tanpa hapus theme" "custom-user-theme" cat "$DST_MCP/.gemini/settings.json"
assert_output_contains "MCP agy settings.json berisi fetch" "fetch" cat "$DST_MCP/.gemini/settings.json"
assert_output_contains "MCP opencode ter-merge tanpa hapus model" "existing-model" cat "$DST_MCP/.config/opencode/opencode.jsonc"
assert_output_contains "MCP opencode mempertahankan existing-mcp" "existing-mcp" cat "$DST_MCP/.config/opencode/opencode.jsonc"
assert_output_contains "MCP opencode menambah termux-device" "termux-device" cat "$DST_MCP/.config/opencode/opencode.jsonc"
assert_output_contains "Global ~/.mcp.json ter-restore" "global-mcp" cat "$DST_MCP/.mcp.json"
assert_success "opencode.db TIDAK ikut ter-restore saat --only mcp" test ! -f "$DST_MCP/.local/share/opencode/opencode.db"
assert_success "agy oauth token TIDAK ikut ter-restore saat --only mcp" test ! -f "$DST_MCP/.gemini/antigravity-cli/antigravity-oauth-token"

echo -e "\n${BOLD}3. Selective Restore: Antigravity CLI Only (--only agy --yes):${RESET}"
DST_AGY="$TEST_ROOT/dst_agy"
mkdir -p "$DST_AGY"
assert_output_contains "Restore --only agy berhasil" "Pengaturan Antigravity CLI (agy) berhasil dipulihkan" env HOME="$DST_AGY" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --only agy --yes
assert_success "OAuth token agy ter-restore" test -f "$DST_AGY/.gemini/antigravity-cli/antigravity-oauth-token"
assert_success "OpenCode TIDAK ikut ter-restore saat --only agy" test ! -d "$DST_AGY/.config/opencode"
assert_success "Riwayat brain agy TIDAK ikut ter-restore tanpa history/--full" test ! -d "$DST_AGY/.gemini/antigravity-cli/brain"

echo -e "\n${BOLD}4. Custom Multi-Select (--only skills,memory --yes):${RESET}"
DST_CUSTOM="$TEST_ROOT/dst_custom"
mkdir -p "$DST_CUSTOM"
assert_output_contains "Restore --only skills,memory berhasil" "Knowledge Memory (memory.db) berhasil dipulihkan" env HOME="$DST_CUSTOM" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --only skills,memory --yes
assert_success "Universal skills ter-restore" test -f "$DST_CUSTOM/.agents/skills/univ-skill/SKILL.md"
assert_success "Antigravity skills ter-restore" test -f "$DST_CUSTOM/.gemini/skills/my-skill/SKILL.md"
assert_success "Memory DB ter-restore" test -f "$DST_CUSTOM/.local/share/termux-ai/memory.db"
assert_success "Rules TIDAK ikut ter-restore" test ! -f "$DST_CUSTOM/AGENTS.md"

echo -e "\n${BOLD}5. Full Restore (--full --yes):${RESET}"
DST_FULL="$TEST_ROOT/dst_full"
mkdir -p "$DST_FULL"
assert_output_contains "Restore --full berhasil" "Restore Selesai!" env HOME="$DST_FULL" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --full --yes
assert_success "Full restore menyertakan opencode.db" test -f "$DST_FULL/.local/share/opencode/opencode.db"
assert_success "Full restore menyertakan agy brain" test -f "$DST_FULL/.gemini/antigravity-cli/brain/conv1/note.md"
assert_success "Full restore menyertakan AGENTS.md" test -f "$DST_FULL/AGENTS.md"
assert_success "Full restore menyertakan .termux_ai_env" test -f "$DST_FULL/.termux_ai_env"

echo -e "\n${BOLD}6. Interactive Prompt Simulation (Piped Stdin):${RESET}"
DST_PIPE="$TEST_ROOT/dst_pipe"
mkdir -p "$DST_PIPE"
assert_output_contains "Interactive pilihan '5' (MCP) + 'y' berhasil" "Konfigurasi MCP Servers selesai diproses" bash -c "printf '5\ny\n' | HOME='$DST_PIPE' bash '$RESTORE_BIN' '$ARCHIVE_FULL'"
assert_success "Interactive pilihan '5' membuat ~/.mcp.json" test -f "$DST_PIPE/.mcp.json"
assert_success "Interactive pilihan '5' tidak membuat memory.db" test ! -f "$DST_PIPE/.local/share/termux-ai/memory.db"

echo -e "\n${BOLD}7. Pemisahan OpenCode v1 (oc1) vs OpenCode v2 (oc2):${RESET}"
DST_OC1="$TEST_ROOT/dst_oc1"
mkdir -p "$DST_OC1"
assert_output_contains "Restore --only oc1 berhasil" "OpenCode v1 (oc) berhasil dipulihkan" env HOME="$DST_OC1" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --only oc1 --yes
assert_success "oc1 me-restore ~/opencode.jsonc" test -f "$DST_OC1/opencode.jsonc"
assert_success "oc1 me-restore storage v1" test -f "$DST_OC1/.local/share/opencode/storage/s1.json"
assert_success "oc1 tidak me-restore cli.json v2" test ! -f "$DST_OC1/.config/opencode/cli.json"
assert_success "oc1 tidak me-restore service.json v2" test ! -f "$DST_OC1/.config/opencode/service.json"
assert_success "oc1 tidak me-restore opencode.db tanpa history" test ! -f "$DST_OC1/.local/share/opencode/opencode.db"

DST_OC2="$TEST_ROOT/dst_oc2"
mkdir -p "$DST_OC2"
assert_output_contains "Restore --only oc2 berhasil" "OpenCode v2 (oc2) berhasil dipulihkan" env HOME="$DST_OC2" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --only oc2 --yes
assert_success "oc2 me-restore cli.json" test -f "$DST_OC2/.config/opencode/cli.json"
assert_success "oc2 me-restore service.json" test -f "$DST_OC2/.config/opencode/service.json"
assert_success "oc2 me-restore auth.json" test -f "$DST_OC2/.local/share/opencode/auth.json"
assert_success "oc2 tidak me-restore ~/opencode.jsonc v1" test ! -f "$DST_OC2/opencode.jsonc"
assert_success "oc2 tidak me-restore storage v1" test ! -d "$DST_OC2/.local/share/opencode/storage"
assert_success "oc2 tidak me-restore opencode.db tanpa history" test ! -f "$DST_OC2/.local/share/opencode/opencode.db"

echo -e "\n${BOLD}8. Pemisahan Multi-Account Registry (accounts) vs Antigravity Swap (aswap):${RESET}"
DST_ASWAP="$TEST_ROOT/dst_aswap"
mkdir -p "$DST_ASWAP"
assert_output_contains "Restore --only aswap berhasil" "Antigravity Swap (accounts & credentials) berhasil dipulihkan" env HOME="$DST_ASWAP" bash "$RESTORE_BIN" "$ARCHIVE_FULL" --only aswap --yes
assert_success "aswap me-restore ~/.local/share/antigravity-swap/accounts.json" test -f "$DST_ASWAP/.local/share/antigravity-swap/accounts.json"
assert_success "aswap tidak me-restore ~/.config/termux-ai/accounts.json" test ! -f "$DST_ASWAP/.config/termux-ai/accounts.json"

echo -e "\n${BOLD}=================================================="
echo -e "  Hasil: ${GREEN}${PASSED} Lulus${RESET} | ${RED}${FAILED} Gagal${RESET}"
echo -e "==================================================${RESET}\n"

[ "$FAILED" -eq 0 ]

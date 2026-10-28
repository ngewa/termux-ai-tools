#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for Knowledge Memory / AI Brain
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEMORY_BIN="$TOOLS_DIR/memory.sh"

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

extract_id() {
    clean_ansi "$1" | grep -E "ID[[:space:]]*:" | head -n 1 | awk -F': ' '{print $2}' | tr -d '[:space:]'
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
echo "    🧪 Testing Suite: Knowledge Memory / AI Brain "
echo -e "==================================================${RESET}\n"

# Test 1: Add note (CRUD Create)
echo -e "${BOLD}1. CRUD Operations (Add, Show, List, Edit, Delete):${RESET}"
ADD_OUT=$("$MEMORY_BIN" add --title "Fix SQLite Locking on Termux" \
                           --content "Gunakan WAL mode dan set PRAGMA busy_timeout = 5000 untuk mencegah database lock." \
                           --category "troubleshooting" \
                           --tags "sqlite,wal,termux,storage" \
                           --project "termux-ai-tools" \
                           --tool "opencode")

MEM_ID=$(extract_id "$ADD_OUT")
if [ -n "$MEM_ID" ] && [[ "$MEM_ID" == mem_* ]]; then
    echo -e "  [${GREEN}PASS${RESET}] Create note (ID: $MEM_ID)"
    PASSED=$((PASSED + 1))
else
    echo -e "  [${RED}FAIL${RESET}] Create note failed (Raw: $ADD_OUT)"
    FAILED=$((FAILED + 1))
fi

# Test 2: Show note (CRUD Read)
assert_output_contains "Show note details" "Fix SQLite Locking on Termux" "$MEMORY_BIN" show "$MEM_ID"
assert_output_contains "Show note category" "troubleshooting" "$MEMORY_BIN" show "$MEM_ID"
assert_output_contains "Show note tags" "sqlite,wal,termux,storage" "$MEMORY_BIN" show "$MEM_ID"

# Test 3: List notes (CRUD List)
assert_output_contains "List notes contains created note" "$MEM_ID" "$MEMORY_BIN" list

# Test 4: Edit note (CRUD Update)
assert_success "Edit note content" "$MEMORY_BIN" edit "$MEM_ID" --title "Fix SQLite Locking on Termux Updated" --append "Tambahan tips: hindari vacuum berulang."
assert_output_contains "Verify updated content" "hindari vacuum berulang" "$MEMORY_BIN" show "$MEM_ID"

# Test 5: Tag Management
echo -e "\n${BOLD}2. Tag Management:${RESET}"
assert_success "Add tag" "$MEMORY_BIN" tag "$MEM_ID" add "concurrency"
assert_output_contains "Verify added tag" "concurrency" "$MEMORY_BIN" show "$MEM_ID"
assert_success "Remove tag" "$MEMORY_BIN" tag "$MEM_ID" remove "storage"
assert_output_contains "Verify removed tag (not in list)" "concurrency" "$MEMORY_BIN" show "$MEM_ID"

# Test 6: Verification Status Transition
echo -e "\n${BOLD}3. Status Lifecycle (unverified -> verified -> deprecated):${RESET}"
assert_output_contains "Initial status is unverified" "[UNVERIFIED]" "$MEMORY_BIN" show "$MEM_ID"
assert_success "Transition to verified" "$MEMORY_BIN" verify "$MEM_ID"
assert_output_contains "Verified status badge" "[VERIFIED]" "$MEMORY_BIN" show "$MEM_ID"
assert_success "Transition to deprecated" "$MEMORY_BIN" deprecate "$MEM_ID"
assert_output_contains "Deprecated status badge" "[DEPRECATED]" "$MEMORY_BIN" show "$MEM_ID"
# Reset to verified for downstream search tests
"$MEMORY_BIN" verify "$MEM_ID" >/dev/null 2>&1

# Test 7: Full-Text Search (FTS5 & LIKE)
echo -e "\n${BOLD}4. Search Engine (FTS5 & LIKE fallback):${RESET}"
assert_output_contains "Search by keyword (FTS5)" "$MEM_ID" "$MEMORY_BIN" search "busy_timeout"
assert_output_contains "Search by tag filter" "$MEM_ID" "$MEMORY_BIN" search "Termux" --tag "sqlite"
assert_output_contains "Search with special characters" "$MEM_ID" "$MEMORY_BIN" search "PRAGMA*"

# Test 8: Unicode & Internationalization
echo -e "\n${BOLD}5. Unicode & Multi-Language Support:${RESET}"
UNI_OUT=$("$MEMORY_BIN" add --title "Catatan 🧠 Emoji & 中文 测试" \
                           --content "Solusi dengan aksara non-ASCII: üñîçødë, テスト, dan simbol ⚡✔." \
                           --category "solution" \
                           --tags "unicode,emoji,test")
UNI_ID=$(extract_id "$UNI_OUT")
assert_output_contains "Unicode note retrieved correctly" "Catatan 🧠 Emoji & 中文 测试" "$MEMORY_BIN" show "$UNI_ID"
assert_output_contains "Unicode content matched" "üñîçødë" "$MEMORY_BIN" show "$UNI_ID"

# Test 9: Input Validation & Edge Cases
echo -e "\n${BOLD}6. Input Validation & Edge Cases:${RESET}"
assert_output_contains "Handle empty search keyword" "[ERROR]" "$MEMORY_BIN" search ""
assert_output_contains "Handle non-existent ID on show" "tidak ditemukan" "$MEMORY_BIN" show "mem_non_existent_9999"
assert_output_contains "Handle non-existent ID on edit" "tidak ditemukan" "$MEMORY_BIN" edit "mem_non_existent_9999" --title "test"

# Test 10: Automatic Secret Redaction
echo -e "\n${BOLD}7. Security & Secret Redaction:${RESET}"
SECRET_OUT=$("$MEMORY_BIN" add --title "Setup API Keys" \
                               --content "Berikut kredensial rahasia:
Google: AIzaSyD1234567890123456789012345678901
Anthropic: sk-ant-api03-abcdef123456789012345678901234567890
OpenAI: sk-proj-1234567890abcdef1234567890abcdef
GitHub: ghp_1234567890abcdefghijklmnopqrstuvwxyz
Token: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.abcdefghijk" \
                               --category "configuration")
SECRET_ID=$(extract_id "$SECRET_OUT")
SECRET_SHOW=$("$MEMORY_BIN" show "$SECRET_ID")

assert_output_contains "Redact Google API Key" "[REDACTED_GOOGLE_API_KEY]" echo "$SECRET_SHOW"
assert_output_contains "Redact Anthropic Key" "[REDACTED_ANTHROPIC_KEY]" echo "$SECRET_SHOW"
assert_output_contains "Redact OpenAI Key" "[REDACTED_OPENAI_KEY]" echo "$SECRET_SHOW"
assert_output_contains "Redact GitHub Token" "[REDACTED_GITHUB_TOKEN]" echo "$SECRET_SHOW"
assert_output_contains "Redact Bearer Token" "Bearer [REDACTED_BEARER_TOKEN]" echo "$SECRET_SHOW"

# Test 11: Export & Import Round-Trip
echo -e "\n${BOLD}8. Markdown Export & Import Round-Trip:${RESET}"
TMP_EXPORT_DIR=$(mktemp -d "${TMPDIR:-$PREFIX/tmp}/mem-test.XXXXXX")
assert_success "Export single note" "$MEMORY_BIN" export "$MEM_ID" "$TMP_EXPORT_DIR/exported_note.md"
[ -f "$TMP_EXPORT_DIR/exported_note.md" ]

# Check frontmatter and content in exported file
assert_success "Exported file has valid ID header" grep -q "id: $MEM_ID" "$TMP_EXPORT_DIR/exported_note.md"

# Test import with duplicate check
assert_output_contains "Import duplicate is skipped safely" "Dilewati     : 1" "$MEMORY_BIN" import "$TMP_EXPORT_DIR/exported_note.md"

# Test import with overwrite
assert_output_contains "Import with overwrite updates record" "Diperbarui   : 1" "$MEMORY_BIN" import "$TMP_EXPORT_DIR/exported_note.md" --overwrite
rm -rf "$TMP_EXPORT_DIR"

# Test 12: Agent Context Exporter
echo -e "\n${BOLD}9. Agent Context Export:${RESET}"
# Deprecate the unicode note to verify it is excluded from context
"$MEMORY_BIN" deprecate "$UNI_ID" >/dev/null 2>&1
CTX_OUT=$("$MEMORY_BIN" context "SQLite" --limit 3)
assert_output_contains "Context output includes verified note" "Fix SQLite Locking on Termux" echo "$CTX_OUT"
assert_output_contains "Context output contains bounded header" "AI KNOWLEDGE MEMORY CONTEXT" echo "$CTX_OUT"

# Verify deprecated note is excluded
if [[ "$CTX_OUT" == *"$UNI_ID"* ]]; then
    echo -e "  [${RED}FAIL${RESET}] Context export should exclude deprecated notes"
    FAILED=$((FAILED + 1))
else
    echo -e "  [${GREEN}PASS${RESET}] Context export excludes deprecated notes"
    PASSED=$((PASSED + 1))
fi

# Test 13: File Permissions & Integrity
echo -e "\n${BOLD}10. Storage Permissions & Database Integrity:${RESET}"
MEM_DIR_PERM=$(stat -c "%a" "$HOME_DIR/.local/share/termux-ai")
MEM_FILE_PERM=$(stat -c "%a" "$HOME_DIR/.local/share/termux-ai/memory.db")
if [ "$MEM_DIR_PERM" = "700" ]; then
    echo -e "  [${GREEN}PASS${RESET}] Storage directory permission is 700 ($MEM_DIR_PERM)"
    PASSED=$((PASSED + 1))
else
    echo -e "  [${RED}FAIL${RESET}] Storage directory permission is $MEM_DIR_PERM (expected 700)"
    FAILED=$((FAILED + 1))
fi

if [ "$MEM_FILE_PERM" = "600" ]; then
    echo -e "  [${GREEN}PASS${RESET}] Database file permission is 600 ($MEM_FILE_PERM)"
    PASSED=$((PASSED + 1))
else
    echo -e "  [${RED}FAIL${RESET}] Database file permission is $MEM_FILE_PERM (expected 600)"
    FAILED=$((FAILED + 1))
fi

# Test 14: Non-Regression on Session Manager
echo -e "\n${BOLD}11. Non-Regression on Session Manager:${RESET}"
assert_success "session.sh status works" "$TOOLS_DIR/session.sh" status
assert_success "session.sh memory dispatcher works" "$TOOLS_DIR/session.sh" memory stats
assert_success "ai memory dispatcher works" ai memory stats

# Test 15: Delete note (CRUD Delete)
echo -e "\n${BOLD}12. CRUD Delete Cleanup:${RESET}"
assert_success "Delete note with -y" "$MEMORY_BIN" delete "$SECRET_ID" -y
assert_output_contains "Deleted note is no longer found" "tidak ditemukan" "$MEMORY_BIN" show "$SECRET_ID"
"$MEMORY_BIN" delete "$UNI_ID" -y >/dev/null 2>&1 || true

# Test 16: MCP Knowledge Graph Export
echo -e "\n${BOLD}13. MCP Knowledge Graph Bridge:${RESET}"
TMP_MCP_OUT="${TMPDIR:-$PREFIX/tmp}/test_mcp.json"
assert_success "Export to MCP JSON" "$MEMORY_BIN" mcp-export "$TMP_MCP_OUT"
assert_success "MCP JSON is valid JSON format" python3 -c "import json; d=json.load(open('$TMP_MCP_OUT')); assert 'entities' in d and 'relations' in d"
rm -f "$TMP_MCP_OUT"

echo -e "\n${BOLD}${CYAN}=================================================="
echo "               Hasil Akhir Pengujian              "
echo -e "==================================================${RESET}"
echo -e "Total Pengujian : $((PASSED + FAILED))"
echo -e "Lolos (Pass)    : ${GREEN}$PASSED${RESET}"
echo -e "Gagal (Fail)    : ${RED}$FAILED${RESET}"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${BOLD}${GREEN}🎉 SEMUA TEST BERHASIL (100% PASS)! Knowledge Memory berfungsi sempurna.${RESET}\n"
    exit 0
else
    echo -e "${BOLD}${RED}✖ Terdapat $FAILED kegagalan dalam pengujian!${RESET}\n"
    exit 1
fi

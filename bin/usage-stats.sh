#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================================
# AI Usage Statistics - Token & Request Counter
# Command: ai usage [--opencode|--agy|--all]
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME="${HOME:-/data/data/com.termux/files/home}"

GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BLUE="\033[34m"
MAGENTA="\033[35m"
RED="\033[31m"
BOLD="\033[1m"
DIM="\033[2m"
RESET="\033[0m"

# ── Helpers ──────────────────────────────────────────────────────────────────

fmt_num() {
    # Format large numbers with K/M suffix
    local n="$1"
    if [ -z "$n" ] || [ "$n" = "None" ] || [ "$n" = "null" ]; then
        echo "0"
        return
    fi
    python3 -c "
n = int('$n')
if n >= 1_000_000:
    print(f'{n/1_000_000:.2f}M')
elif n >= 1_000:
    print(f'{n/1_000:.1f}K')
else:
    print(str(n))
"
}

# ── OpenCode Stats ────────────────────────────────────────────────────────────

show_opencode_stats() {
    local db="$HOME/.local/share/opencode/opencode.db"

    echo -e "\n${BOLD}${CYAN}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${CYAN}│        OpenCode Usage Statistics        │${RESET}"
    echo -e "${BOLD}${CYAN}└─────────────────────────────────────────┘${RESET}\n"

    if [ ! -f "$db" ]; then
        echo -e "  ${RED}✗ Database tidak ditemukan:${RESET} $db"
        return 1
    fi

    python3 - "$db" << 'PYEOF'
import sys, sqlite3, json

db = sys.argv[1]
try:
    conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
except Exception as e:
    print(f"  \033[31mError membuka DB: {e}\033[0m")
    sys.exit(1)

BOLD   = "\033[1m"
GREEN  = "\033[32m"
YELLOW = "\033[33m"
CYAN   = "\033[36m"
BLUE   = "\033[34m"
MAGENTA= "\033[35m"
DIM    = "\033[2m"
RESET  = "\033[0m"

def fmt(n):
    if not n: return "0"
    n = int(n)
    if n >= 1_000_000: return f"{n/1_000_000:.2f}M"
    if n >= 1_000:     return f"{n/1_000:.1f}K"
    return str(n)

# ── Totals ────────────────────────────────────────────────────────────
row = conn.execute("""
    SELECT
        COUNT(*) as requests,
        COALESCE(SUM(json_extract(data,'$.tokens.input')),0)     as input_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.output')),0)    as output_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.cache.read')),0) as cache_read,
        COALESCE(SUM(json_extract(data,'$.tokens.cache.write')),0)as cache_write,
        COALESCE(SUM(json_extract(data,'$.cost')),0)             as cost
    FROM message
    WHERE json_extract(data,'$.role')='assistant'
""").fetchone()

total_req, in_tok, out_tok, cache_r, cache_w, cost = row
total_tok = in_tok + out_tok

print(f"  {BOLD}Total Requests  {RESET}: {CYAN}{fmt(total_req)}{RESET}")
print(f"  {BOLD}Total Tokens    {RESET}: {GREEN}{fmt(total_tok)}{RESET}")
print(f"  {BOLD}  ├─ Input      {RESET}: {fmt(in_tok)}")
print(f"  {BOLD}  ├─ Output     {RESET}: {fmt(out_tok)}")
print(f"  {BOLD}  ├─ Cache Read {RESET}: {DIM}{fmt(cache_r)}{RESET}")
print(f"  {BOLD}  └─ Cache Write{RESET}: {DIM}{fmt(cache_w)}{RESET}")
if cost and float(cost) > 0:
    print(f"  {BOLD}Total Cost      {RESET}: {YELLOW}${float(cost):.4f}{RESET}")
else:
    print(f"  {BOLD}Total Cost      {RESET}: {DIM}Free/No data{RESET}")

# ── Session count ─────────────────────────────────────────────────────
sess_count = conn.execute("SELECT COUNT(*) FROM session").fetchone()[0]
print(f"  {BOLD}Sessions        {RESET}: {fmt(sess_count)}")

# ── Per-model breakdown ───────────────────────────────────────────────
rows = conn.execute("""
    SELECT
        json_extract(data,'$.providerID') as provider,
        json_extract(data,'$.modelID')    as model,
        COUNT(*)                          as reqs,
        COALESCE(SUM(json_extract(data,'$.tokens.input')),0)  as in_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.output')),0) as out_tok
    FROM message
    WHERE json_extract(data,'$.role')='assistant'
    GROUP BY provider, model
    ORDER BY reqs DESC
    LIMIT 10
""").fetchall()

if rows:
    print(f"\n  {BOLD}Per-Model Breakdown:{RESET}")
    print(f"  {DIM}{'Model':<35} {'Requests':>10} {'Input':>10} {'Output':>10}{RESET}")
    print(f"  {DIM}{'─'*35} {'─'*10} {'─'*10} {'─'*10}{RESET}")
    for r in rows:
        provider, model, reqs, in_t, out_t = r
        label = f"{provider}/{model}" if provider else (model or "unknown")
        label = label[:34]
        print(f"  {label:<35} {CYAN}{fmt(reqs):>10}{RESET} {fmt(in_t):>10} {fmt(out_t):>10}")

conn.close()
PYEOF
}

# ── AGY Stats ─────────────────────────────────────────────────────────────────

show_agy_stats() {
    local conv_dir="$HOME/.gemini/antigravity-cli/conversations"
    local brain_dir="$HOME/.gemini/antigravity-cli/brain"

    echo -e "\n${BOLD}${MAGENTA}┌─────────────────────────────────────────┐${RESET}"
    echo -e "${BOLD}${MAGENTA}│     Antigravity (AGY) Usage Statistics  │${RESET}"
    echo -e "${BOLD}${MAGENTA}└─────────────────────────────────────────┘${RESET}\n"

    if [ ! -d "$conv_dir" ] && [ ! -d "$brain_dir" ]; then
        echo -e "  ${RED}✗ Direktori AGY tidak ditemukan${RESET}"
        return 1
    fi

    python3 - "$conv_dir" "$brain_dir" << 'PYEOF'
import sys, os, glob, sqlite3, json

conv_dir  = sys.argv[1]
brain_dir = sys.argv[2]

BOLD    = "\033[1m"
GREEN   = "\033[32m"
YELLOW  = "\033[33m"
CYAN    = "\033[36m"
MAGENTA = "\033[35m"
DIM     = "\033[2m"
RESET   = "\033[0m"

def fmt(n):
    if not n: return "0"
    n = int(n)
    if n >= 1_000_000: return f"{n/1_000_000:.2f}M"
    if n >= 1_000:     return f"{n/1_000:.1f}K"
    return str(n)

# ── Count API requests from gen_metadata in conversation DBs ──────────
dbs = glob.glob(os.path.join(conv_dir, "*.db")) if os.path.isdir(conv_dir) else []
total_requests = 0
total_convs    = len(dbs)

for db in dbs:
    try:
        conn = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        tables = [r[0] for r in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()]
        if "gen_metadata" in tables:
            c = conn.execute("SELECT COUNT(*) FROM gen_metadata").fetchone()[0]
            total_requests += c
        conn.close()
    except:
        pass

# ── Parse token usage from JSONL transcripts ──────────────────────────
# AGY stores token info in the gen_metadata protobuf, but also exposes
# input/output counts in some transcript tool_call responses.
# We scan for the structured usage fields in full transcript files.
transcripts = glob.glob(os.path.join(brain_dir, "*/.system_generated/logs/transcript_full.jsonl"))
total_input  = 0
total_output = 0
total_cache  = 0
parsed_convs = 0

for tf in transcripts:
    found = False
    try:
        with open(tf, "r", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                    # Tool call responses can contain usage
                    for tc in d.get("tool_calls", []):
                        result = tc.get("result", {})
                        if isinstance(result, dict):
                            usage = result.get("usage", {})
                            if usage:
                                total_input  += usage.get("input_tokens", 0)
                                total_output += usage.get("output_tokens", 0)
                                total_cache  += usage.get("cache_read_input_tokens", 0)
                                found = True
                    # Also check content list items
                    content = d.get("content", [])
                    if isinstance(content, list):
                        for item in content:
                            if isinstance(item, dict):
                                usage = item.get("usage", {})
                                if usage:
                                    total_input  += usage.get("input_tokens", 0)
                                    total_output += usage.get("output_tokens", 0)
                                    found = True
                except:
                    pass
    except:
        pass
    if found:
        parsed_convs += 1

total_tokens = total_input + total_output

print(f"  {BOLD}Total Conversations {RESET}: {MAGENTA}{fmt(total_convs)}{RESET}")
print(f"  {BOLD}Total API Requests  {RESET}: {CYAN}{fmt(total_requests)}{RESET}")

if total_tokens > 0:
    print(f"  {BOLD}Total Tokens        {RESET}: {GREEN}{fmt(total_tokens)}{RESET}")
    print(f"  {BOLD}  ├─ Input          {RESET}: {fmt(total_input)}")
    print(f"  {BOLD}  ├─ Output         {RESET}: {fmt(total_output)}")
    if total_cache > 0:
        print(f"  {BOLD}  └─ Cache Read     {RESET}: {DIM}{fmt(total_cache)}{RESET}")
else:
    print(f"  {BOLD}Token Details       {RESET}: {DIM}Data tersimpan dalam format protobuf (tidak dapat di-parse){RESET}")
    print(f"  {DIM}  Gunakan /usage di dalam sesi AGY untuk melihat token per-sesi{RESET}")

# ── History stats ─────────────────────────────────────────────────────
hist = os.path.join(os.path.dirname(brain_dir), "history.jsonl")
slash_usage = 0
if os.path.exists(hist):
    with open(hist) as f:
        for line in f:
            try:
                d = json.loads(line)
                if d.get("type") == "slash_command" and "/usage" in d.get("display",""):
                    slash_usage += 1
            except:
                pass

print(f"  {BOLD}Transcripts Tersimpan{RESET}: {fmt(len(transcripts))}")
PYEOF
}

# ── Main ──────────────────────────────────────────────────────────────────────

show_header() {
    echo -e "${BOLD}╔══════════════════════════════════════════╗${RESET}"
    echo -e "${BOLD}║         AI Tools Usage Statistics        ║${RESET}"
    echo -e "${BOLD}╚══════════════════════════════════════════╝${RESET}"
    echo -e "${DIM}  Menghitung token & request dari database lokal...${RESET}"
}

case "${1:-all}" in
    --opencode|oc|opencode)
        show_header
        show_opencode_stats
        ;;
    --agy|agy|antigravity)
        show_header
        show_agy_stats
        ;;
    --all|all|"")
        show_header
        show_opencode_stats
        show_agy_stats
        ;;
    --help|-h|help)
        echo -e "
${BOLD}ai usage${RESET} — Lihat statistik pemakaian token & request AI

${BOLD}Usage:${RESET}
  ai usage             # Tampilkan semua (OpenCode + AGY)
  ai usage --opencode  # Hanya OpenCode
  ai usage --agy       # Hanya Antigravity CLI

${BOLD}Data sumber:${RESET}
  OpenCode : ~/.local/share/opencode/opencode.db
  AGY      : ~/.gemini/antigravity-cli/conversations/*.db
"
        ;;
    *)
        echo -e "${RED}Opsi tidak dikenal: $1${RESET}"
        echo "Gunakan: ai usage [--opencode|--agy|--all|--help]"
        exit 1
        ;;
esac

echo ""

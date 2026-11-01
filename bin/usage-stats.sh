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

    python3 - "$db" "$DAYS" << 'PYEOF'
import sys, sqlite3, json, datetime

db   = sys.argv[1]
days = int(sys.argv[2]) if len(sys.argv) > 2 and str(sys.argv[2]).isdigit() else 14
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

# ── Deteksi skema storage ─────────────────────────────────────────────
# OpenCode v2 menyimpan pesan di tabel `session_message` (kolom `type`),
# sedangkan versi lama memakai tabel `message` (role di dalam JSON `data`).
# Keduanya memakai struktur token yang sama di `data`. Saat migrasi v1→v2,
# sebagian pesan lama bisa tertinggal di tabel `message`, jadi keduanya
# digabung dan dideduplikasi berdasarkan message id.
tables = {r[0] for r in conn.execute(
    "SELECT name FROM sqlite_master WHERE type='table'"
).fetchall()}

has_v2 = "session_message" in tables
has_v1 = "message" in tables

if has_v2 and has_v1:
    SOURCE = """
    WITH msgs AS (
        SELECT id, time_created, data FROM session_message WHERE type='assistant'
        UNION ALL
        SELECT id, time_created, data FROM message
         WHERE json_extract(data,'$.role')='assistant'
           AND id NOT IN (SELECT id FROM session_message WHERE type='assistant')
    )"""
    SCHEMA_LABEL = "v2 session_message + legacy message (gabungan)"
elif has_v2:
    SOURCE = "WITH msgs AS (SELECT id, time_created, data FROM session_message WHERE type='assistant')"
    SCHEMA_LABEL = "v2 (session_message)"
else:
    SOURCE = "WITH msgs AS (SELECT id, time_created, data FROM message WHERE json_extract(data,'$.role')='assistant')"
    SCHEMA_LABEL = "v1 (message)"

MODEL_EXPR = ("COALESCE(json_extract(data,'$.model.providerID'), json_extract(data,'$.providerID')), "
              "COALESCE(json_extract(data,'$.model.id'), json_extract(data,'$.modelID'))")

def fmt(n):
    if not n: return "0"
    n = int(n)
    if n >= 1_000_000: return f"{n/1_000_000:.2f}M"
    if n >= 1_000:     return f"{n/1_000:.1f}K"
    return str(n)

def bar(value, max_value, width=18):
    if not max_value or value <= 0:
        return ""
    n = int(round(value / max_value * width))
    return "█" * max(n, 1)

# ── Totals ────────────────────────────────────────────────────────────
row = conn.execute(f"""{SOURCE}
    SELECT
        COUNT(*) as requests,
        COALESCE(SUM(json_extract(data,'$.tokens.input')),0)     as input_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.output')),0)    as output_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.cache.read')),0) as cache_read,
        COALESCE(SUM(json_extract(data,'$.tokens.cache.write')),0)as cache_write,
        COALESCE(SUM(json_extract(data,'$.cost')),0)             as cost
    FROM msgs
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
sess_table = "session_v2" if "session_v2" in tables else "session"
sess_count = conn.execute(f"SELECT COUNT(*) FROM {sess_table}").fetchone()[0]
print(f"  {BOLD}Sessions        {RESET}: {fmt(sess_count)}")
print(f"  {DIM}Schema storage  : {SCHEMA_LABEL}{RESET}")

# ── Per-day breakdown ─────────────────────────────────────────────────
daily = conn.execute(f"""{SOURCE}
    SELECT
        date(time_created/1000,'unixepoch','localtime') as day,
        COUNT(*) as reqs,
        COALESCE(SUM(json_extract(data,'$.tokens.input')),0)  as in_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.output')),0) as out_tok,
        COALESCE(SUM(json_extract(data,'$.cost')),0)          as cost
    FROM msgs
    WHERE date(time_created/1000,'unixepoch','localtime') >= date('now','localtime',?)
    GROUP BY day
    ORDER BY day DESC
""", (f"-{days - 1} days",)).fetchall()

print(f"\n  {BOLD}Per-Hari ({days} hari terakhir):{RESET}")
by_day = {r[0]: r for r in daily}
today = datetime.date.today()
ordered = []
for offset in range(days):
    day = (today - datetime.timedelta(days=offset)).isoformat()
    row = by_day.get(day)
    ordered.append(row if row else (day, 0, 0, 0, 0))
max_total = max((r[2] + r[3]) for r in ordered) or 1
if not any(r[1] for r in ordered):
    print(f"  {DIM}(belum ada aktivitas pada rentang ini){RESET}")
print(f"  {DIM}{'Tanggal':<12} {'Req':>5} {'Input':>9} {'Output':>9} {'Total':>9} {'Cost':>9}{RESET}")
print(f"  {DIM}{'─'*12} {'─'*5} {'─'*9} {'─'*9} {'─'*9} {'─'*9}{RESET}")
for day, reqs, in_t, out_t, dcost in ordered:
    total = in_t + out_t
    cost_str = f"${float(dcost):.4f}" if dcost and float(dcost) > 0 else "-"
    print(f"  {day:<12} {CYAN}{fmt(reqs):>5}{RESET} {fmt(in_t):>9} {fmt(out_t):>9} "
          f"{GREEN}{fmt(total):>9}{RESET} {YELLOW}{cost_str:>9}{RESET} {MAGENTA}{bar(total, max_total)}{RESET}")
sum_reqs = sum(r[1] for r in ordered)
sum_total = sum(r[2] + r[3] for r in ordered)
sum_cost = sum(float(r[4] or 0) for r in ordered)
cost_total = f"${sum_cost:.4f}" if sum_cost > 0 else "-"
print(f"  {DIM}{'─'*12} {'─'*5} {'─'*9} {'─'*9} {'─'*9} {'─'*9}{RESET}")
print(f"  {BOLD}{'SUBTOTAL':<12} {fmt(sum_reqs):>5} {'':>9} {'':>9} {fmt(sum_total):>9} {cost_total:>9}{RESET}")

# ── Per-model breakdown ───────────────────────────────────────────────
rows = conn.execute(f"""{SOURCE}
    SELECT
        {MODEL_EXPR},
        COUNT(*)                          as reqs,
        COALESCE(SUM(json_extract(data,'$.tokens.input')),0)  as in_tok,
        COALESCE(SUM(json_extract(data,'$.tokens.output')),0) as out_tok
    FROM msgs
    GROUP BY 1, 2
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

    python3 - "$conv_dir" "$brain_dir" "$DAYS" << 'PYEOF'
import sys, os, glob, sqlite3, json, datetime

conv_dir  = sys.argv[1]
brain_dir = sys.argv[2]
days      = int(sys.argv[3]) if len(sys.argv) > 3 and str(sys.argv[3]).isdigit() else 14

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
daily        = {}
cutoff       = datetime.date.today() - datetime.timedelta(days=days - 1)

def bar(value, max_value, width=18):
    if not max_value or value <= 0:
        return ""
    n = int(round(value / max_value * width))
    return "█" * max(n, 1)

def parse_day(value):
    if not value:
        return None
    try:
        dt = datetime.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return dt.astimezone().date()
    except Exception:
        return None

def add_usage(day, in_tok, out_tok, cache_tok=0):
    global total_input, total_output, total_cache
    in_tok    = int(in_tok or 0)
    out_tok   = int(out_tok or 0)
    cache_tok = int(cache_tok or 0)
    total_input  += in_tok
    total_output += out_tok
    total_cache  += cache_tok
    if day is None or day < cutoff:
        return
    rec = daily.setdefault(day, {"reqs": 0, "in": 0, "out": 0, "cache": 0})
    rec["reqs"] += 1
    rec["in"]   += in_tok
    rec["out"]  += out_tok
    rec["cache"] += cache_tok

for tf in transcripts:
    found = False
    try:
        with open(tf, "r", errors="replace") as f:
            for line in f:
                try:
                    d = json.loads(line)
                except Exception:
                    continue
                day = parse_day(d.get("created_at"))

                # Format utama AGY: token usage langsung di level atas transkrip
                if d.get("input_tokens") is not None or d.get("output_tokens") is not None:
                    add_usage(day,
                              int(d.get("input_tokens") or 0),
                              int(d.get("output_tokens") or 0),
                              int(d.get("cache_read_tokens") or 0))
                    found = True
                    continue

                # Fallback: tool call responses / content items yang menyertakan usage
                for tc in d.get("tool_calls", []) or []:
                    result = tc.get("result", {})
                    if isinstance(result, dict):
                        usage = result.get("usage", {})
                        if usage:
                            add_usage(day,
                                      usage.get("input_tokens", 0),
                                      usage.get("output_tokens", 0),
                                      usage.get("cache_read_input_tokens", 0))
                            found = True
                content = d.get("content", [])
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict):
                            usage = item.get("usage", {})
                            if usage:
                                add_usage(day,
                                          usage.get("input_tokens", 0),
                                          usage.get("output_tokens", 0),
                                          usage.get("cache_read_input_tokens", 0))
                                found = True
    except Exception:
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
    print(f"  {BOLD}Token Details       {RESET}: {DIM}Belum ada data token usage pada transcript{RESET}")
    print(f"  {DIM}  Gunakan /usage di dalam sesi AGY untuk melihat token per-sesi{RESET}")

# ── Per-day breakdown ─────────────────────────────────────────────────
print(f"\n  {BOLD}Per-Hari ({days} hari terakhir):{RESET}")
ordered = []
for offset in range(days):
    day = datetime.date.today() - datetime.timedelta(days=offset)
    ordered.append((day, daily.get(day, {"reqs": 0, "in": 0, "out": 0, "cache": 0})))
max_total = max((r["in"] + r["out"]) for _, r in ordered) or 1
if not any(r["reqs"] for _, r in ordered):
    print(f"  {DIM}(belum ada data token pada rentang ini){RESET}")
print(f"  {DIM}{'Tanggal':<12} {'Req':>5} {'Input':>9} {'Output':>9} {'Total':>9}{RESET}")
print(f"  {DIM}{'─'*12} {'─'*5} {'─'*9} {'─'*9} {'─'*9}{RESET}")
for day, r in ordered:
    total = r["in"] + r["out"]
    print(f"  {day.isoformat():<12} {CYAN}{fmt(r['reqs']):>5}{RESET} {fmt(r['in']):>9} {fmt(r['out']):>9} "
          f"{GREEN}{fmt(total):>9}{RESET} {MAGENTA}{bar(total, max_total)}{RESET}")
sum_reqs  = sum(r["reqs"] for _, r in ordered)
sum_total = sum(r["in"] + r["out"] for _, r in ordered)
print(f"  {DIM}{'─'*12} {'─'*5} {'─'*9} {'─'*9} {'─'*9}{RESET}")
print(f"  {BOLD}{'SUBTOTAL':<12} {fmt(sum_reqs):>5} {'':>9} {'':>9} {fmt(sum_total):>9}{RESET}")

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
    echo -e "${DIM}  Statistik harian: ${DAYS} hari terakhir${RESET}"
}

DAYS=14
TARGET="all"

while [ $# -gt 0 ]; do
    case "$1" in
        --opencode|oc|opencode) TARGET="opencode" ;;
        --agy|agy|antigravity)  TARGET="agy" ;;
        --all|all)              TARGET="all" ;;
        --days)                 shift; DAYS="${1:-14}" ;;
        --days=*)               DAYS="${1#*=}" ;;
        --help|-h|help)
            echo -e "
${BOLD}ai usage${RESET} — Lihat statistik pemakaian token & request AI

${BOLD}Usage:${RESET}
  ai usage                 # Tampilkan semua (OpenCode + AGY), 14 hari terakhir
  ai usage --opencode      # Hanya OpenCode
  ai usage --agy           # Hanya Antigravity CLI
  ai usage --days 7        # Batasi statistik harian ke N hari terakhir

${BOLD}Data sumber:${RESET}
  OpenCode : ~/.local/share/opencode/opencode.db (kolom time_created)
  AGY      : ~/.gemini/antigravity-cli/brain/*/.system_generated/logs/transcript_full.jsonl
"
            exit 0
            ;;
        *)
            echo -e "${RED}Opsi tidak dikenal: $1${RESET}"
            echo "Gunakan: ai usage [--opencode|--agy|--all] [--days N] [--help]"
            exit 1
            ;;
    esac
    shift
done

case "$DAYS" in
    ''|*[!0-9]*|0) DAYS=14 ;;
esac

show_header
case "$TARGET" in
    opencode) show_opencode_stats ;;
    agy)      show_agy_stats ;;
    *)        show_opencode_stats; show_agy_stats ;;
esac

echo ""

#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Knowledge Memory / AI Brain (memory.sh / aisession memory)
# Manages:
#   - Persistent Technical Knowledge Notes (CRUD, tags, categories)
#   - Verification Status (unverified, verified, deprecated)
#   - High-Speed Full-Text Search (SQLite FTS5 + LIKE fallback)
#   - Auto Secret Redaction (API Keys, Tokens, Private Keys)
#   - Turn-based Session-to-Knowledge Extraction
#   - Agent Context Exporter (Markdown for OpenCode, Antigravity, etc.)
#   - Portable Markdown Import / Export with YAML Frontmatter
#   - Dedicated Isolated Storage (~/.local/share/termux-ai/memory.db)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
MEMORY_DIR="$HOME_DIR/.local/share/termux-ai"
MEMORY_DB="$MEMORY_DIR/memory.db"
EXPORT_DIR="$HOME_DIR/memory-export"

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

if ! command -v python3 >/dev/null 2>&1; then
    log_err "Python3 diperlukan untuk menjalankan Knowledge Memory."
    echo "Jalankan: pkg install python"
    exit 1
fi

# Ensure storage directory exists with strict permissions (0700)
mkdir -p "$MEMORY_DIR" "$EXPORT_DIR"
chmod 700 "$MEMORY_DIR" 2>/dev/null || true

# ------------------------------------------------------------------------------
# Embedded Python Knowledge Memory Engine
# ------------------------------------------------------------------------------
run_python_engine() {
    python3 - "$@" << 'EOF'
import sys, os, sqlite3, json, datetime, re, shutil, uuid, textwrap

HOME = os.path.expanduser("~")
MEMORY_DIR = os.path.join(HOME, ".local/share/termux-ai")
MEMORY_DB = os.path.join(MEMORY_DIR, "memory.db")
EXPORT_DIR = os.path.join(HOME, "memory-export")

OPENCODE_DB = os.path.join(HOME, ".local/share/opencode/opencode.db")
AGY_DB = os.path.join(HOME, ".gemini/antigravity-cli/conversation_summaries.db")
AGY_CONV_DIR = os.path.join(HOME, ".gemini/antigravity-cli/conversations")

# Color constants
C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_DIM = "\033[2m"
C_GREEN = "\033[32m"
C_YELLOW = "\033[33m"
C_CYAN = "\033[36m"
C_RED = "\033[31m"
C_BLUE = "\033[34m"
C_MAGENTA = "\033[35m"

CATEGORIES = [
    "troubleshooting",
    "solution",
    "architecture",
    "configuration",
    "workflow",
    "decision",
    "lesson"
]

STATUSES = ["unverified", "verified", "deprecated"]

# ------------------------------------------------------------------------------
# Secret Redaction Patterns
# ------------------------------------------------------------------------------
SECRET_PATTERNS = [
    # Google API Key (AIzaSy...)
    (re.compile(r'AIza[0-9A-Za-z_\-]{30,}'), '[REDACTED_GOOGLE_API_KEY]'),
    # Anthropic API Key (sk-ant-...)
    (re.compile(r'sk-ant-[A-Za-z0-9_\-]{20,}'), '[REDACTED_ANTHROPIC_KEY]'),
    # OpenAI & generic sk- keys (sk-..., sk-proj-...)
    (re.compile(r'sk-(?:proj-)?[A-Za-z0-9_\-]{20,}'), '[REDACTED_OPENAI_KEY]'),
    # GitHub Tokens
    (re.compile(r'gh[pousr]_[A-Za-z0-9]{36,}'), '[REDACTED_GITHUB_TOKEN]'),
    (re.compile(r'github_pat_[A-Za-z0-9_]{36,}'), '[REDACTED_GITHUB_TOKEN]'),
    # Bearer tokens
    (re.compile(r'(?i)bearer\s+[A-Za-z0-9_\-\.]{25,}'), 'Bearer [REDACTED_BEARER_TOKEN]'),
    # RSA / EC / OPENSSH Private Keys
    (re.compile(r'-----BEGIN [A-Z0-9 ]+ PRIVATE KEY-----[\s\S]*?-----END [A-Z0-9 ]+ PRIVATE KEY-----'), '[REDACTED_PRIVATE_KEY]'),
    # Basic auth embedded in URLs: http(s)://user:pass@host
    (re.compile(r'(https?://)[^:\s@]+:([^@\s]+)@'), r'\1***:***@'),
    # Slack tokens
    (re.compile(r'xox[baprs]-[A-Za-z0-9\-]{20,}'), '[REDACTED_SLACK_TOKEN]'),
    # AWS access key
    (re.compile(r'AKIA[0-9A-Z]{16}'), '[REDACTED_AWS_KEY]')
]

def redact_secrets(text):
    """Scan and redact known secrets, return tuple of (sanitized_text, match_count)"""
    if not text:
        return text, 0
    redacted = text
    total_redacted = 0
    for pattern, repl in SECRET_PATTERNS:
        matches = len(pattern.findall(redacted))
        if matches > 0:
            total_redacted += matches
            redacted = pattern.sub(repl, redacted)
    return redacted, total_redacted

# ------------------------------------------------------------------------------
# Database Initialization & Connection
# ------------------------------------------------------------------------------
def get_db():
    os.makedirs(MEMORY_DIR, mode=0o700, exist_ok=True)
    con = sqlite3.connect(MEMORY_DB, timeout=5.0)
    con.execute("PRAGMA journal_mode = WAL;")
    con.execute("PRAGMA busy_timeout = 5000;")
    con.execute("PRAGMA foreign_keys = ON;")
    
    # Secure file permission (0600)
    try:
        os.chmod(MEMORY_DB, 0o600)
    except Exception:
        pass
        
    init_schema(con)
    return con

def init_schema(con):
    with con:
        con.execute("""
            CREATE TABLE IF NOT EXISTS memories (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                category TEXT NOT NULL DEFAULT 'troubleshooting',
                tags TEXT DEFAULT '',
                project TEXT DEFAULT '',
                tool TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                status TEXT NOT NULL DEFAULT 'unverified',
                source_session_id TEXT DEFAULT '',
                source_session_title TEXT DEFAULT '',
                metadata TEXT DEFAULT '{}'
            );
        """)
        
        # Check FTS5 Virtual Table Support
        try:
            con.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS memory_fts USING fts5(
                    id UNINDEXED,
                    title,
                    content,
                    category,
                    tags,
                    project,
                    content='memories',
                    content_rowid='rowid'
                );
            """)
            
            # Sync triggers for FTS5
            con.execute("""
                CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
                    INSERT INTO memory_fts(rowid, id, title, content, category, tags, project)
                    VALUES (new.rowid, new.id, new.title, new.content, new.category, new.tags, new.project);
                END;
            """)
            con.execute("""
                CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
                    INSERT INTO memory_fts(memory_fts, rowid, id, title, content, category, tags, project)
                    VALUES ('delete', old.rowid, old.id, old.title, old.content, old.category, old.tags, old.project);
                END;
            """)
            con.execute("""
                CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE ON memories BEGIN
                    INSERT INTO memory_fts(memory_fts, rowid, id, title, content, category, tags, project)
                    VALUES ('delete', old.rowid, old.id, old.title, old.content, old.category, old.tags, old.project);
                    INSERT INTO memory_fts(rowid, id, title, content, category, tags, project)
                    VALUES (new.rowid, new.id, new.title, new.content, new.category, new.tags, new.project);
                END;
            """)
        except Exception:
            # Fallback if FTS5 is not compiled into sqlite3
            pass

def generate_id():
    now_str = datetime.datetime.now().strftime("%Y%m%d")
    short_uuid = uuid.uuid4().hex[:6]
    return f"mem_{now_str}_{short_uuid}"

def current_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def normalize_tags(tags_input):
    if not tags_input:
        return ""
    if isinstance(tags_input, list):
        tag_list = tags_input
    else:
        tag_list = [t.strip().lower() for t in str(tags_input).replace(";", ",").split(",")]
    cleaned = []
    for t in tag_list:
        t = re.sub(r'[^a-zA-Z0-9_\-\.]', '', t)
        if t and t not in cleaned:
            cleaned.append(t)
    return ",".join(cleaned)

def status_badge(status):
    status = (status or "unverified").lower()
    if status == "verified":
        return f"{C_GREEN}[VERIFIED]{C_RESET}"
    elif status == "deprecated":
        return f"{C_RED}[DEPRECATED]{C_RESET}"
    else:
        return f"{C_YELLOW}[UNVERIFIED]{C_RESET}"

# ------------------------------------------------------------------------------
# Action: ADD MEMORY
# ------------------------------------------------------------------------------
def action_add(args):
    # Parse CLI flags or interactive input
    title = ""
    content = ""
    category = "troubleshooting"
    tags = ""
    project = ""
    tool = ""
    status = "unverified"
    source_session_id = ""
    source_session_title = ""
    file_path = ""
    bypass_redaction = False

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("--title", "-t") and i + 1 < len(args):
            title = args[i + 1]
            i += 1
        elif arg in ("--content", "-c") and i + 1 < len(args):
            content = args[i + 1]
            i += 1
        elif arg in ("--category", "-k") and i + 1 < len(args):
            category = args[i + 1].lower()
            i += 1
        elif arg in ("--tags", "-g") and i + 1 < len(args):
            tags = args[i + 1]
            i += 1
        elif arg in ("--project", "-p") and i + 1 < len(args):
            project = args[i + 1]
            i += 1
        elif arg in ("--tool", "-m") and i + 1 < len(args):
            tool = args[i + 1]
            i += 1
        elif arg in ("--status", "-s") and i + 1 < len(args):
            status = args[i + 1].lower()
            i += 1
        elif arg in ("--session", "--sid") and i + 1 < len(args):
            source_session_id = args[i + 1]
            i += 1
        elif arg in ("--session-title",) and i + 1 < len(args):
            source_session_title = args[i + 1]
            i += 1
        elif arg in ("--file", "-f") and i + 1 < len(args):
            file_path = args[i + 1]
            i += 1
        elif arg == "--no-redact":
            bypass_redaction = True
        i += 1

    if file_path and os.path.exists(file_path):
        try:
            with open(file_path, "r", encoding="utf-8", errors="replace") as fp:
                file_content = fp.read()
            if not content:
                content = file_content
            if not title:
                title = os.path.basename(file_path)
        except Exception as e:
            print(f"{C_RED}[ERROR] Gagal membaca file: {e}{C_RESET}")
            return False

    # Interactive prompt if needed
    if not title:
        try:
            print(f"{C_BOLD}{C_CYAN}=== Tambah Catatan Pengetahuan Baru ==={C_RESET}")
            title = input(f"{C_BOLD}Judul Catatan:{C_RESET} ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nDibatalkan.")
            return False

    if not title:
        print(f"{C_RED}[ERROR] Judul catatan tidak boleh kosong!{C_RESET}")
        return False

    if not content:
        try:
            print(f"{C_BOLD}Isi / Solusi / Catatan (Ketik konten, akhiri dengan baris kosong dan ENTER, atau masukkan ringkasan):{C_RESET}")
            lines = []
            while True:
                line = input()
                if not line and lines:
                    break
                lines.append(line)
            content = "\n".join(lines).strip()
        except (KeyboardInterrupt, EOFError):
            print("\nDibatalkan.")
            return False

    if not content:
        print(f"{C_RED}[ERROR] Isi catatan tidak boleh kosong!{C_RESET}")
        return False

    if category not in CATEGORIES:
        print(f"{C_YELLOW}[WARN] Kategori '{category}' tidak standar. Menggunakan kategori default 'troubleshooting'.{C_RESET}")
        category = "troubleshooting"

    if status not in STATUSES:
        status = "unverified"

    # Secret Redaction Check
    redacted_matches = 0
    if not bypass_redaction:
        content, redacted_matches = redact_secrets(content)
        title, title_redacted = redact_secrets(title)
        redacted_matches += title_redacted
        if redacted_matches > 0:
            print(f"{C_YELLOW}⚠️ [PERINGATAN KEAMANAN] Ditemukan {redacted_matches} pola kredensial sensitif (API Key, token, atau private key).{C_RESET}")
            print(f"{C_GREEN}✔ Konten telah disensor otomatis sebelum disimpan ke database.{C_RESET}")

    mem_id = generate_id()
    now_iso = current_iso()
    norm_tags = normalize_tags(tags)

    con = get_db()
    try:
        with con:
            con.execute("""
                INSERT INTO memories (
                    id, title, content, category, tags, project, tool,
                    created_at, updated_at, status, source_session_id, source_session_title, metadata
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                mem_id, title, content, category, norm_tags, project, tool,
                now_iso, now_iso, status, source_session_id, source_session_title, "{}"
            ))
        print(f"\n{C_GREEN}{C_BOLD}✔ Catatan Pengetahuan Berhasil Disimpan!{C_RESET}")
        print(f"  {C_CYAN}ID{C_RESET}       : {C_BOLD}{mem_id}{C_RESET}")
        print(f"  {C_CYAN}Judul{C_RESET}    : {title}")
        print(f"  {C_CYAN}Kategori{C_RESET} : {category}")
        print(f"  {C_CYAN}Status{C_RESET}   : {status_badge(status)}")
        print(f"  {C_CYAN}Tag{C_RESET}      : {norm_tags or '-'}")
        return True
    except Exception as e:
        print(f"{C_RED}[ERROR] Gagal menyimpan memori: {e}{C_RESET}")
        return False
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: LIST MEMORIES
# ------------------------------------------------------------------------------
def action_list(args):
    limit = 25
    filter_cat = None
    filter_status = None
    filter_tag = None
    filter_project = None
    as_json = False

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("--limit", "-l") and i + 1 < len(args):
            try: limit = int(args[i + 1])
            except ValueError: pass
            i += 1
        elif arg in ("--category", "-k") and i + 1 < len(args):
            filter_cat = args[i + 1].lower()
            i += 1
        elif arg in ("--status", "-s") and i + 1 < len(args):
            filter_status = args[i + 1].lower()
            i += 1
        elif arg in ("--tag", "-g") and i + 1 < len(args):
            filter_tag = args[i + 1].lower()
            i += 1
        elif arg in ("--project", "-p") and i + 1 < len(args):
            filter_project = args[i + 1]
            i += 1
        elif arg == "--json":
            as_json = True
        elif arg.isdigit() and i == 0:
            limit = int(arg)
        i += 1

    con = get_db()
    try:
        cur = con.cursor()
        query = "SELECT id, title, category, tags, status, updated_at, project FROM memories WHERE 1=1"
        params = []
        if filter_cat:
            query += " AND category = ?"
            params.append(filter_cat)
        if filter_status:
            query += " AND status = ?"
            params.append(filter_status)
        if filter_tag:
            query += " AND (tags = ? OR tags LIKE ? OR tags LIKE ? OR tags LIKE ?)"
            params.extend([filter_tag, f"{filter_tag},%", f"%,{filter_tag}", f"%,{filter_tag},%"])
        if filter_project:
            query += " AND project LIKE ?"
            params.append(f"%{filter_project}%")

        query += " ORDER BY updated_at DESC LIMIT ?"
        params.append(limit)

        rows = cur.execute(query, params).fetchall()

        if as_json:
            result = []
            for r in rows:
                result.append({
                    "id": r[0], "title": r[1], "category": r[2],
                    "tags": r[3].split(",") if r[3] else [],
                    "status": r[4], "updated_at": r[5], "project": r[6]
                })
            print(json.dumps(result, indent=2))
            return

        print(f"\n{C_BOLD}{C_CYAN}===================================================================================================={C_RESET}")
        print(f"{C_BOLD}                           DAFTAR KNOWLEDGE MEMORY / AI BRAIN                                       {C_RESET}")
        print(f"{C_BOLD}{C_CYAN}===================================================================================================={C_RESET}")
        print(f"{'ID MEMORI':<19} {'STATUS':<14} {'KATEGORI':<16} {'TAGS':<18} {'JUDUL':<32}")
        print("-" * 100)

        if not rows:
            print(f"  {C_DIM}Belum ada catatan memori yang tersimpan.{C_RESET}")
        else:
            for r in rows:
                mid, title, cat, tags_str, st, up_at, proj = r
                t_clean = (title or "").replace("\n", " ").strip()
                if len(t_clean) > 30:
                    t_clean = t_clean[:27] + "..."
                tags_clean = (tags_str or "-")
                if len(tags_clean) > 16:
                    tags_clean = tags_clean[:14] + ".."
                cat_clean = cat[:14]
                
                # Raw status text length for table formatting
                badge = status_badge(st)
                badge_pad = " " * (14 - len(st) - 2) if len(st) <= 12 else ""
                print(f"{C_BOLD}{mid:<19}{C_RESET} {badge}{badge_pad} {cat_clean:<16} {tags_clean:<18} {t_clean:<32}")

        print("-" * 100)
        total_count = cur.execute("SELECT count(*) FROM memories").fetchone()[0]
        print(f"Menampilkan {len(rows)} dari total {total_count} catatan.")
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: SHOW MEMORY
# ------------------------------------------------------------------------------
def action_show(mem_id):
    if not mem_id:
        print(f"{C_RED}[ERROR] Harap tentukan ID memori yang ingin ditampilkan.{C_RESET}")
        return False

    con = get_db()
    try:
        cur = con.cursor()
        r = cur.execute("""
            SELECT id, title, content, category, tags, project, tool,
                   created_at, updated_at, status, source_session_id, source_session_title, metadata
            FROM memories WHERE id = ?
        """, (mem_id,)).fetchone()

        if not r:
            print(f"{C_RED}[ERROR] Catatan memori dengan ID '{mem_id}' tidak ditemukan.{C_RESET}")
            return False

        mid, title, content, cat, tags_str, proj, tool, cr_at, up_at, st, s_id, s_title, meta = r

        print(f"\n{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
        print(f"{C_BOLD} 🧠 DETAIL KNOWLEDGE MEMORY: {C_YELLOW}{title}{C_RESET}")
        print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
        print(f"  {C_CYAN}ID Memori{C_RESET}       : {C_BOLD}{mid}{C_RESET}")
        print(f"  {C_CYAN}Status Verifikasi{C_RESET}: {status_badge(st)}")
        print(f"  {C_CYAN}Kategori{C_RESET}        : {C_BOLD}{cat}{C_RESET}")
        print(f"  {C_CYAN}Tagar (Tags){C_RESET}    : {tags_str or '-'}")
        print(f"  {C_CYAN}Proyek / Repo{C_RESET}   : {proj or '-'}")
        print(f"  {C_CYAN}Tool / Agent{C_RESET}    : {tool or '-'}")
        print(f"  {C_CYAN}Waktu Dibuat{C_RESET}    : {cr_at}")
        print(f"  {C_CYAN}Waktu Diperbarui{C_RESET}: {up_at}")
        if s_id:
            print(f"  {C_CYAN}Referensi Sesi{C_RESET}  : {s_id} ({s_title or 'Tanpa Judul'})")
        print("-" * 70)
        print(f"{C_BOLD}📝 Konten & Solusi Teknis:{C_RESET}\n")
        print(content)
        print("-" * 70)
        return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: SEARCH MEMORY (FTS5 + LIKE Fallback)
# ------------------------------------------------------------------------------
def action_search(query_str, args=[]):
    if not query_str:
        print(f"{C_RED}[ERROR] Tentukan kata kunci pencarian!{C_RESET}")
        return False

    filter_cat = None
    filter_status = None
    limit = 20
    as_json = False

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("--category", "-k") and i + 1 < len(args):
            filter_cat = args[i + 1].lower()
            i += 1
        elif arg in ("--status", "-s") and i + 1 < len(args):
            filter_status = args[i + 1].lower()
            i += 1
        elif arg in ("--limit", "-l") and i + 1 < len(args):
            try: limit = int(args[i + 1])
            except ValueError: pass
            i += 1
        elif arg == "--json":
            as_json = True
        i += 1

    con = get_db()
    rows = []
    used_engine = "FTS5"

    try:
        cur = con.cursor()
        # 1. Try SQLite FTS5 Match
        try:
            # Clean fts query string
            clean_q = re.sub(r'[^a-zA-Z0-9_\-\*\s]', ' ', query_str).strip()
            terms = [f'"{t}"*' for t in clean_q.split() if t]
            fts_query_str = " AND ".join(terms) if terms else query_str

            sql = """
                SELECT m.id, m.title, m.content, m.category, m.tags, m.status, m.updated_at, m.project
                FROM memory_fts f
                JOIN memories m ON f.rowid = m.rowid
                WHERE memory_fts MATCH ?
            """
            params = [fts_query_str]
            if filter_cat:
                sql += " AND m.category = ?"
                params.append(filter_cat)
            if filter_status:
                sql += " AND m.status = ?"
                params.append(filter_status)

            sql += " ORDER BY rank LIMIT ?"
            params.append(limit)
            rows = cur.execute(sql, params).fetchall()
        except Exception:
            # Fallback to standard LIKE
            used_engine = "LIKE"
            sql = """
                SELECT id, title, content, category, tags, status, updated_at, project
                FROM memories
                WHERE (title LIKE ? OR content LIKE ? OR tags LIKE ? OR project LIKE ?)
            """
            like_term = f"%{query_str}%"
            params = [like_term, like_term, like_term, like_term]
            if filter_cat:
                sql += " AND category = ?"
                params.append(filter_cat)
            if filter_status:
                sql += " AND status = ?"
                params.append(filter_status)

            sql += " ORDER BY updated_at DESC LIMIT ?"
            params.append(limit)
            rows = cur.execute(sql, params).fetchall()

        if as_json:
            result = []
            for r in rows:
                result.append({
                    "id": r[0], "title": r[1], "content": r[2], "category": r[3],
                    "tags": r[4].split(",") if r[4] else [], "status": r[5],
                    "updated_at": r[6], "project": r[7]
                })
            print(json.dumps(result, indent=2))
            return

        print(f"\n{C_BOLD}{C_CYAN}===================================================================================================={C_RESET}")
        print(f"{C_BOLD}   HASIL PENCARIAN KNOWLEDGE MEMORY ({used_engine}): '{C_YELLOW}{query_str}{C_RESET}{C_BOLD}'                      {C_RESET}")
        print(f"{C_BOLD}{C_CYAN}===================================================================================================={C_RESET}")
        print(f"{'ID MEMORI':<19} {'STATUS':<14} {'KATEGORI':<16} {'TAGS':<18} {'JUDUL':<32}")
        print("-" * 100)

        if not rows:
            print(f"  {C_DIM}Tidak ditemukan catatan yang cocok dengan kata kunci '{query_str}'.{C_RESET}")
        else:
            for r in rows:
                mid, title, content, cat, tags_str, st, up_at, proj = r
                t_clean = (title or "").replace("\n", " ").strip()
                if len(t_clean) > 30:
                    t_clean = t_clean[:27] + "..."
                tags_clean = (tags_str or "-")
                if len(tags_clean) > 16:
                    tags_clean = tags_clean[:14] + ".."
                cat_clean = cat[:14]

                badge = status_badge(st)
                badge_pad = " " * (14 - len(st) - 2) if len(st) <= 12 else ""
                print(f"{C_BOLD}{mid:<19}{C_RESET} {badge}{badge_pad} {cat_clean:<16} {tags_clean:<18} {t_clean:<32}")

        print("-" * 100)
        print(f"Ditemukan {len(rows)} catatan relevan.")
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: EDIT MEMORY
# ------------------------------------------------------------------------------
def action_edit(mem_id, args):
    if not mem_id:
        print(f"{C_RED}[ERROR] Tentukan ID memori yang ingin diubah!{C_RESET}")
        return False

    con = get_db()
    try:
        cur = con.cursor()
        r = cur.execute("SELECT id, title, content, category, tags, project, tool, status FROM memories WHERE id=?", (mem_id,)).fetchone()
        if not r:
            print(f"{C_RED}[ERROR] Memori dengan ID '{mem_id}' tidak ditemukan.{C_RESET}")
            return False

        mid, cur_title, cur_content, cur_cat, cur_tags, cur_proj, cur_tool, cur_status = r

        new_title = cur_title
        new_content = cur_content
        new_cat = cur_cat
        new_tags = cur_tags
        new_status = cur_status
        new_proj = cur_proj
        new_tool = cur_tool
        append_content = ""
        file_path = ""

        i = 0
        has_flags = False
        while i < len(args):
            arg = args[i]
            if arg in ("--title", "-t") and i + 1 < len(args):
                new_title = args[i + 1]
                has_flags = True
                i += 1
            elif arg in ("--content", "-c") and i + 1 < len(args):
                new_content = args[i + 1]
                has_flags = True
                i += 1
            elif arg in ("--append", "-a") and i + 1 < len(args):
                append_content = args[i + 1]
                has_flags = True
                i += 1
            elif arg in ("--category", "-k") and i + 1 < len(args):
                new_cat = args[i + 1].lower()
                has_flags = True
                i += 1
            elif arg in ("--tags", "-g") and i + 1 < len(args):
                new_tags = args[i + 1]
                has_flags = True
                i += 1
            elif arg in ("--status", "-s") and i + 1 < len(args):
                new_status = args[i + 1].lower()
                has_flags = True
                i += 1
            elif arg in ("--project", "-p") and i + 1 < len(args):
                new_proj = args[i + 1]
                has_flags = True
                i += 1
            elif arg in ("--file", "-f") and i + 1 < len(args):
                file_path = args[i + 1]
                has_flags = True
                i += 1
            i += 1

        if file_path and os.path.exists(file_path):
            with open(file_path, "r", encoding="utf-8", errors="replace") as fp:
                new_content = fp.read()

        if append_content:
            new_content = new_content.rstrip() + "\n\n" + append_content.strip()

        # If no flags provided, interactive prompt
        if not has_flags:
            print(f"{C_BOLD}{C_CYAN}=== Edit Catatan Memori: {mem_id} ==={C_RESET}")
            t_in = input(f"Judul [{cur_title}]: ").strip()
            if t_in: new_title = t_in
            c_in = input(f"Kategori [{cur_cat}]: ").strip()
            if c_in: new_cat = c_in
            g_in = input(f"Tagar [{cur_tags}]: ").strip()
            if g_in: new_tags = g_in
            s_in = input(f"Status (unverified/verified/deprecated) [{cur_status}]: ").strip()
            if s_in: new_status = s_in
            print(f"Tambahkan konten ke akhir? (Kosongkan jika tidak): ")
            add_c = input().strip()
            if add_c:
                new_content = new_content.rstrip() + "\n\n" + add_c

        # Redact secrets on update
        new_content, red_cnt = redact_secrets(new_content)
        new_title, _ = redact_secrets(new_title)
        if red_cnt > 0:
            print(f"{C_YELLOW}⚠️ Disensor {red_cnt} kredensial sensitif secara otomatis.{C_RESET}")

        if new_cat not in CATEGORIES:
            new_cat = cur_cat
        if new_status not in STATUSES:
            new_status = cur_status

        now_iso = current_iso()
        with con:
            con.execute("""
                UPDATE memories
                SET title=?, content=?, category=?, tags=?, project=?, tool=?, status=?, updated_at=?
                WHERE id=?
            """, (new_title, new_content, new_cat, normalize_tags(new_tags), new_proj, new_tool, new_status, now_iso, mem_id))

        print(f"{C_GREEN}{C_BOLD}✔ Memori {mem_id} berhasil diperbarui!{C_RESET}")
        return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: DELETE MEMORY
# ------------------------------------------------------------------------------
def action_delete(mem_id, force=False):
    if not mem_id:
        print(f"{C_RED}[ERROR] Tentukan ID memori yang ingin dihapus!{C_RESET}")
        return False

    con = get_db()
    try:
        cur = con.cursor()
        r = cur.execute("SELECT id, title FROM memories WHERE id=?", (mem_id,)).fetchone()
        if not r:
            print(f"{C_RED}[ERROR] Memori dengan ID '{mem_id}' tidak ditemukan.{C_RESET}")
            return False

        if not force:
            print(f"{C_YELLOW}{C_BOLD}PERHATIAN:{C_RESET} Anda akan menghapus catatan:")
            print(f"  ID    : {r[0]}")
            print(f"  Judul : {r[1]}")
            try:
                conf = input("Yakin ingin menghapus permanen? (y/N): ").strip().lower()
                if conf not in ("y", "yes"):
                    print("Penghapusan dibatalkan.")
                    return False
            except (KeyboardInterrupt, EOFError):
                print("\nDibatalkan.")
                return False

        with con:
            con.execute("DELETE FROM memories WHERE id=?", (mem_id,))

        print(f"{C_GREEN}{C_BOLD}✔ Catatan memori {mem_id} berhasil dihapus.{C_RESET}")
        return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: TAG MANAGEMENT (add / remove)
# ------------------------------------------------------------------------------
def action_tag(mem_id, op, tag_args):
    if not mem_id or not op or not tag_args:
        print(f"{C_RED}Gunakan: memory tag <id> [add|remove] <tag1,tag2...>{C_RESET}")
        return False

    con = get_db()
    try:
        cur = con.cursor()
        r = cur.execute("SELECT tags FROM memories WHERE id=?", (mem_id,)).fetchone()
        if not r:
            print(f"{C_RED}[ERROR] Memori dengan ID '{mem_id}' tidak ditemukan.{C_RESET}")
            return False

        cur_tags_list = [t for t in r[0].split(",") if t]
        tags_to_modify = [t.strip().lower() for t in ",".join(tag_args).split(",") if t.strip()]

        if op == "add":
            for t in tags_to_modify:
                t = re.sub(r'[^a-zA-Z0-9_\-\.]', '', t)
                if t and t not in cur_tags_list:
                    cur_tags_list.append(t)
        elif op in ("remove", "rm", "del"):
            cur_tags_list = [t for t in cur_tags_list if t not in tags_to_modify]
        else:
            print(f"{C_RED}[ERROR] Operasi tidak valid: {op}. Gunakan 'add' atau 'remove'.{C_RESET}")
            return False

        new_tags_str = ",".join(cur_tags_list)
        now_iso = current_iso()
        with con:
            con.execute("UPDATE memories SET tags=?, updated_at=? WHERE id=?", (new_tags_str, now_iso, mem_id))

        print(f"{C_GREEN}✔ Tag memori {mem_id} diperbarui: {new_tags_str or '-'}{C_RESET}")
        return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: VERIFY / DEPRECATE QUICK TOGGLE
# ------------------------------------------------------------------------------
def action_set_status(mem_id, new_status):
    if not mem_id:
        print(f"{C_RED}[ERROR] Tentukan ID memori.{C_RESET}")
        return False
    if new_status not in STATUSES:
        print(f"{C_RED}[ERROR] Status harus salah satu dari: {', '.join(STATUSES)}{C_RESET}")
        return False

    con = get_db()
    try:
        cur = con.cursor()
        r = cur.execute("SELECT title, status FROM memories WHERE id=?", (mem_id,)).fetchone()
        if not r:
            print(f"{C_RED}[ERROR] Memori dengan ID '{mem_id}' tidak ditemukan.{C_RESET}")
            return False

        now_iso = current_iso()
        with con:
            con.execute("UPDATE memories SET status=?, updated_at=? WHERE id=?", (new_status, now_iso, mem_id))

        print(f"{C_GREEN}✔ Status memori {mem_id} ({r[0]}) diubah: {r[1]} -> {status_badge(new_status)}{C_RESET}")
        return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: EXPORT TO MARKDOWN
# ------------------------------------------------------------------------------
def action_export(mem_id_or_all, out_target=None):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    con = get_db()
    try:
        cur = con.cursor()
        if mem_id_or_all in ("--all", "all"):
            rows = cur.execute("""
                SELECT id, title, content, category, tags, project, tool,
                       created_at, updated_at, status, source_session_id, source_session_title
                FROM memories ORDER BY updated_at DESC
            """).fetchall()
            if not rows:
                print(f"{C_YELLOW}Tidak ada catatan untuk diekspor.{C_RESET}")
                return False

            target_dir = out_target if out_target and os.path.isdir(out_target) else EXPORT_DIR
            count = 0
            for r in rows:
                mid, title, content, cat, tags_str, proj, tool, cr_at, up_at, st, s_id, s_title = r
                safe_title = re.sub(r'[^a-zA-Z0-9_-]', '_', (title or "mem")[:35])
                fn = f"{safe_title}_{mid}.md"
                fpath = os.path.join(target_dir, fn)
                tag_arr_str = json.dumps(tags_str.split(",") if tags_str else [])
                md_text = f"""---
id: {mid}
title: "{title.replace('"', '\\"')}"
category: {cat}
tags: {tag_arr_str}
project: "{proj}"
tool: "{tool}"
status: {st}
created_at: {cr_at}
updated_at: {up_at}
source_session_id: "{s_id}"
source_session_title: "{s_title}"
---

# {title}

{content}
"""
                with open(fpath, "w", encoding="utf-8") as fp:
                    fp.write(md_text)
                count += 1

            print(f"{C_GREEN}{C_BOLD}✔ Berhasil mengekspor {count} catatan memori ke direktori: {target_dir}{C_RESET}")
            return True
        else:
            mid = mem_id_or_all
            r = cur.execute("""
                SELECT id, title, content, category, tags, project, tool,
                       created_at, updated_at, status, source_session_id, source_session_title
                FROM memories WHERE id=?
            """, (mid,)).fetchone()
            if not r:
                print(f"{C_RED}[ERROR] Catatan memori '{mid}' tidak ditemukan.{C_RESET}")
                return False

            mid, title, content, cat, tags_str, proj, tool, cr_at, up_at, st, s_id, s_title = r
            safe_title = re.sub(r'[^a-zA-Z0-9_-]', '_', (title or "mem")[:35])
            fpath = out_target if out_target else os.path.join(EXPORT_DIR, f"{safe_title}_{mid}.md")

            tag_arr_str = json.dumps(tags_str.split(",") if tags_str else [])
            md_text = f"""---
id: {mid}
title: "{title.replace('"', '\\"')}"
category: {cat}
tags: {tag_arr_str}
project: "{proj}"
tool: "{tool}"
status: {st}
created_at: {cr_at}
updated_at: {up_at}
source_session_id: "{s_id}"
source_session_title: "{s_title}"
---

# {title}

{content}
"""
            with open(fpath, "w", encoding="utf-8") as fp:
                fp.write(md_text)

            print(f"{C_GREEN}{C_BOLD}✔ Berhasil diekspor ke: {fpath}{C_RESET}")
            return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: IMPORT FROM MARKDOWN
# ------------------------------------------------------------------------------
def parse_markdown_memory(file_path):
    with open(file_path, "r", encoding="utf-8", errors="replace") as fp:
        raw = fp.read()

    meta = {}
    content = raw
    if raw.startswith("---"):
        parts = raw.split("---", 2)
        if len(parts) >= 3:
            fm_text = parts[1]
            content = parts[2].strip()
            # Parse YAML frontmatter
            for line in fm_text.splitlines():
                line = line.strip()
                if ":" in line:
                    k, v = line.split(":", 1)
                    k = k.strip()
                    v = v.strip().strip('"').strip("'")
                    if k == "tags" and v.startswith("[") and v.endswith("]"):
                        try:
                            meta[k] = json.loads(v)
                        except Exception:
                            meta[k] = [t.strip() for t in v[1:-1].split(",") if t.strip()]
                    else:
                        meta[k] = v

    # Remove top level H1 matching title if present
    title = meta.get("title")
    if not title:
        m = re.search(r'^#\s+(.+)$', content, re.M)
        if m:
            title = m.group(1).strip()
            content = content[:m.start()] + content[m.end():]
            content = content.strip()
        else:
            title = os.path.splitext(os.path.basename(file_path))[0]

    return {
        "id": meta.get("id"),
        "title": title,
        "content": content,
        "category": meta.get("category", "troubleshooting"),
        "tags": meta.get("tags", []),
        "project": meta.get("project", ""),
        "tool": meta.get("tool", ""),
        "status": meta.get("status", "unverified"),
        "source_session_id": meta.get("source_session_id", ""),
        "source_session_title": meta.get("source_session_title", ""),
        "created_at": meta.get("created_at"),
        "updated_at": meta.get("updated_at")
    }

def action_import(target_path, overwrite=False, skip_duplicates=True):
    if not target_path or not os.path.exists(target_path):
        print(f"{C_RED}[ERROR] File atau direktori target '{target_path}' tidak ditemukan.{C_RESET}")
        return False

    files = []
    if os.path.isfile(target_path):
        files.append(target_path)
    else:
        for root, dirs, fnames in os.walk(target_path):
            for fn in fnames:
                if fn.endswith(".md"):
                    files.append(os.path.join(root, fn))

    if not files:
        print(f"{C_YELLOW}Tidak ada file Markdown (.md) ditemukan.{C_RESET}")
        return False

    con = get_db()
    imported = 0
    skipped = 0
    updated = 0

    try:
        cur = con.cursor()
        for fpath in files:
            data = parse_markdown_memory(fpath)
            mid = data.get("id") or generate_id()
            title = data.get("title")
            content = data.get("content")
            cat = data.get("category", "troubleshooting")
            if cat not in CATEGORIES: cat = "troubleshooting"
            status = data.get("status", "unverified")
            if status not in STATUSES: status = "unverified"
            tags = normalize_tags(data.get("tags"))
            now_iso = current_iso()
            cr_at = data.get("created_at") or now_iso
            up_at = data.get("updated_at") or now_iso

            # Redact secrets on import for safety
            content, _ = redact_secrets(content)
            title, _ = redact_secrets(title)

            # Check duplication by ID or by exact title + content hash
            existing_id = cur.execute("SELECT id FROM memories WHERE id=?", (mid,)).fetchone()
            existing_duplicate = cur.execute("SELECT id FROM memories WHERE title=? AND content=?", (title, content)).fetchone()

            if existing_id:
                if overwrite:
                    with con:
                        con.execute("""
                            UPDATE memories
                            SET title=?, content=?, category=?, tags=?, project=?, tool=?,
                                status=?, updated_at=?
                            WHERE id=?
                        """, (title, content, cat, tags, data.get("project", ""), data.get("tool", ""), status, up_at, mid))
                    updated += 1
                else:
                    skipped += 1
            elif existing_duplicate:
                # Same content already exists under different ID
                skipped += 1
            else:
                with con:
                    con.execute("""
                        INSERT INTO memories (
                            id, title, content, category, tags, project, tool,
                            created_at, updated_at, status, source_session_id, source_session_title, metadata
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        mid, title, content, cat, tags, data.get("project", ""), data.get("tool", ""),
                        cr_at, up_at, status, data.get("source_session_id", ""), data.get("source_session_title", ""), "{}"
                    ))
                imported += 1

        print(f"\n{C_GREEN}{C_BOLD}✔ Proses Impor Selesai!{C_RESET}")
        print(f"  Baru diimpor : {C_GREEN}{imported}{C_RESET}")
        print(f"  Diperbarui   : {C_CYAN}{updated}{C_RESET}")
        print(f"  Dilewati     : {C_DIM}{skipped}{C_RESET}")
        return True
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: AGENT CONTEXT EXPORTER
# ------------------------------------------------------------------------------
def action_context(query_str, limit=5, max_chars=4000, verified_only=False, out_file=None):
    con = get_db()
    try:
        cur = con.cursor()
        rows = []
        # Exclude deprecated notes from agent context by default
        if query_str and query_str != "*":
            try:
                # FTS5 search
                clean_q = re.sub(r'[^a-zA-Z0-9_\-\*\s]', ' ', query_str).strip()
                terms = [f'"{t}"*' for t in clean_q.split() if t]
                fts_query_str = " AND ".join(terms) if terms else query_str

                sql = """
                    SELECT m.id, m.title, m.content, m.category, m.tags, m.status, m.project, m.source_session_id
                    FROM memory_fts f
                    JOIN memories m ON f.rowid = m.rowid
                    WHERE memory_fts MATCH ? AND m.status != 'deprecated'
                """
                params = [fts_query_str]
                if verified_only:
                    sql += " AND m.status = 'verified'"
                # Order by verified status first, then rank
                sql += " ORDER BY CASE WHEN m.status = 'verified' THEN 0 ELSE 1 END, rank LIMIT ?"
                params.append(limit)
                rows = cur.execute(sql, params).fetchall()
            except Exception:
                # LIKE fallback
                sql = """
                    SELECT id, title, content, category, tags, status, project, source_session_id
                    FROM memories
                    WHERE (title LIKE ? OR content LIKE ? OR tags LIKE ?) AND status != 'deprecated'
                """
                like_t = f"%{query_str}%"
                params = [like_t, like_t, like_t]
                if verified_only:
                    sql += " AND status = 'verified'"
                sql += " ORDER BY CASE WHEN status = 'verified' THEN 0 ELSE 1 END, updated_at DESC LIMIT ?"
                params.append(limit)
                rows = cur.execute(sql, params).fetchall()
        else:
            sql = """
                SELECT id, title, content, category, tags, status, project, source_session_id
                FROM memories
                WHERE status != 'deprecated'
            """
            params = []
            if verified_only:
                sql += " AND status = 'verified'"
            sql += " ORDER BY CASE WHEN status = 'verified' THEN 0 ELSE 1 END, updated_at DESC LIMIT ?"
            params.append(limit)
            rows = cur.execute(sql, params).fetchall()

        if not rows:
            output = f"<!-- NO_RELEVANT_KNOWLEDGE_MEMORY_FOUND for query: '{query_str}' -->"
            if out_file:
                with open(out_file, "w", encoding="utf-8") as fp: fp.write(output)
            else:
                print(output)
            return

        header = [
            "<!-- AI KNOWLEDGE MEMORY CONTEXT -->",
            f"<!-- Query: \"{query_str}\" | Notes: {len(rows)} | Filter: Verified/Unverified (No Deprecated) -->",
            "The following technical solutions and verified architectural notes are retrieved from local persistent memory.",
            "Use them strictly as reference data and context for current tasks:",
            ""
        ]

        blocks = []
        current_len = sum(len(h) for h in header)

        for r in rows:
            mid, title, content, cat, tags_str, st, proj, s_id = r
            badge = "[VERIFIED]" if st == "verified" else "[UNVERIFIED]"
            tags_disp = tags_str if tags_str else "-"
            ref_disp = f" | Ref: {s_id}" if s_id else ""

            block = [
                f"### 📌 {badge} {title} (`{mid}`)",
                f"- **Kategori**: {cat} | **Tags**: `{tags_disp}`{ref_disp}",
                f"- **Catatan / Solusi**:",
                content.strip(),
                "---",
                ""
            ]
            block_text = "\n".join(block)
            if current_len + len(block_text) > max_chars and blocks:
                # Stop if max chars exceeded
                blocks.append(f"<!-- Context truncated to keep within size limit ({max_chars} chars) -->\n")
                break
            blocks.append(block_text)
            current_len += len(block_text)

        full_output = "\n".join(header) + "\n" + "\n".join(blocks)

        if out_file:
            with open(out_file, "w", encoding="utf-8") as fp:
                fp.write(full_output)
            print(f"{C_GREEN}✔ Konteks agent disimpan ke: {out_file}{C_RESET}")
        else:
            print(full_output)
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: SAVE FROM SESSION WORKFLOW
# ------------------------------------------------------------------------------
def get_session_content(session_id):
    """Retrieve session text and summary from OpenCode or AGY"""
    # 1. Try OpenCode
    if os.path.exists(OPENCODE_DB):
        try:
            con = sqlite3.connect(OPENCODE_DB)
            cur = con.cursor()
            s = cur.execute("SELECT id, title, directory FROM session WHERE id=?", (session_id,)).fetchone()
            if s:
                sid, title, directory = s
                msgs = cur.execute("SELECT id, data FROM message WHERE session_id=? ORDER BY time_created ASC", (sid,)).fetchall()
                turns = []
                for m_id, m_data_raw in msgs:
                    m_data = json.loads(m_data_raw) if m_data_raw else {}
                    role = m_data.get("role", "unknown")
                    parts = cur.execute("SELECT data FROM part WHERE message_id=? ORDER BY id ASC", (m_id,)).fetchall()
                    p_texts = []
                    for p in parts:
                        if p[0]:
                            try:
                                pj = json.loads(p[0])
                                if pj.get("type") == "text" and pj.get("text"):
                                    p_texts.append(pj.get("text").strip())
                            except Exception:
                                pass
                    if p_texts:
                        turns.append(f"[{role.upper()}]:\n" + "\n".join(p_texts))
                con.close()
                return {
                    "platform": "opencode",
                    "id": sid,
                    "title": title or "Sesi OpenCode",
                    "project": directory or "",
                    "content": "\n\n".join(turns)
                }
            con.close()
        except Exception:
            pass

    # 2. Try Antigravity
    if os.path.exists(AGY_DB):
        try:
            con = sqlite3.connect(AGY_DB)
            cur = con.cursor()
            r = cur.execute("SELECT conversation_id, title FROM conversation_summaries WHERE conversation_id=?", (session_id,)).fetchone()
            con.close()
            if r:
                cid, title = r
                cfile = os.path.join(AGY_CONV_DIR, f"{cid}.json")
                turns = []
                if os.path.exists(cfile):
                    with open(cfile, "r", encoding="utf-8", errors="replace") as fp:
                        data = json.load(fp)
                    for item in data:
                        sender = item.get("sender", "unknown")
                        txt = item.get("text", "")
                        if txt:
                            turns.append(f"[{sender.upper()}]:\n{txt.strip()}")
                return {
                    "platform": "agy",
                    "id": cid,
                    "title": title or "Sesi Antigravity",
                    "project": "",
                    "content": "\n\n".join(turns)
                }
        except Exception:
            pass

    return None

def action_save_from_session(session_id=None):
    # If no session ID provided, display recent sessions
    if not session_id:
        print(f"\n{C_BOLD}{C_CYAN}=== Pilih Sesi Sumber untuk Disimpan ke Knowledge Memory ==={C_RESET}\n")
        recent_sessions = []
        if os.path.exists(OPENCODE_DB):
            try:
                con = sqlite3.connect(OPENCODE_DB)
                cur = con.cursor()
                for r in cur.execute("SELECT id, title, time_updated FROM session ORDER BY time_updated DESC LIMIT 10"):
                    recent_sessions.append(("OpenCode", r[0], r[1] or "(Tanpa Judul)"))
                con.close()
            except Exception:
                pass
        if os.path.exists(AGY_DB):
            try:
                con = sqlite3.connect(AGY_DB)
                cur = con.cursor()
                for r in cur.execute("SELECT conversation_id, title FROM conversation_summaries ORDER BY last_modified_time DESC LIMIT 10"):
                    recent_sessions.append(("AGY", r[0], r[1] or "(Tanpa Judul)"))
                con.close()
            except Exception:
                pass

        if not recent_sessions:
            print(f"{C_YELLOW}Tidak ada sesi yang ditemukan.{C_RESET}")
            return False

        for idx, (plat, sid, title) in enumerate(recent_sessions, 1):
            t_clean = (title or "").replace("\n", " ").strip()[:40]
            print(f"  {idx}) [{plat}] {sid[:18]}... : {t_clean}")

        try:
            ch = input(f"\nPilih nomor sesi [1-{len(recent_sessions)}] atau ketik ID: ").strip()
            if ch.isdigit() and 1 <= int(ch) <= len(recent_sessions):
                session_id = recent_sessions[int(ch) - 1][1]
            else:
                session_id = ch
        except (KeyboardInterrupt, EOFError):
            print("\nDibatalkan.")
            return False

    if not session_id:
        print(f"{C_RED}[ERROR] ID Sesi tidak valid.{C_RESET}")
        return False

    session_data = get_session_content(session_id)
    if not session_data:
        print(f"{C_RED}[ERROR] Data sesi dengan ID '{session_id}' tidak ditemukan di OpenCode atau AGY.{C_RESET}")
        return False

    raw_content = session_data.get("content", "")
    if not raw_content:
        print(f"{C_YELLOW}[WARN] Sesi tidak memiliki teks percakapan. Silakan masukkan catatan secara manual.{C_RESET}")
        raw_content = ""

    # Sanitize and redact secrets immediately
    clean_content, red_cnt = redact_secrets(raw_content)
    if red_cnt > 0:
        print(f"{C_YELLOW}⚠️ Disensor {red_cnt} kredensial sensitif yang ditemukan pada sesi.{C_RESET}")

    default_title = session_data.get("title", "Solusi dari Sesi")
    print(f"\n{C_BOLD}{C_CYAN}--- Konfigurasi Catatan Pengetahuan dari Sesi ---{C_RESET}")
    print(f"Platform Sumber : {session_data.get('platform')}")
    print(f"ID Sesi Sumber  : {session_data.get('id')}")

    try:
        t_in = input(f"Judul Catatan [{default_title}]: ").strip()
        final_title = t_in if t_in else default_title

        print("Kategori pilihan:")
        for idx, c in enumerate(CATEGORIES, 1):
            print(f"  {idx}) {c}")
        cat_in = input("Pilih kategori [1-7] (default 1: troubleshooting): ").strip()
        if cat_in.isdigit() and 1 <= int(cat_in) <= len(CATEGORIES):
            final_cat = CATEGORIES[int(cat_in) - 1]
        elif cat_in.lower() in CATEGORIES:
            final_cat = cat_in.lower()
        else:
            final_cat = "troubleshooting"

        tags_in = input("Tagar / Kata Kunci (pisahkan dengan koma): ").strip()
        final_tags = normalize_tags(tags_in)

        print("\nPilihan Pemrosesan Konten Sesi:")
        print("  1) Simpan rangkuman/ekstrak percakapan lengkap yang disensor")
        print("  2) Masukkan solusi ringkas / poin penting secara manual")
        opt = input("Pilihan [1-2] (default 1): ").strip()

        if opt == "2":
            print("Masukkan catatan / solusi penting:")
            lines = []
            while True:
                line = input()
                if not line and lines: break
                lines.append(line)
            final_content = "\n".join(lines).strip()
            final_content, _ = redact_secrets(final_content)
        else:
            # Take clean content, truncate if gigantic (>10KB) with prompt
            if len(clean_content) > 12000:
                print(f"{C_YELLOW}Konten sesi cukup panjang ({len(clean_content)} karakter). Memotong 200 baris terakhir...{C_RESET}")
                lines = clean_content.splitlines()
                final_content = "...\n" + "\n".join(lines[-200:])
            else:
                final_content = clean_content

        v_in = input("Tandai catatan ini sebagai terverifikasi (verified)? (y/N): ").strip().lower()
        final_status = "verified" if v_in in ("y", "yes") else "unverified"

        # Review before saving
        print(f"\n{C_BOLD}=== Pratinjau Catatan Sebelum Disimpan ==={C_RESET}")
        print(f"Judul    : {final_title}")
        print(f"Kategori : {final_cat}")
        print(f"Tag      : {final_tags}")
        print(f"Status   : {status_badge(final_status)}")
        print(f"Sumber   : {session_data.get('id')}")
        print(f"Ukuran   : {len(final_content)} karakter")
        conf = input("Konfirmasi simpan catatan ini? (Y/n): ").strip().lower()
        if conf in ("n", "no"):
            print("Penyimpanan dibatalkan.")
            return False

        # Save note
        mem_id = generate_id()
        now_iso = current_iso()
        con = get_db()
        try:
            with con:
                con.execute("""
                    INSERT INTO memories (
                        id, title, content, category, tags, project, tool,
                        created_at, updated_at, status, source_session_id, source_session_title, metadata
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    mem_id, final_title, final_content, final_cat, final_tags,
                    session_data.get("project", ""), session_data.get("platform", ""),
                    now_iso, now_iso, final_status, session_data.get("id"),
                    session_data.get("title", ""), "{}"
                ))
            print(f"\n{C_GREEN}{C_BOLD}✔ Pengetahuan dari Sesi Berhasil Disimpan ke AI Brain!{C_RESET}")
            print(f"  ID Memori: {C_BOLD}{mem_id}{C_RESET}")
            return True
        finally:
            con.close()

    except (KeyboardInterrupt, EOFError):
        print("\nDibatalkan.")
        return False

# ------------------------------------------------------------------------------
# Action: STATS & DATABASE STATUS
# ------------------------------------------------------------------------------
def action_stats():
    con = get_db()
    try:
        cur = con.cursor()
        total = cur.execute("SELECT count(*) FROM memories").fetchone()[0]
        verified = cur.execute("SELECT count(*) FROM memories WHERE status='verified'").fetchone()[0]
        unverified = cur.execute("SELECT count(*) FROM memories WHERE status='unverified'").fetchone()[0]
        deprecated = cur.execute("SELECT count(*) FROM memories WHERE status='deprecated'").fetchone()[0]

        cat_counts = cur.execute("SELECT category, count(*) FROM memories GROUP BY category ORDER BY count(*) DESC").fetchall()

        db_size = os.path.getsize(MEMORY_DB) if os.path.exists(MEMORY_DB) else 0
        wal_path = MEMORY_DB + "-wal"
        wal_size = os.path.getsize(wal_path) if os.path.exists(wal_path) else 0

        # Check FTS5
        fts_status = "Aktif (High Speed Search)"
        try:
            cur.execute("SELECT count(*) FROM memory_fts")
        except Exception:
            fts_status = "Nonaktif (Fallback ke LIKE)"

        print(f"\n{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
        print(f"{C_BOLD}             STATISTIK KNOWLEDGE MEMORY / AI BRAIN                   {C_RESET}")
        print(f"{C_BOLD}{C_CYAN}======================================================================{C_RESET}")
        print(f"  {C_CYAN}Lokasi Database{C_RESET}   : {MEMORY_DB}")
        print(f"  {C_CYAN}Ukuran Database{C_RESET}   : {db_size / 1024:.1f} KB (WAL: {wal_size / 1024:.1f} KB)")
        print(f"  {C_CYAN}Mesin Pencari FTS{C_RESET} : {fts_status}")
        print(f"  {C_CYAN}Total Catatan{C_RESET}     : {C_BOLD}{total}{C_RESET}")
        print(f"  {C_GREEN}Terverifikasi{C_RESET}     : {verified}")
        print(f"  {C_YELLOW}Belum Diverifikasi{C_RESET}: {unverified}")
        print(f"  {C_RED}Deprecated{C_RESET}        : {deprecated}")
        print("-" * 70)
        print(f"{C_BOLD}Distribusi Kategori:{C_RESET}")
        for c, cnt in cat_counts:
            pct = (cnt / total * 100) if total > 0 else 0
            bar = "█" * int(pct // 5)
            print(f"  {c:<16}: {cnt:<4} ({pct:>5.1f}%) {C_CYAN}{bar}{C_RESET}")
        print("=" * 70)
    finally:
        con.close()

# ------------------------------------------------------------------------------
# Action: EXPORT TO MCP KNOWLEDGE GRAPH FORMAT
# ------------------------------------------------------------------------------
def action_mcp_export(out_file=None):
    con = get_db()
    try:
        cur = con.cursor()
        rows = cur.execute("SELECT id, title, content, category, tags, status FROM memories WHERE status != 'deprecated'").fetchall()
        entities = []
        relations = []
        for r in rows:
            mid, title, content, cat, tags_str, st = r
            entities.append({
                "name": title,
                "entityType": cat,
                "observations": [
                    f"ID: {mid}",
                    f"Status: {st}",
                    f"Tags: {tags_str}",
                    content[:500]
                ]
            })
            if tags_str:
                for t in tags_str.split(","):
                    if t:
                        relations.append({
                            "from": title,
                            "to": t,
                            "relationType": "tagged_with"
                        })
        mcp_data = {
            "entities": entities,
            "relations": relations
        }
        dest = out_file or os.path.join(EXPORT_DIR, "mcp_knowledge_graph.json")
        with open(dest, "w", encoding="utf-8") as fp:
            json.dump(mcp_data, fp, indent=2)
        print(f"{C_GREEN}✔ Export MCP Knowledge Graph berhasil: {dest} ({len(entities)} entitas){C_RESET}")
    finally:
        con.close()

# ------------------------------------------------------------------------------
# CLI Router
# ------------------------------------------------------------------------------
def main():
    if len(sys.argv) < 2:
        return 1

    cmd = sys.argv[1].lower()
    sub_args = sys.argv[2:]
    res = True

    if cmd == "add":
        res = action_add(sub_args)
    elif cmd in ("list", "ls"):
        res = action_list(sub_args)
    elif cmd in ("show", "get"):
        res = action_show(sub_args[0] if sub_args else "")
    elif cmd in ("search", "find"):
        q = sub_args[0] if sub_args else ""
        res = action_search(q, sub_args[1:])
    elif cmd == "edit":
        res = action_edit(sub_args[0] if sub_args else "", sub_args[1:])
    elif cmd in ("delete", "rm"):
        force = "-y" in sub_args or "--yes" in sub_args
        target_id = [a for a in sub_args if not a.startswith("-")]
        res = action_delete(target_id[0] if target_id else "", force=force)
    elif cmd == "tag":
        if len(sub_args) >= 3:
            res = action_tag(sub_args[0], sub_args[1], sub_args[2:])
        else:
            print(f"{C_RED}Gunakan: memory tag <id> [add|remove] <tags...>{C_RESET}")
            res = False
    elif cmd in ("verify", "verified"):
        res = action_set_status(sub_args[0] if sub_args else "", "verified")
    elif cmd in ("deprecate", "deprecated"):
        res = action_set_status(sub_args[0] if sub_args else "", "deprecated")
    elif cmd == "export":
        target = sub_args[0] if sub_args else "--all"
        out = sub_args[1] if len(sub_args) > 1 else None
        res = action_export(target, out)
    elif cmd == "import":
        target = sub_args[0] if sub_args else ""
        overwrite = "--overwrite" in sub_args
        res = action_import(target, overwrite=overwrite)
    elif cmd in ("context", "ctx"):
        q = sub_args[0] if sub_args else ""
        verified_only = "--verified-only" in sub_args
        limit = 5
        max_chars = 4000
        out_f = None
        i = 1
        while i < len(sub_args):
            if sub_args[i] in ("--limit", "-l") and i + 1 < len(sub_args):
                limit = int(sub_args[i + 1])
                i += 1
            elif sub_args[i] in ("--max-chars", "-c") and i + 1 < len(sub_args):
                max_chars = int(sub_args[i + 1])
                i += 1
            elif sub_args[i] in ("--out", "-o") and i + 1 < len(sub_args):
                out_f = sub_args[i + 1]
                i += 1
            i += 1
        res = action_context(q, limit=limit, max_chars=max_chars, verified_only=verified_only, out_file=out_f)
    elif cmd in ("save-from-session", "from-session", "save-session"):
        res = action_save_from_session(sub_args[0] if sub_args else None)
    elif cmd in ("stats", "status", "info"):
        res = action_stats()
    elif cmd in ("mcp-export", "export-mcp"):
        out_f = sub_args[0] if sub_args else None
        res = action_mcp_export(out_f)
    else:
        print(f"{C_RED}Perintah tidak dikenal: {cmd}{C_RESET}")
        return 1
    return 0 if (res is None or res is True) else 1

if __name__ == "__main__":
    sys.exit(main())
EOF
}

# ------------------------------------------------------------------------------
# Interactive Menu (TUI)
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "        🧠 Knowledge Memory & AI Brain           "
        echo "   Persistent Technical Knowledge for Termux AI  "
        echo -e "==================================================${RESET}"
        echo -e "  ${GREEN}1)${RESET} 📋 Daftar Catatan Pengetahuan (List Memories)"
        echo -e "  ${GREEN}2)${RESET} 🔍 Cari Pengetahuan (Full-Text Search FTS5)"
        echo -e "  ${GREEN}3)${RESET} 📖 Lihat Detail Catatan (Show Memory)"
        echo -e "  ${CYAN}4)${RESET} ➕ Buat Catatan Pengetahuan Baru (Add Memory)"
        echo -e "  ${CYAN}5)${RESET} 💡 Simpan Pengetahuan dari Sesi AI (Save from Session)"
        echo -e "  ${CYAN}6)${RESET} 🤖 Ekspor Konteks untuk Agent AI (Agent Context Export)"
        echo -e "  ${YELLOW}7)${RESET} 🏷️  Kelola Tagar & Status Verifikasi"
        echo -e "  ${YELLOW}8)${RESET} ✏️  Edit Catatan Pengetahuan"
        echo -e "  ${RED}9)${RESET} 🗑️  Hapus Catatan Pengetahuan"
        echo -e "  ${CYAN}10)${RESET} 📤 Ekspor Catatan ke Markdown (.md)"
        echo -e "  ${CYAN}11)${RESET} 📥 Impor Catatan dari Markdown (.md)"
        echo -e "  ${CYAN}12)${RESET} 📊 Statistik & Status Memory DB"
        echo -e "  ${YELLOW}0)${RESET} Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-12]: " opt
        case "$opt" in
            1)
                run_python_engine "list"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            2)
                read -r -p "Masukkan kata kunci pencarian: " kw
                if [ -n "$kw" ]; then
                    run_python_engine "search" "$kw"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            3)
                read -r -p "Masukkan ID Catatan (contoh: mem_20261028_...): " mid
                if [ -n "$mid" ]; then
                    run_python_engine "show" "$mid"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                run_python_engine "add"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            5)
                run_python_engine "save-from-session"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            6)
                read -r -p "Masukkan topik/query konteks agent: " ctx_q
                if [ -n "$ctx_q" ]; then
                    echo ""
                    run_python_engine "context" "$ctx_q"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            7)
                echo "1) Tandai Terverifikasi (Verify)"
                echo "2) Tandai Deprecated"
                echo "3) Tambah Tag"
                echo "4) Hapus Tag"
                read -r -p "Pilihan [1-4]: " sub_opt
                read -r -p "ID Catatan: " mid
                case "$sub_opt" in
                    1) [ -n "$mid" ] && run_python_engine "verify" "$mid" ;;
                    2) [ -n "$mid" ] && run_python_engine "deprecate" "$mid" ;;
                    3)
                        read -r -p "Tag yang ingin ditambah (pisahkan koma): " t_add
                        [ -n "$mid" ] && [ -n "$t_add" ] && run_python_engine "tag" "$mid" "add" "$t_add"
                        ;;
                    4)
                        read -r -p "Tag yang ingin dihapus (pisahkan koma): " t_rm
                        [ -n "$mid" ] && [ -n "$t_rm" ] && run_python_engine "tag" "$mid" "remove" "$t_rm"
                        ;;
                esac
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            8)
                read -r -p "ID Catatan yang ingin diedit: " mid
                if [ -n "$mid" ]; then
                    run_python_engine "edit" "$mid"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            9)
                read -r -p "ID Catatan yang ingin dihapus: " mid
                if [ -n "$mid" ]; then
                    run_python_engine "delete" "$mid"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            10)
                echo "1) Ekspor SEMUA catatan ke direktori ~/memory-export"
                echo "2) Ekspor satu catatan spesifik"
                read -r -p "Pilihan [1-2]: " exp_opt
                if [ "$exp_opt" = "1" ]; then
                    run_python_engine "export" "--all"
                elif [ "$exp_opt" = "2" ]; then
                    read -r -p "ID Catatan: " mid
                    [ -n "$mid" ] && run_python_engine "export" "$mid"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            11)
                read -r -p "Path file Markdown atau direktori import: " imp_path
                if [ -n "$imp_path" ]; then
                    run_python_engine "import" "$imp_path"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            12)
                run_python_engine "stats"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            0)
                echo "Kembali."
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
# Dispatcher
# ------------------------------------------------------------------------------
if [ $# -eq 0 ]; then
    interactive_menu
    exit 0
fi

case "$1" in
    add)
        shift
        run_python_engine "add" "$@"
        ;;
    list|ls)
        shift
        run_python_engine "list" "$@"
        ;;
    show|get)
        shift
        run_python_engine "show" "$@"
        ;;
    search|find)
        shift
        run_python_engine "search" "$@"
        ;;
    edit)
        shift
        run_python_engine "edit" "$@"
        ;;
    delete|rm)
        shift
        run_python_engine "delete" "$@"
        ;;
    tag)
        shift
        run_python_engine "tag" "$@"
        ;;
    verify|verified)
        shift
        run_python_engine "verify" "$@"
        ;;
    deprecate|deprecated)
        shift
        run_python_engine "deprecate" "$@"
        ;;
    export)
        shift
        run_python_engine "export" "$@"
        ;;
    import)
        shift
        run_python_engine "import" "$@"
        ;;
    context|ctx)
        shift
        run_python_engine "context" "$@"
        ;;
    save-from-session|from-session|save-session)
        shift
        run_python_engine "save-from-session" "$@"
        ;;
    stats|status|info)
        run_python_engine "stats"
        ;;
    mcp-export|export-mcp)
        shift
        run_python_engine "mcp-export" "$@"
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - Knowledge Memory / AI Brain Usage:${RESET}"
        echo "  memory.sh                                Buka menu interaktif TUI"
        echo "  memory.sh add [options]                  Tambah catatan pengetahuan baru"
        echo "  memory.sh show <id>                      Tampilkan detail catatan pengetahuan"
        echo "  memory.sh list [--category <cat>]        Daftar catatan pengetahuan"
        echo "  memory.sh search <kata_kunci>            Cari catatan (FTS5 Full-Text Search)"
        echo "  memory.sh edit <id> [options]            Ubah/perbarui catatan pengetahuan"
        echo "  memory.sh delete <id> [-y]               Hapus catatan pengetahuan"
        echo "  memory.sh tag <id> [add|remove] <tags>   Kelola tagar catatan"
        echo "  memory.sh verify <id>                    Tandai catatan sebagai verified"
        echo "  memory.sh deprecate <id>                 Tandai catatan sebagai deprecated"
        echo "  memory.sh export [--all|<id>] [out]      Ekspor catatan ke format Markdown"
        echo "  memory.sh import <file_atau_dir>         Impor catatan dari Markdown"
        echo "  memory.sh context \"<topik>\" [options]    Ekspor konteks terverifikasi untuk Agent AI"
        echo "  memory.sh save-from-session [id_sesi]    Simpan pengetahuan dari sesi percakapan"
        echo "  memory.sh stats                          Tampilkan statistik & status database"
        echo "  memory.sh mcp-export [out_file]          Ekspor graf pengetahuan format MCP"
        echo ""
        echo "  Alias yang didukung: aisession memory <command>, ai memory <command>, aimem <command>"
        exit 0
        ;;
    *)
        interactive_menu
        ;;
esac

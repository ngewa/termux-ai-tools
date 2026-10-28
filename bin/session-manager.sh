#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - Session & Context Manager (session.sh)
# Manages:
#   - OpenCode Sessions (opencode.db, message, part, session, session_v2)
#   - Antigravity CLI Conversations (conversation_summaries.db, conversations/)
#   - Storage Cleanup & SQLite VACUUM (reclaim GBs of storage)
#   - Rich Human-Readable Markdown Exporter (.md)
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
OPENCODE_DB="$HOME_DIR/.local/share/opencode/opencode.db"
AGY_DB="$HOME_DIR/.gemini/antigravity-cli/conversation_summaries.db"
EXPORT_DIR="$HOME_DIR/sessions-export"

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
    log_err "Python3 diperlukan untuk menjalankan session manager."
    echo "Jalankan: pkg install python"
    exit 1
fi

mkdir -p "$EXPORT_DIR"

# ------------------------------------------------------------------------------
# Embedded Python Session Engine
# ------------------------------------------------------------------------------
run_python_engine() {
    python3 - "$@" << 'EOF'
import sys, os, sqlite3, json, datetime, re, shutil

HOME = os.path.expanduser("~")
OPENCODE_DIR = os.path.join(HOME, ".local/share/opencode")
OPENCODE_DB = os.path.join(OPENCODE_DIR, "opencode.db")
AGY_DIR = os.path.join(HOME, ".gemini/antigravity-cli")
AGY_DB = os.path.join(AGY_DIR, "conversation_summaries.db")
EXPORT_DIR = os.path.join(HOME, "sessions-export")

def get_dir_size(path):
    total = 0
    if not os.path.exists(path):
        return 0
    if os.path.isfile(path):
        return os.path.getsize(path)
    for root, dirs, files in os.walk(path):
        for f in files:
            fp = os.path.join(root, f)
            try:
                total += os.path.getsize(fp)
            except Exception:
                pass
    return total

def format_size(bytes_val):
    if bytes_val < 1024:
        return f"{bytes_val} B"
    elif bytes_val < 1024 * 1024:
        return f"{bytes_val / 1024:.1f} KB"
    elif bytes_val < 1024 * 1024 * 1024:
        return f"{bytes_val / (1024 * 1024):.1f} MB"
    else:
        return f"{bytes_val / (1024 * 1024 * 1024):.2f} GB"

def format_timestamp(ts):
    if not ts:
        return "-"
    try:
        if isinstance(ts, (int, float)):
            if ts > 1e11:
                ts = ts / 1000.0
            return datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M")
        elif isinstance(ts, str):
            ts_clean = ts.split(".")[0].replace("T", " ")
            return ts_clean[:16]
    except Exception:
        pass
    return str(ts)[:16]

def clean_model_name(model_str):
    if not model_str:
        return "-"
    if model_str.startswith("{"):
        try:
            m = json.loads(model_str)
            return m.get("id") or m.get("modelID") or model_str[:20]
        except Exception:
            pass
    return model_str.split("/")[-1]

# ------------------------------------------------------------------------------
# Action: STATUS
# ------------------------------------------------------------------------------
def action_status():
    print("\033[1m\033[36m======================================================================\033[0m")
    print("\033[1m           ANALISIS PENYIMPANAN SESI & KONTEKS AI (STORAGE)           \033[0m")
    print("\033[1m\033[36m======================================================================\033[0m")

    # 1. OpenCode Database & Storage
    oc_db_size = os.path.getsize(OPENCODE_DB) if os.path.exists(OPENCODE_DB) else 0
    oc_wal_size = os.path.getsize(OPENCODE_DB + "-wal") if os.path.exists(OPENCODE_DB + "-wal") else 0
    oc_log_size = get_dir_size(os.path.join(OPENCODE_DIR, "log"))
    oc_output_size = get_dir_size(os.path.join(OPENCODE_DIR, "tool-output")) + get_dir_size(os.path.join(OPENCODE_DIR, "snapshot"))
    
    oc_session_count = 0
    oc_msg_count = 0
    oc_freelist_bytes = 0
    
    if os.path.exists(OPENCODE_DB):
        try:
            con = sqlite3.connect(OPENCODE_DB)
            cur = con.cursor()
            oc_session_count = cur.execute("SELECT count(*) FROM session").fetchone()[0]
            oc_msg_count = cur.execute("SELECT count(*) FROM message").fetchone()[0]
            ps = cur.execute("PRAGMA page_size").fetchone()[0]
            fc = cur.execute("PRAGMA freelist_count").fetchone()[0]
            oc_freelist_bytes = ps * fc
            con.close()
        except Exception:
            pass

    # 2. Antigravity Storage
    agy_db_size = os.path.getsize(AGY_DB) if os.path.exists(AGY_DB) else 0
    agy_conv_size = get_dir_size(os.path.join(AGY_DIR, "conversations"))
    agy_brain_size = get_dir_size(os.path.join(AGY_DIR, "brain"))
    agy_log_size = get_dir_size(os.path.join(AGY_DIR, "log"))
    agy_conv_count = 0
    if os.path.exists(AGY_DB):
        try:
            con = sqlite3.connect(AGY_DB)
            cur = con.cursor()
            agy_conv_count = cur.execute("SELECT count(*) FROM conversation_summaries").fetchone()[0]
            con.close()
        except Exception:
            pass

    total_ai_storage = oc_db_size + oc_wal_size + oc_log_size + oc_output_size + agy_db_size + agy_conv_size + agy_brain_size + agy_log_size
    cleanable_temp = oc_log_size + oc_output_size + agy_log_size
    reclaimable_vacuum = oc_freelist_bytes

    print(f"\033[1m1. OpenCode Storage:\033[0m")
    print(f"  • Database Utama (opencode.db) : \033[33m{format_size(oc_db_size)}\033[0m ({oc_session_count} sesi, {oc_msg_count} pesan)")
    if oc_wal_size > 0:
        print(f"  • SQLite WAL Temporary Cache   : {format_size(oc_wal_size)}")
    print(f"  • Log & Riwayat Debug          : {format_size(oc_log_size)}")
    print(f"  • Tool Output & Snapshot Cache : {format_size(oc_output_size)}")
    if oc_freelist_bytes > 0:
        print(f"  • \033[32mRuang Kosong (Dead Pages)    : {format_size(oc_freelist_bytes)} (Bisa dibebaskan dengan VACUUM)\033[0m")

    print(f"\n\033[1m2. Antigravity CLI (agy) Storage:\033[0m")
    print(f"  • File Sesi Percakapan (.db/.pb): \033[33m{format_size(agy_conv_size)}\033[0m ({agy_conv_count} ringkasan)")
    print(f"  • Brain Context & Scratchpad   : {format_size(agy_brain_size)}")
    print(f"  • Log Riwayat Eksekusi         : {format_size(agy_log_size)}")

    print("\033[1m\033[36m----------------------------------------------------------------------\033[0m")
    print(f"📁 \033[1mTotal Penggunaan Storage AI   :\033[0m \033[31m{format_size(total_ai_storage)}\033[0m")
    print(f"✨ \033[1mPotensi Pembebasan Ruang Disk :\033[0m \033[32m~{format_size(cleanable_temp + reclaimable_vacuum)}\033[0m")
    if cleanable_temp > 0 or reclaimable_vacuum > 0:
        print(f"   (Pembersihan Log/Cache: {format_size(cleanable_temp)} + SQLite VACUUM: {format_size(reclaimable_vacuum)})")
    print("\033[1m\033[36m======================================================================\033[0m")

# ------------------------------------------------------------------------------
# Action: LIST SESSIONS
# ------------------------------------------------------------------------------
def action_list(limit=15, filter_tool="all"):
    print("\033[1m\033[36m====================================================================================================\033[0m")
    print("\033[1m                                 DAFTAR SESI PERCAKAPAN TERBARU                                     \033[0m")
    print("\033[1m\033[36m====================================================================================================\033[0m")
    print(f"{'TOOL':<9} {'ID SESI':<26} {'TANGGAL':<17} {'MSGS':<6} {'MODEL':<20} {'JUDUL / TOPIK':<20}")
    print("-" * 100)

    rows_shown = 0

    # 1. OpenCode Sessions
    if filter_tool in ("all", "oc", "opencode") and os.path.exists(OPENCODE_DB):
        try:
            con = sqlite3.connect(OPENCODE_DB)
            cur = con.cursor()
            q = """
                SELECT s.id, s.title, s.time_updated, s.model,
                       (SELECT count(*) FROM message m WHERE m.session_id = s.id) as msg_count
                FROM session s
                ORDER BY s.time_updated DESC
                LIMIT ?
            """
            for row in cur.execute(q, (limit,)):
                sid, title, tu, model, count = row
                title_clean = (title or "(Tanpa Judul)").replace("\n", " ").strip()
                if len(title_clean) > 28:
                    title_clean = title_clean[:25] + "..."
                model_clean = clean_model_name(model)[:18]
                date_str = format_timestamp(tu)
                print(f"\033[32m{'OpenCode':<9}\033[0m {sid:<26} {date_str:<17} {count:<6} {model_clean:<20} {title_clean:<20}")
                rows_shown += 1
            con.close()
        except Exception as e:
            print(f"Error reading OpenCode sessions: {e}")

    # 2. Antigravity Sessions
    if filter_tool in ("all", "agy", "antigravity") and os.path.exists(AGY_DB):
        try:
            con = sqlite3.connect(AGY_DB)
            cur = con.cursor()
            q = """
                SELECT conversation_id, title, last_modified_time, step_count
                FROM conversation_summaries
                ORDER BY last_modified_time DESC
                LIMIT ?
            """
            for row in cur.execute(q, (limit,)):
                cid, title, lmt, steps = row
                title_clean = (title or "(Tanpa Judul)").replace("\n", " ").strip()
                if len(title_clean) > 28:
                    title_clean = title_clean[:25] + "..."
                date_str = format_timestamp(lmt)
                cid_short = cid[:24] + ".."
                print(f"\033[36m{'AGY':<9}\033[0m {cid_short:<26} {date_str:<17} {steps or 0:<6} {'gemini':<20} {title_clean:<20}")
                rows_shown += 1
            con.close()
        except Exception as e:
            print(f"Error reading AGY sessions: {e}")

    print("-" * 100)
    print(f"Menampilkan {rows_shown} sesi terbaru.")

# ------------------------------------------------------------------------------
# Action: SEARCH SESSIONS
# ------------------------------------------------------------------------------
def action_search(keyword):
    print("\033[1m\033[36m====================================================================================================\033[0m")
    print(f"\033[1m                     HASIL PENCARIAN SESI UNTUK KATA KUNCI: '\033[33m{keyword}\033[0m\033[1m'                          \033[0m")
    print("\033[1m\033[36m====================================================================================================\033[0m")
    print(f"{'TOOL':<9} {'ID SESI':<26} {'TANGGAL':<17} {'MSGS':<6} {'MODEL':<20} {'JUDUL / TOPIK':<20}")
    print("-" * 100)

    found = 0
    kw_param = f"%{keyword}%"

    # Search in OpenCode
    if os.path.exists(OPENCODE_DB):
        try:
            con = sqlite3.connect(OPENCODE_DB)
            cur = con.cursor()
            q = """
                SELECT s.id, s.title, s.time_updated, s.model,
                       (SELECT count(*) FROM message m WHERE m.session_id = s.id) as msg_count
                FROM session s
                WHERE s.title LIKE ? OR s.id LIKE ? OR s.directory LIKE ?
                ORDER BY s.time_updated DESC
                LIMIT 30
            """
            for row in cur.execute(q, (kw_param, kw_param, kw_param)):
                sid, title, tu, model, count = row
                title_clean = (title or "(Tanpa Judul)").replace("\n", " ").strip()
                if len(title_clean) > 28:
                    title_clean = title_clean[:25] + "..."
                model_clean = clean_model_name(model)[:18]
                date_str = format_timestamp(tu)
                print(f"\033[32m{'OpenCode':<9}\033[0m {sid:<26} {date_str:<17} {count:<6} {model_clean:<20} {title_clean:<20}")
                found += 1
            con.close()
        except Exception:
            pass

    # Search in Antigravity
    if os.path.exists(AGY_DB):
        try:
            con = sqlite3.connect(AGY_DB)
            cur = con.cursor()
            q = """
                SELECT conversation_id, title, last_modified_time, step_count
                FROM conversation_summaries
                WHERE title LIKE ? OR conversation_id LIKE ? OR preview LIKE ?
                ORDER BY last_modified_time DESC
                LIMIT 30
            """
            for row in cur.execute(q, (kw_param, kw_param, kw_param)):
                cid, title, lmt, steps = row
                title_clean = (title or "(Tanpa Judul)").replace("\n", " ").strip()
                if len(title_clean) > 28:
                    title_clean = title_clean[:25] + "..."
                date_str = format_timestamp(lmt)
                cid_short = cid[:24] + ".."
                print(f"\033[36m{'AGY':<9}\033[0m {cid_short:<26} {date_str:<17} {steps or 0:<6} {'gemini':<20} {title_clean:<20}")
                found += 1
            con.close()
        except Exception:
            pass

    print("-" * 100)
    print(f"Ditemukan {found} sesi yang cocok.")

# ------------------------------------------------------------------------------
# Action: INFO DETAIL
# ------------------------------------------------------------------------------
def action_info(session_id):
    if os.path.exists(OPENCODE_DB):
        try:
            con = sqlite3.connect(OPENCODE_DB)
            cur = con.cursor()
            s = cur.execute("SELECT id, title, time_created, time_updated, model, directory, tokens_input, tokens_output, cost FROM session WHERE id=?", (session_id,)).fetchone()
            if s:
                sid, title, tc, tu, model, d, tin, tout, cost = s
                msg_count = cur.execute("SELECT count(*) FROM message WHERE session_id=?", (sid,)).fetchone()[0]
                part_count = cur.execute("SELECT count(*) FROM part WHERE session_id=?", (sid,)).fetchone()[0]
                con.close()
                print("\033[1m\033[36m==================================================\033[0m")
                print(f"\033[1mDetail Sesi OpenCode: {sid}\033[0m")
                print("\033[1m\033[36m==================================================\033[0m")
                print(f"Judul         : {title or '(Tanpa Judul)'}")
                print(f"Model         : {clean_model_name(model)}")
                print(f"Direktori Proyek: {d or '-'}")
                print(f"Dibuat Pada   : {format_timestamp(tc)}")
                print(f"Terakhir Aktif: {format_timestamp(tu)}")
                print(f"Jumlah Pesan  : {msg_count} pesan ({part_count} parts)")
                print(f"Token Input   : {tin or 0:,}")
                print(f"Token Output  : {tout or 0:,}")
                if cost:
                    print(f"Estimasi Biaya: ${cost:.4f}")
                return
            con.close()
        except Exception:
            pass

    # Check AGY
    if os.path.exists(AGY_DB):
        try:
            con = sqlite3.connect(AGY_DB)
            cur = con.cursor()
            c = cur.execute("SELECT conversation_id, title, last_modified_time, step_count, preview, workspace_uris FROM conversation_summaries WHERE conversation_id=?", (session_id,)).fetchone()
            if c:
                cid, title, lmt, steps, prev, w = c
                con.close()
                print("\033[1m\033[36m==================================================\033[0m")
                print(f"\033[1mDetail Percakapan AGY: {cid}\033[0m")
                print("\033[1m\033[36m==================================================\033[0m")
                print(f"Judul         : {title or '(Tanpa Judul)'}")
                print(f"Terakhir Aktif: {format_timestamp(lmt)}")
                print(f"Jumlah Step   : {steps or 0}")
                print(f"Workspace     : {w or '-'}")
                print(f"Preview       : {prev or '-'}")
                return
            con.close()
        except Exception:
            pass

    print(f"Sesi dengan ID '{session_id}' tidak ditemukan.")

# ------------------------------------------------------------------------------
# Action: EXPORT TO RICH MARKDOWN (Turn-Based & 100% Complete)
# ------------------------------------------------------------------------------
def action_export(session_id, copy_sdcard=True):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    
    # 1. OpenCode Session Export
    if os.path.exists(OPENCODE_DB):
        try:
            con = sqlite3.connect(OPENCODE_DB)
            cur = con.cursor()
            s = cur.execute("SELECT id, title, time_created, time_updated, model, directory, tokens_input, tokens_output, cost FROM session WHERE id=?", (session_id,)).fetchone()
            if s:
                sid, title, tc, tu, model, directory, tin, tout, cost = s
                safe_title = re.sub(r'[^a-zA-Z0-9_-]', '_', (title or "session")[:40])
                filename = f"{safe_title}_{sid[:10]}.md"
                out_path = os.path.join(EXPORT_DIR, filename)

                lines = [
                    f"# 📝 Catatan Sesi Percakapan: {title or '(Tanpa Judul)'}",
                    "",
                    f"- **Platform**: OpenCode",
                    f"- **ID Sesi**: `{sid}`",
                    f"- **Model**: `{clean_model_name(model)}`",
                    f"- **Direktori Proyek**: `{directory or '-'}`",
                    f"- **Waktu Sesi**: {format_timestamp(tc)} s/d {format_timestamp(tu)}",
                    f"- **Penggunaan Token**: Input: {tin or 0:,} | Output: {tout or 0:,}",
                    "",
                    "---",
                    ""
                ]

                msgs = cur.execute("SELECT id, data, time_created FROM message WHERE session_id=? ORDER BY time_created ASC", (sid,)).fetchall()

                turns = []
                current_turn = None

                for m_id, m_data_raw, m_tc in msgs:
                    m_data = json.loads(m_data_raw) if m_data_raw else {}
                    role = m_data.get("role", "unknown")
                    parts = cur.execute("SELECT data FROM part WHERE message_id=? ORDER BY id ASC", (m_id,)).fetchall()
                    parsed_parts = [json.loads(p[0]) for p in parts if p[0]]
                    
                    if role == "user":
                        current_turn = {"role": "user", "time": m_tc, "content": [], "attachments": []}
                        for p in parsed_parts:
                            ptype = p.get("type")
                            if ptype == "text":
                                txt = p.get("text", "").strip()
                                if p.get("synthetic"):
                                    current_turn["attachments"].append(txt)
                                else:
                                    current_turn["content"].append(txt)
                            elif ptype == "file":
                                fn = p.get("filename") or p.get("url", "file")
                                current_turn["attachments"].append(f"File: {fn}")
                        if current_turn["content"] or current_turn["attachments"]:
                            turns.append(current_turn)
                        current_turn = None
                    elif role == "assistant":
                        if not current_turn or current_turn["role"] != "assistant":
                            current_turn = {"role": "assistant", "time": m_tc, "content": [], "tools": [], "reasoning": []}
                            turns.append(current_turn)
                        
                        for p in parsed_parts:
                            ptype = p.get("type")
                            if ptype == "text":
                                txt = p.get("text", "").strip()
                                if txt:
                                    current_turn["content"].append(txt)
                            elif ptype == "reasoning":
                                r = p.get("text", "").strip()
                                if r:
                                    current_turn["reasoning"].append(r)
                            elif ptype == "tool":
                                tname = p.get("tool", "tool")
                                inp = p.get("state", {}).get("input", {})
                                out = p.get("state", {}).get("output", "")
                                current_turn["tools"].append({"tool": tname, "input": inp, "output": out})

                # Render all turns
                for t in turns:
                    time_str = format_timestamp(t["time"])
                    if t["role"] == "user":
                        lines.append(f"### 👤 Pengguna ({time_str})\n")
                        for c in t["content"]:
                            lines.append(c + "\n")
                        if t["attachments"]:
                            lines.append("<details>\n<summary>📎 <b>Lampiran File / Konteks Otomatis</b> (klik untuk membuka)</summary>\n")
                            for att in t["attachments"]:
                                lines.append(f"```text\n{att[:400]}...\n```\n")
                            lines.append("</details>\n")
                        lines.append("\n---\n")
                    else:
                        has_content = bool(t["content"])
                        has_tools = bool(t["tools"])
                        has_reasoning = bool(t["reasoning"])
                        
                        if not (has_content or has_tools or has_reasoning):
                            continue
                            
                        lines.append(f"### 🤖 Asisten AI ({time_str})\n")
                        
                        # Tools accordion
                        if has_tools:
                            lines.append(f"<details>\n<summary>⚙️ <b>Langkah Eksekusi Alat ({len(t['tools'])} langkah)</b> (klik untuk membuka detail perintah & hasil)</summary>\n")
                            for i, tool_call in enumerate(t["tools"]):
                                tname = tool_call.get("tool", "tool")
                                inp_cmd = tool_call.get("input", {}).get("command") or str(tool_call.get("input", ""))
                                out_txt = str(tool_call.get("output", ""))
                                lines.append(f"#### Langkah {i+1}: `{tname}`\n")
                                if inp_cmd:
                                    lines.append(f"**Perintah:**\n```bash\n{inp_cmd[:600]}\n```\n")
                                if out_txt:
                                    lines.append(f"**Hasil:**\n```text\n{out_txt[:600]}\n```\n")
                            lines.append("</details>\n\n")
                            
                        # Reasoning accordion
                        if has_reasoning:
                            lines.append(f"<details>\n<summary>💭 <b>Alur Penalaran Model (Reasoning)</b> (klik untuk membuka)</summary>\n")
                            for r in t["reasoning"]:
                                lines.append(f"> {r}\n>\n")
                            lines.append("</details>\n\n")
                            
                        # Main text content
                        if has_content:
                            for c in t["content"]:
                                lines.append(c + "\n\n")
                        elif has_tools:
                            lines.append(f"*Asisten menyelesaikan {len(t['tools'])} langkah eksekusi alat tanpa teks ringkasan tambahan.*\n\n")
                            
                        lines.append("---\n")

                with open(out_path, "w", encoding="utf-8") as f:
                    f.write("\n".join(lines))
                con.close()

                print(f"\033[32m[OK]\033[0m Sesi berhasil diekspor secara lengkap ke: \033[1m{out_path}\033[0m ({len(lines)} baris)")
                
                # Copy to /sdcard/Download if possible
                if copy_sdcard:
                    sd_dir = "/sdcard/Download"
                    if os.path.exists(sd_dir):
                        try:
                            sd_dest = os.path.join(sd_dir, filename)
                            shutil.copy2(out_path, sd_dest)
                            print(f"\033[32m[OK]\033[0m Disalin ke memori HP: \033[1m{sd_dest}\033[0m")
                        except Exception:
                            pass
                return
            con.close()
        except Exception as e:
            print(f"Error exporting OpenCode session: {e}")

    # 2. Antigravity Session Export (from transcript.jsonl)
    agy_transcript = os.path.join(AGY_DIR, "brain", session_id, ".system_generated", "logs", "transcript.jsonl")
    if os.path.exists(agy_transcript):
        try:
            out_path = os.path.join(EXPORT_DIR, f"agy_{session_id[:10]}.md")
            lines = [
                f"# 📝 Catatan Sesi Antigravity CLI",
                f"- **Platform**: Antigravity CLI (AGY)",
                f"- **Conversation ID**: `{session_id}`",
                "",
                "---",
                ""
            ]
            with open(agy_transcript, "r", encoding="utf-8") as tf:
                for line in tf:
                    if not line.strip():
                        continue
                    step = json.loads(line)
                    stype = step.get("type")
                    content = step.get("content", "")
                    created_at = step.get("created_at", "")[:16]
                    if stype == "USER_INPUT":
                        lines.append(f"### 👤 Pengguna ({created_at})\n\n{content}\n\n---\n")
                    elif stype == "PLANNER_RESPONSE":
                        lines.append(f"### 🤖 Asisten AI ({created_at})\n\n")
                        thinking = step.get("thinking")
                        if thinking:
                            lines.append(f"<details>\n<summary>💭 <b>Alur Berpikir (Thinking)</b></summary>\n\n> {thinking}\n</details>\n\n")
                        if content:
                            lines.append(f"{content}\n\n")
                        lines.append("---\n")
            with open(out_path, "w", encoding="utf-8") as f:
                f.write("\n".join(lines))
            print(f"\033[32m[OK]\033[0m Sesi AGY berhasil diekspor ke: \033[1m{out_path}\033[0m")
            if copy_sdcard and os.path.exists("/sdcard/Download"):
                shutil.copy2(out_path, f"/sdcard/Download/agy_{session_id[:10]}.md")
                print(f"\033[32m[OK]\033[0m Disalin ke memori HP: /sdcard/Download/agy_{session_id[:10]}.md")
            return
        except Exception as e:
            print(f"Error exporting AGY session: {e}")

    print(f"Sesi dengan ID '{session_id}' tidak ditemukan untuk diekspor.")

# ------------------------------------------------------------------------------
# Action: CLEAN LOGS & CACHE
# ------------------------------------------------------------------------------
def action_clean():
    freed_bytes = 0
    cleaned_items = 0

    dirs_to_clean = [
        os.path.join(OPENCODE_DIR, "log"),
        os.path.join(OPENCODE_DIR, "tool-output"),
        os.path.join(OPENCODE_DIR, "snapshot"),
        os.path.join(AGY_DIR, "log"),
        os.path.join(AGY_DIR, "cache")
    ]

    for d in dirs_to_clean:
        if os.path.exists(d):
            for item in os.listdir(d):
                p = os.path.join(d, item)
                try:
                    if os.path.isfile(p):
                        freed_bytes += os.path.getsize(p)
                        os.remove(p)
                        cleaned_items += 1
                    elif os.path.isdir(p):
                        freed_bytes += get_dir_size(p)
                        shutil.rmtree(p)
                        cleaned_items += 1
                except Exception:
                    pass

    print(f"\033[32m[OK]\033[0m Pembersihan selesai!")
    print(f"  • Berkas/folder dibersihkan: {cleaned_items}")
    print(f"  • Ruang disk dibebaskan    : \033[1m\033[32m{format_size(freed_bytes)}\033[0m")

# ------------------------------------------------------------------------------
# Action: VACUUM DATABASE
# ------------------------------------------------------------------------------
def action_vacuum():
    print("\033[1m\033[36mMemulai proses optimasi & SQLite VACUUM...\033[0m")
    total_reclaimed = 0

    if os.path.exists(OPENCODE_DB):
        before_size = os.path.getsize(OPENCODE_DB)
        print(f"Ukuran opencode.db sebelum VACUUM : {format_size(before_size)}")
        try:
            con = sqlite3.connect(OPENCODE_DB)
            con.execute("VACUUM;")
            con.execute("PRAGMA optimize;")
            con.close()
            after_size = os.path.getsize(OPENCODE_DB)
            diff = before_size - after_size
            total_reclaimed += max(0, diff)
            print(f"Ukuran opencode.db sesudah VACUUM : \033[1m\033[32m{format_size(after_size)}\033[0m")
            print(f"Ruang yang berhasil dihemat       : \033[1m\033[32m{format_size(diff)}\033[0m")
        except Exception as e:
            print(f"Gagal melakukan VACUUM pada opencode.db: {e}")

    if os.path.exists(AGY_DB):
        try:
            con = sqlite3.connect(AGY_DB)
            con.execute("VACUUM;")
            con.execute("PRAGMA optimize;")
            con.close()
        except Exception:
            pass

    print(f"\n\033[1m\033[32m🎉 TOTAL RUANG INTERNAL HP DIBEBASKAN: {format_size(total_reclaimed)}\033[0m\n")

# ------------------------------------------------------------------------------
# Action: PRUNE SESSIONS
# ------------------------------------------------------------------------------
def action_prune(days=None, keep_latest=None, prune_empty=False):
    if not os.path.exists(OPENCODE_DB):
        print("Database OpenCode tidak ditemukan.")
        return

    con = sqlite3.connect(OPENCODE_DB)
    cur = con.cursor()

    to_delete_ids = []

    if prune_empty:
        q = "SELECT s.id FROM session s WHERE (SELECT count(*) FROM message m WHERE m.session_id = s.id) = 0"
        to_delete_ids.extend([r[0] for r in cur.execute(q).fetchall()])

    if days is not None:
        cutoff_ms = (datetime.datetime.now() - datetime.timedelta(days=days)).timestamp() * 1000
        q = "SELECT id FROM session WHERE time_updated < ?"
        to_delete_ids.extend([r[0] for r in cur.execute(q, (cutoff_ms,)).fetchall()])

    if keep_latest is not None:
        q = "SELECT id FROM session ORDER BY time_updated DESC LIMIT -1 OFFSET ?"
        to_delete_ids.extend([r[0] for r in cur.execute(q, (keep_latest,)).fetchall()])

    to_delete_ids = list(set(to_delete_ids))

    if not to_delete_ids:
        print("Tidak ada sesi yang memenuhi kriteria penghapusan.")
        con.close()
        return

    print(f"\033[33m[PERINGATAN]\033[0m {len(to_delete_ids)} sesi akan dihapus secara permanen.")
    
    for sid in to_delete_ids:
        cur.execute("DELETE FROM part WHERE session_id=?", (sid,))
        cur.execute("DELETE FROM message WHERE session_id=?", (sid,))
        cur.execute("DELETE FROM session_message WHERE session_id=?", (sid,))
        cur.execute("DELETE FROM session WHERE id=?", (sid,))
        cur.execute("DELETE FROM session_v2 WHERE id=?", (sid,))

    con.commit()
    con.close()
    print(f"\033[32m[OK]\033[0m {len(to_delete_ids)} sesi berhasil dihapus dari database.")
    
    action_vacuum()

# ------------------------------------------------------------------------------
# Main CLI Dispatcher
# ------------------------------------------------------------------------------
cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

if cmd in ("status", "stat"):
    action_status()
elif cmd in ("list", "ls"):
    lim = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 15
    action_list(limit=lim)
elif cmd in ("search", "find"):
    kw = sys.argv[2] if len(sys.argv) > 2 else ""
    if not kw:
        print("Gunakan: session.sh search <kata_kunci>")
    else:
        action_search(kw)
elif cmd == "info":
    sid = sys.argv[2] if len(sys.argv) > 2 else ""
    if not sid:
        print("Gunakan: session.sh info <id_sesi>")
    else:
        action_info(sid)
elif cmd == "export":
    sid = sys.argv[2] if len(sys.argv) > 2 else ""
    if not sid:
        print("Gunakan: session.sh export <id_sesi>")
    else:
        action_export(sid)
elif cmd == "clean":
    action_clean()
elif cmd == "vacuum":
    action_vacuum()
elif cmd == "prune":
    days_val = None
    keep_val = None
    prune_empty_val = False
    
    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--days" and i + 1 < len(sys.argv):
            days_val = int(sys.argv[i+1])
            i += 2
        elif arg == "--keep" and i + 1 < len(sys.argv):
            keep_val = int(sys.argv[i+1])
            i += 2
        elif arg == "--empty":
            prune_empty_val = True
            i += 1
        else:
            i += 1
    
    if days_val is None and keep_val is None and not prune_empty_val:
        print("Tentukan opsi pruning: --days <N> | --keep <N> | --empty")
    else:
        action_prune(days=days_val, keep_latest=keep_val, prune_empty=prune_empty_val)

EOF
}

# ------------------------------------------------------------------------------
# Interactive Menu Wizard
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "     🔄 Termux AI Tools - Session Manager         "
        echo -e "==================================================${RESET}"
        
        run_python_engine "status"
        echo ""
        echo -e "${BOLD}Pilihan Menu:${RESET}"
        echo -e "  ${GREEN}1)${RESET} 📋 Lihat Daftar Sesi Terbaru"
        echo -e "  ${GREEN}2)${RESET} 🔍 Cari Sesi Berdasarkan Kata Kunci"
        echo -e "  ${CYAN}3)${RESET} 📄 Ekspor Sesi Tertentu ke Markdown (.md)"
        echo -e "  ${CYAN}4)${RESET} ⏩ Lanjutkan Sesi di OpenCode"
        echo -e "  ${YELLOW}5)${RESET} 🧹 Bersihkan Berkas Log & Output Sementara"
        echo -e "  ${GREEN}6)${RESET} 🗜️ Optimasi & SQLite VACUUM (Bebaskan GB Storage)"
        echo -e "  ${RED}7)${RESET} 🗑️ Prune / Hapus Sesi Lama Berdasarkan Umur"
        echo -e "  ${CYAN}8)${RESET} 🧠 Knowledge Memory & AI Brain (Solusi & Catatan Permanen)"
        echo -e "  ${YELLOW}0)${RESET} 🚪 Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-8]: " menu_opt

        case "$menu_opt" in
            1)
                echo ""
                read -r -p "Jumlah sesi yang ingin ditampilkan [default: 15]: " lim_in
                lim_in="${lim_in:-15}"
                echo ""
                run_python_engine "list" "$lim_in"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            2)
                echo ""
                read -r -p "Masukkan kata kunci pencarian (judul, topik, id): " kw_in
                if [ -n "$kw_in" ]; then
                    echo ""
                    run_python_engine "search" "$kw_in"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            3)
                echo ""
                read -r -p "Masukkan ID Sesi yang ingin diekspor (contoh: ses_...): " exp_id
                if [ -n "$exp_id" ]; then
                    echo ""
                    run_python_engine "export" "$exp_id"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                echo ""
                read -r -p "Masukkan ID Sesi yang ingin dilanjutkan: " res_id
                if [ -n "$res_id" ]; then
                    echo -e "\nPilih versi OpenCode:"
                    echo -e "  1) OpenCode v2 (Rekomendasi)"
                    echo -e "  2) OpenCode v1"
                    read -r -p "Pilihan [1/2]: " v_choice
                    if [ "$v_choice" = "1" ] && [ -x "$PREFIX/bin/opencode-v2" ]; then
                        exec "$PREFIX/bin/opencode-v2" --session "$res_id"
                    elif [ -x "$PREFIX/bin/opencode" ]; then
                        exec "$PREFIX/bin/opencode" --session "$res_id"
                    else
                        log_err "OpenCode belum terpasang!"
                        sleep 2
                    fi
                fi
                ;;
            5)
                echo ""
                log_info "Membersihkan log lama dan cache sementara..."
                run_python_engine "clean"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            6)
                echo ""
                if pgrep -f "opencode" >/dev/null 2>&1; then
                    log_warn "OpenCode terdeteksi sedang berjalan di latar belakang."
                    read -r -p "Lanjutkan VACUUM sekarang? (Disarankan hentikan service dulu) (y/N): " run_vac
                    if [[ ! "$run_vac" =~ ^[Yy]$ ]]; then
                        continue
                    fi
                fi
                run_python_engine "vacuum"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            7)
                echo ""
                echo -e "${BOLD}${RED}Menu Pruning Sesi Lama:${RESET}"
                echo "1) Hapus sesi yang lebih tua dari 30 hari"
                echo "2) Hapus sesi yang lebih tua dari 14 hari"
                echo "3) Sisakan 20 sesi terbaru (hapus sisanya)"
                echo "4) Input jumlah hari kustom"
                echo "0) Batal"
                read -r -p "Pilihan [0-4]: " p_opt
                
                case "$p_opt" in
                    1)
                        read -r -p "Yakin ingin menghapus sesi > 30 hari? (y/N): " conf
                        [[ "$conf" =~ ^[Yy]$ ]] && run_python_engine "prune" "--days" "30"
                        ;;
                    2)
                        read -r -p "Yakin ingin menghapus sesi > 14 hari? (y/N): " conf
                        [[ "$conf" =~ ^[Yy]$ ]] && run_python_engine "prune" "--days" "14"
                        ;;
                    3)
                        read -r -p "Yakin ingin menyisakan hanya 20 sesi terbaru? (y/N): " conf
                        [[ "$conf" =~ ^[Yy]$ ]] && run_python_engine "prune" "--keep" "20"
                        ;;
                    4)
                        read -r -p "Hapus sesi yang lebih tua dari berapa hari?: " custom_days
                        if [ -n "$custom_days" ]; then
                            read -r -p "Yakin ingin menghapus sesi > $custom_days hari? (y/N): " conf
                            [[ "$conf" =~ ^[Yy]$ ]] && run_python_engine "prune" "--days" "$custom_days"
                        fi
                        ;;
                    *)
                        ;;
                esac
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            8)
                if [ -f "$SCRIPT_DIR/memory-manager.sh" ]; then
                    bash "$SCRIPT_DIR/memory-manager.sh"
                elif [ -f "$REPO_DIR/memory.sh" ]; then
                    bash "$REPO_DIR/memory.sh"
                fi
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
# Dispatcher
# ------------------------------------------------------------------------------
case "$1" in
    status|stat)
        run_python_engine "status"
        ;;
    list|ls)
        shift
        run_python_engine "list" "$@"
        ;;
    search|find)
        shift
        run_python_engine "search" "$@"
        ;;
    info)
        shift
        run_python_engine "info" "$@"
        ;;
    export)
        shift
        run_python_engine "export" "$@"
        ;;
    clean)
        run_python_engine "clean"
        ;;
    vacuum)
        run_python_engine "vacuum"
        ;;
    prune)
        shift
        run_python_engine "prune" "$@"
        ;;
    resume)
        shift
        sid="$1"
        if [ -n "$sid" ]; then
            if [ -x "$PREFIX/bin/opencode-v2" ]; then
                exec "$PREFIX/bin/opencode-v2" --session "$sid"
            else
                exec "$PREFIX/bin/opencode" --session "$sid"
            fi
        else
            echo "Gunakan: session.sh resume <session_id>"
            exit 1
        fi
        ;;
    memory|mem)
        shift
        if [ -f "$SCRIPT_DIR/memory-manager.sh" ]; then
            exec bash "$SCRIPT_DIR/memory-manager.sh" "$@"
        elif [ -f "$REPO_DIR/memory.sh" ]; then
            exec bash "$REPO_DIR/memory.sh" "$@"
        else
            echo "Knowledge Memory manager tidak ditemukan."
            exit 1
        fi
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - Session Manager Usage:${RESET}"
        echo "  session.sh                         Buka menu interaktif TUI"
        echo "  session.sh status                  Tampilkan analisis penyimpanan sesi & dead space"
        echo "  session.sh list [limit]            Tampilkan daftar sesi terbaru"
        echo "  session.sh search <kata_kunci>     Cari sesi percakapan berdasarkan topik/id"
        echo "  session.sh info <id_sesi>          Tampilkan metadata detail sesi"
        echo "  session.sh export <id_sesi>        Ekspor sesi ke file catatan Markdown (.md)"
        echo "  session.sh clean                   Hapus berkas log lama & temporary cache"
        echo "  session.sh vacuum                  Optimasi database SQLite & bebaskan memori HP"
        echo "  session.sh prune --days <N>        Hapus sesi yang lebih tua dari N hari"
        echo "  session.sh prune --keep <N>        Sisakan N sesi terbaru, hapus sisanya"
        echo "  session.sh resume <id_sesi>        Lanjutkan sesi di OpenCode"
        echo "  session.sh memory <command>        Akses Knowledge Memory / AI Brain (CRUD & Search)"
        exit 0
        ;;
    *)
        interactive_menu
        ;;
esac

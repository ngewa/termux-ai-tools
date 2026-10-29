#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - AI Persona & Subagent Manager (agent.sh / aiagent)
# Manages:
#   - Specialized AI personas and subagents across OpenCode and Antigravity
#   - Antigravity Agents: ~/.gemini/config/agents/<name>/agent.md
#   - OpenCode Agents: ~/.config/opencode/agents/<name>.md
#   - Cross-platform persona synchronization (Antigravity <-> OpenCode)
#   - Toggle active/disabled, scaffold creation, preset archetypes, and doctor audit
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
    log_err "Python3 diperlukan untuk mengelola AI Subagents & Personas."
    echo "Jalankan: pkg install python"
    exit 1
fi

# Ensure storage directories exist
mkdir -p "$HOME_DIR/.gemini/config/agents" "$HOME_DIR/.gemini/config/agents-disabled"
mkdir -p "$HOME_DIR/.config/opencode/agents" "$HOME_DIR/.config/opencode/agents-disabled"

# ------------------------------------------------------------------------------
# Python Core Agent Manager Engine
# ------------------------------------------------------------------------------
run_python_manager() {
    python3 - "$@" << 'EOF'
import sys, os, shutil, re, subprocess, json

HOME = os.path.expanduser("~")
AGY_AGENTS_DIR = os.path.join(HOME, ".gemini", "config", "agents")
AGY_AGENTS_DIS = os.path.join(HOME, ".gemini", "config", "agents-disabled")
OC_AGENTS_DIR = os.path.join(HOME, ".config", "opencode", "agents")
OC_AGENTS_DIS = os.path.join(HOME, ".config", "opencode", "agents-disabled")

DEFAULT_TOOLS = [
    "read_file", "write_file", "edit_file", "run_command", "manage_task",
    "send_message", "schedule", "invoke_subagent", "define_subagent",
    "manage_subagents", "search_web", "ask_question"
]

PRESETS = {
    "code-reviewer": {
        "name": "code-reviewer",
        "desc": "Spesialis audit kode mendalam, deteksi regresi logika, analisis blast radius, dan keamanan.",
        "prompt": """# Code Reviewer Specialist

Anda adalah **Code Reviewer Specialist**. Tugas Anda adalah menganalisis perubahan kode secara objektif, ketat, dan berbasis risiko.

## Aturan Utama
1. Analisis perubahan sebelum mengeksekusi patch.
2. Identifikasi potensi breaking change pada API publik dan database migrations.
3. Berikan saran refaktorisasi yang token-efficient dan minim kompleksitas siklomatis.
4. Pastikan unit test mencakup skenario happy path dan edge cases (nilai null, batas array, timeout)."""
    },
    "android-reverser": {
        "name": "android-reverser",
        "desc": "Spesialis reverse engineering Android (APK decompilation, Smali, patch biner ARM64 ELF, & bypass gate).",
        "prompt": """# Android Reverse Engineering Specialist

Anda adalah **Android Reverse Engineering Specialist** di lingkungan Termux.

## Fokus & Prosedur
1. Analisis struktur paket APK (`classes.dex`, `lib/arm64-v8a/*.so`, `AndroidManifest.xml`).
2. Gunakan `apktool` untuk disassembly resource/smali, dan `readelf`/`objdump` untuk biner natif ELF.
3. Utamakan teknik patch in-place presisi tanpa memodifikasi bagian yang tidak relevan.
4. Verifikasi signature dan alignment APK sebelum instalasi."""
    },
    "fullstack-dev": {
        "name": "fullstack-dev",
        "desc": "Spesialis full-stack web dev (Backend API, Frontend modern, database schema, & auth workflow).",
        "prompt": """# Full-Stack Web Engineer

Anda adalah **Full-Stack Web Engineer** profesional.

## Standar Kerja
1. Bangun arsitektur yang modular, bersih, dan mudah di-maintain (Separation of Concerns).
2. Terapkan validasi input yang ketat di sisi server (SQL Injection, XSS, CSRF protection).
3. Buat UI yang responsif dan mobile-friendly dengan standard aksesibilitas tinggi.
4. Sertakan automated smoke test atau unit test di setiap penambahan fitur."""
    },
    "bash-automator": {
        "name": "bash-automator",
        "desc": "Spesialis otomatisasi Termux/Linux (skrip Bash tangguh, background services, cron, & CLI utilities).",
        "prompt": """# Linux & Termux Automation Specialist

Anda adalah **Linux & Termux Automation Specialist**.

## Standar Penulisan Skrip
1. Selalu gunakan `set -e` dan tangani error dengan gracefully.
2. Hindari dependensi biner eksternal yang tidak tersedia di Termux standar.
3. Gunakan POSIX compliant constructs bila memungkinkan dan hindari command injection via `$()`.
4. Berikan output terminal yang informatif dengan kode warna ANSI standar."""
    }
}

def parse_agent_file(filepath):
    if not os.path.isfile(filepath):
        return None
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        return {"error": str(e), "valid": False}

    meta = {
        "filepath": filepath,
        "name": os.path.splitext(os.path.basename(filepath))[0],
        "description": "",
        "valid": False,
        "tools": [],
        "body": ""
    }

    m = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)$", content, re.DOTALL)
    if m:
        meta["valid"] = True
        raw_header = m.group(1)
        meta["body"] = m.group(2).strip()

        # Parse simple frontmatter keys
        in_tools = False
        for line in raw_header.splitlines():
            sline = line.strip()
            if not sline or sline.startswith("#"):
                continue
            if sline.startswith("tools:"):
                in_tools = True
                continue
            if in_tools:
                if sline.startswith("-"):
                    meta["tools"].append(sline.lstrip("-").strip())
                    continue
                else:
                    in_tools = False
            if ":" in sline:
                k, v = sline.split(":", 1)
                k = k.strip().lower()
                v = v.strip().strip("\"'")
                if k in ["name", "description", "mode"]:
                    meta[k] = v
    else:
        meta["body"] = content.strip()

    if not meta.get("description"):
        meta["description"] = "(Tanpa deskripsi)"
    return meta

def scan_all_agents():
    agents = []

    # 1. Antigravity Active (~/.gemini/config/agents/<name>/agent.md)
    if os.path.isdir(AGY_AGENTS_DIR):
        for e in sorted(os.listdir(AGY_AGENTS_DIR)):
            p = os.path.join(AGY_AGENTS_DIR, e, "agent.md")
            if os.path.isfile(p):
                data = parse_agent_file(p)
                if data:
                    agents.append({
                        "id": e,
                        "name": data.get("name", e),
                        "description": data.get("description", ""),
                        "platform": "Antigravity",
                        "status": "active",
                        "path": p,
                        "tools": data.get("tools", []),
                        "body": data.get("body", ""),
                        "valid": data.get("valid", False)
                    })

    # 2. Antigravity Disabled (~/.gemini/config/agents-disabled/<name>/agent.md)
    if os.path.isdir(AGY_AGENTS_DIS):
        for e in sorted(os.listdir(AGY_AGENTS_DIS)):
            p = os.path.join(AGY_AGENTS_DIS, e, "agent.md")
            if os.path.isfile(p):
                data = parse_agent_file(p)
                if data:
                    agents.append({
                        "id": e,
                        "name": data.get("name", e),
                        "description": data.get("description", ""),
                        "platform": "Antigravity",
                        "status": "disabled",
                        "path": p,
                        "tools": data.get("tools", []),
                        "body": data.get("body", ""),
                        "valid": data.get("valid", False)
                    })

    # 3. OpenCode Active (~/.config/opencode/agents/<name>.md)
    if os.path.isdir(OC_AGENTS_DIR):
        for e in sorted(os.listdir(OC_AGENTS_DIR)):
            if e.endswith(".md"):
                aid = e[:-3]
                p = os.path.join(OC_AGENTS_DIR, e)
                data = parse_agent_file(p)
                if data:
                    agents.append({
                        "id": aid,
                        "name": data.get("name", aid),
                        "description": data.get("description", ""),
                        "platform": "OpenCode",
                        "status": "active",
                        "path": p,
                        "tools": data.get("tools", []),
                        "body": data.get("body", ""),
                        "valid": data.get("valid", False)
                    })

    # 4. OpenCode Disabled (~/.config/opencode/agents-disabled/<name>.md)
    if os.path.isdir(OC_AGENTS_DIS):
        for e in sorted(os.listdir(OC_AGENTS_DIS)):
            if e.endswith(".md"):
                aid = e[:-3]
                p = os.path.join(OC_AGENTS_DIS, e)
                data = parse_agent_file(p)
                if data:
                    agents.append({
                        "id": aid,
                        "name": data.get("name", aid),
                        "description": data.get("description", ""),
                        "platform": "OpenCode",
                        "status": "disabled",
                        "path": p,
                        "tools": data.get("tools", []),
                        "body": data.get("body", ""),
                        "valid": data.get("valid", False)
                    })

    return agents

# ------------------------------------------------------------------------------
# Action: LIST / STATUS
# ------------------------------------------------------------------------------
def action_list():
    agents = scan_all_agents()
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                     STATUS AI PERSONAS & SUBAGENTS TERPASANG                           \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m")

    if not agents:
        print("  \033[33m(Belum ada AI Persona / Subagent yang terdaftar di Antigravity atau OpenCode)\033[0m")
        print("\n  \033[36mTip:\033[0m Buat persona baru dengan: \033[1maiagent create <nama>\033[0m atau pasang template: \033[1maiagent presets\033[0m")
        return

    # Group by platform
    by_plat = {"Antigravity": [], "OpenCode": []}
    for a in agents:
        by_plat.setdefault(a["platform"], []).append(a)

    for plat_name, list_agents in by_plat.items():
        loc_str = "~/.gemini/config/agents/" if plat_name == "Antigravity" else "~/.config/opencode/agents/"
        print(f"\n\033[1m{plat_name} Personas ({loc_str}):\033[0m")
        if not list_agents:
            print("  \033[33m(Kosong)\033[0m")
            continue
        for a in list_agents:
            st = "\033[32m[AKTIF]\033[0m" if a["status"] == "active" else "\033[33m[NONAKTIF]\033[0m"
            tools_info = f" \033[2m({len(a['tools'])} tools)\033[0m" if a["tools"] else ""
            desc = a["description"]
            if len(desc) > 65:
                desc = desc[:62] + "..."
            print(f"  • {st} \033[1m{a['id']:<18}\033[0m{tools_info}")
            print(f"      \033[2m{desc}\033[0m")

    total_active = sum(1 for a in agents if a["status"] == "active")
    total_dis = len(agents) - total_active
    print(f"\n\033[1mRingkasan:\033[0m Total: \033[1m{len(agents)}\033[0m persona | Aktif: \033[32m{total_active}\033[0m | Nonaktif: \033[33m{total_dis}\033[0m")

# ------------------------------------------------------------------------------
# Action: PRESETS
# ------------------------------------------------------------------------------
def action_presets():
    installed_ids = {a["id"] for a in scan_all_agents()}
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                    KATALOG TEMPLATE PRESET SUBAGENT POPULER                            \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m\n")

    for pid, p in PRESETS.items():
        is_inst = pid in installed_ids
        st = "\033[32m[TERPASANG]\033[0m" if is_inst else "\033[36m[TERSEDIA]\033[0m"
        print(f"  • {st} \033[1m{pid:<18}\033[0m")
        print(f"      {p['desc']}\n")

    print("\033[1mCara Pasang:\033[0m")
    print("  aiagent create <preset-name> [--opencode|--gemini|--both]")
    print("  (Contoh: \033[32maiagent create code-reviewer --both\033[0m)")

# ------------------------------------------------------------------------------
# Action: CREATE
# ------------------------------------------------------------------------------
def action_create(agent_name, target_platform="both", custom_desc=None, custom_prompt=None):
    if not agent_name:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama persona agent baru.")
        sys.exit(1)

    agent_id = re.sub(r"[^a-zA-Z0-9_-]", "-", agent_name).lower()

    desc = custom_desc
    body = custom_prompt

    if agent_id in PRESETS and not custom_desc:
        desc = PRESETS[agent_id]["desc"]
        body = PRESETS[agent_id]["prompt"]
    else:
        if not desc:
            desc = f"Spesialis persona untuk alur kerja {agent_id}."
        if not body:
            body = f"""# {agent_id.replace('-', ' ').title()} Specialist

Anda adalah **{agent_id.replace('-', ' ').title()} Specialist**.

## Tanggung Jawab
- Membantu penyelesaian tugas khusus terkait proyek {agent_id}.
- Memberikan solusi teknis yang akurat, aman, dan efisien."""

    created_any = False

    # 1. Antigravity target
    if target_platform in ["both", "gemini", "antigravity", "agy"]:
        dest_folder = os.path.join(AGY_AGENTS_DIR, agent_id)
        os.makedirs(dest_folder, exist_ok=True)
        dest_file = os.path.join(dest_folder, "agent.md")

        tools_yaml = "\n".join([f"  - {t}" for t in DEFAULT_TOOLS])
        content_agy = f"""---
name: {agent_id}
description: "{desc}"
mainAgent: true
tools:
{tools_yaml}
---

{body}
"""
        with open(dest_file, "w", encoding="utf-8") as f:
            f.write(content_agy)
        print(f"\033[32m[OK]\033[0m Persona Antigravity dibuat di: \033[36m{dest_file}\033[0m")
        created_any = True

    # 2. OpenCode target
    if target_platform in ["both", "opencode", "oc"]:
        os.makedirs(OC_AGENTS_DIR, exist_ok=True)
        dest_file = os.path.join(OC_AGENTS_DIR, f"{agent_id}.md")

        content_oc = f"""---
description: "{desc}"
mode: all
permission:
  edit: allow
  shell: allow
---

{body}
"""
        with open(dest_file, "w", encoding="utf-8") as f:
            f.write(content_oc)
        print(f"\033[32m[OK]\033[0m Persona OpenCode dibuat di: \033[36m{dest_file}\033[0m")
        created_any = True

    if created_any:
        print(f"\033[32m[SUKSES]\033[0m Persona '\033[1m{agent_id}\033[0m' siap digunakan!")

# ------------------------------------------------------------------------------
# Action: SYNC (Bridge Antigravity <-> OpenCode)
# ------------------------------------------------------------------------------
def action_sync(target_agent=None):
    agents = scan_all_agents()
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m              SINKRONISASI SILANG PERSONA (Antigravity <-> OpenCode)                     \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m\n")

    agy_map = {a["id"]: a for a in agents if a["platform"] == "Antigravity"}
    oc_map = {a["id"]: a for a in agents if a["platform"] == "OpenCode"}

    synced_count = 0

    # Sync Antigravity -> OpenCode
    for aid, a in agy_map.items():
        if target_agent and aid != target_agent:
            continue
        if aid not in oc_map:
            print(f"\033[36m[SYNC]\033[0m Mengonversi Antigravity '{aid}' -> OpenCode...")
            action_create(aid, target_platform="opencode", custom_desc=a["description"], custom_prompt=a["body"])
            synced_count += 1

    # Sync OpenCode -> Antigravity
    for aid, a in oc_map.items():
        if target_agent and aid != target_agent:
            continue
        if aid not in agy_map:
            print(f"\033[36m[SYNC]\033[0m Mengonversi OpenCode '{aid}' -> Antigravity...")
            action_create(aid, target_platform="antigravity", custom_desc=a["description"], custom_prompt=a["body"])
            synced_count += 1

    if synced_count == 0:
        print("  \033[32m[OK]\033[0m Seluruh persona sudah sinkron di kedua platform (Antigravity & OpenCode).")
    else:
        print(f"\n\033[32m[OK]\033[0m Berhasil menyinkronkan {synced_count} persona antar platform!")

# ------------------------------------------------------------------------------
# Action: INFO / INSPECT
# ------------------------------------------------------------------------------
def action_info(agent_id):
    if not agent_id:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama persona.")
        sys.exit(1)

    matches = [a for a in scan_all_agents() if a["id"] == agent_id]
    if not matches:
        print(f"\033[31m[ERROR]\033[0m Persona '{agent_id}' tidak ditemukan.")
        return

    print("\033[1m\033[36m========================================================================================\033[0m")
    print(f"\033[1m                         DETAIL AI PERSONA: {agent_id.upper()}                          \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m")

    for a in matches:
        st_color = "\033[32m[AKTIF]\033[0m" if a["status"] == "active" else "\033[33m[NONAKTIF]\033[0m"
        print(f"\n\033[1mPlatform    : {a['platform']} {st_color}\033[0m")
        print(f"  • Berkas      : {a['path']}")
        print(f"  • Deskripsi   : {a['description']}")
        if a["tools"]:
            print(f"  • Tools Aktif : {', '.join(a['tools'])}")

    first = matches[0]
    print(f"\n\033[1mPratinjau Instruksi Sistem:\033[0m")
    print("\033[2m" + "-" * 70 + "\033[0m")
    lines = first["body"].splitlines()
    for l in lines[:25]:
        print(l)
    if len(lines) > 25:
        print(f"\033[2m... ({len(lines) - 25} baris lainnya)\033[0m")
    print("\033[2m" + "-" * 70 + "\033[0m")

# ------------------------------------------------------------------------------
# Action: TOGGLE / ENABLE / DISABLE
# ------------------------------------------------------------------------------
def action_toggle(agent_id, explicit_state=None):
    if not agent_id:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama persona.")
        sys.exit(1)

    toggled_any = False

    # 1. Antigravity toggle
    act_agy = os.path.join(AGY_AGENTS_DIR, agent_id)
    dis_agy = os.path.join(AGY_AGENTS_DIS, agent_id)

    if os.path.isdir(act_agy) and explicit_state != "enable":
        os.makedirs(AGY_AGENTS_DIS, exist_ok=True)
        shutil.move(act_agy, dis_agy)
        print(f"\033[32m[OK]\033[0m Persona Antigravity '{agent_id}' dinonaktifkan.")
        toggled_any = True
    elif os.path.isdir(dis_agy) and explicit_state != "disable":
        os.makedirs(AGY_AGENTS_DIR, exist_ok=True)
        shutil.move(dis_agy, act_agy)
        print(f"\033[32m[OK]\033[0m Persona Antigravity '{agent_id}' diaktifkan.")
        toggled_any = True

    # 2. OpenCode toggle
    act_oc = os.path.join(OC_AGENTS_DIR, f"{agent_id}.md")
    dis_oc = os.path.join(OC_AGENTS_DIS, f"{agent_id}.md")

    if os.path.isfile(act_oc) and explicit_state != "enable":
        os.makedirs(OC_AGENTS_DIS, exist_ok=True)
        shutil.move(act_oc, dis_oc)
        print(f"\033[32m[OK]\033[0m Persona OpenCode '{agent_id}' dinonaktifkan.")
        toggled_any = True
    elif os.path.isfile(dis_oc) and explicit_state != "disable":
        os.makedirs(OC_AGENTS_DIR, exist_ok=True)
        shutil.move(dis_oc, act_oc)
        print(f"\033[32m[OK]\033[0m Persona OpenCode '{agent_id}' diaktifkan.")
        toggled_any = True

    if not toggled_any:
        print(f"\033[31m[ERROR]\033[0m Persona '{agent_id}' tidak ditemukan atau sudah dalam status yang diminta.")

# ------------------------------------------------------------------------------
# Action: REMOVE
# ------------------------------------------------------------------------------
def action_remove(agent_id):
    if not agent_id:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama persona yang ingin dihapus.")
        sys.exit(1)

    targets = [
        os.path.join(AGY_AGENTS_DIR, agent_id),
        os.path.join(AGY_AGENTS_DIS, agent_id),
        os.path.join(OC_AGENTS_DIR, f"{agent_id}.md"),
        os.path.join(OC_AGENTS_DIS, f"{agent_id}.md")
    ]

    deleted_any = False
    for t in targets:
        if os.path.isdir(t):
            shutil.rmtree(t)
            print(f"\033[32m[OK]\033[0m Berhasil menghapus direktori: {t}")
            deleted_any = True
        elif os.path.isfile(t):
            os.remove(t)
            print(f"\033[32m[OK]\033[0m Berhasil menghapus berkas: {t}")
            deleted_any = True

    if not deleted_any:
        print(f"\033[31m[ERROR]\033[0m Persona '{agent_id}' tidak ditemukan di sistem.")

# ------------------------------------------------------------------------------
# Action: DOCTOR / AUDIT
# ------------------------------------------------------------------------------
def action_doctor():
    agents = scan_all_agents()
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                        AUDIT & DIAGNOSTIK KESEHATAN PERSONA                            \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m\n")

    total = len(agents)
    passed = 0
    warnings = 0
    errors = 0

    agy_ids = {a["id"] for a in agents if a["platform"] == "Antigravity"}
    oc_ids = {a["id"] for a in agents if a["platform"] == "OpenCode"}

    for a in agents:
        aid = a["id"]
        issues = []

        if not a["valid"]:
            issues.append("YAML frontmatter header tidak valid atau hilang (wajib diapit '---')")
            errors += 1
        elif not a["description"] or a["description"] == "(Tanpa deskripsi)":
            issues.append("Deskripsi persona kosong di frontmatter")
            warnings += 1

        if not a["body"]:
            issues.append("Instruksi sistem (prompt body) kosong")
            errors += 1

        # Check cross-platform availability
        if a["platform"] == "Antigravity" and aid not in oc_ids:
            issues.append("Tersedia di Antigravity, tapi belum disinkronkan ke OpenCode (Jalankan: aiagent sync)")
            warnings += 1
        elif a["platform"] == "OpenCode" and aid not in agy_ids:
            issues.append("Tersedia di OpenCode, tapi belum disinkronkan ke Antigravity (Jalankan: aiagent sync)")
            warnings += 1

        if not issues:
            print(f"  [\033[32mPASS\033[0m] \033[1m{aid:<20}\033[0m ({a['platform']})")
            passed += 1
        else:
            is_err = any("tidak valid" in i or "kosong" in i for i in issues)
            tag = "\033[31mFAIL\033[0m" if is_err else "\033[33mWARN\033[0m"
            print(f"  [{tag}] \033[1m{aid:<20}\033[0m ({a['platform']})")
            for iss in issues:
                print(f"         \033[33m• {iss}\033[0m")

    print(f"\n\033[1mHasil Audit:\033[0m Total: {total} | Pass: \033[32m{passed}\033[0m | Warning: \033[33m{warnings}\033[0m | Error: \033[31m{errors}\033[0m")

# ------------------------------------------------------------------------------
# Dispatcher for Python engine
# ------------------------------------------------------------------------------
cmd = sys.argv[1] if len(sys.argv) > 1 else "status"

if cmd in ["status", "list", "ls"]:
    action_list()
elif cmd == "presets":
    action_presets()
elif cmd in ["create", "new", "add"]:
    name = sys.argv[2] if len(sys.argv) > 2 else ""
    target_p = "both"
    if "--gemini" in sys.argv or "--agy" in sys.argv:
        target_p = "gemini"
    elif "--opencode" in sys.argv or "--oc" in sys.argv:
        target_p = "opencode"
    action_create(name, target_platform=target_p)
elif cmd == "sync":
    target = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("-") else None
    action_sync(target)
elif cmd in ["info", "show"]:
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_info(target)
elif cmd == "enable":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_toggle(target, explicit_state="enable")
elif cmd == "disable":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_toggle(target, explicit_state="disable")
elif cmd == "toggle":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_toggle(target)
elif cmd in ["remove", "rm", "del", "uninstall"]:
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_remove(target)
elif cmd in ["doctor", "check", "audit"]:
    action_doctor()
else:
    print(f"\033[31m[ERROR]\033[0m Perintah '{cmd}' tidak dikenal.")
    sys.exit(1)
EOF
}

# ------------------------------------------------------------------------------
# Launch Helper
# ------------------------------------------------------------------------------
run_agent() {
    local agent_name="$1"
    local tool_target="${2:-auto}"

    if [ -z "$agent_name" ]; then
        echo -e "${RED}[ERROR]${RESET} Harap masukkan nama persona yang ingin dijalankan."
        echo "Contoh: aiagent run roblox-engineer"
        exit 1
    fi

    echo -e "${BOLD}${CYAN}Memulai persona spesialis:${RESET} \033[1m$agent_name\033[0m"

    if [ "$tool_target" = "oc" ] || [ "$tool_target" = "opencode" ]; then
        if [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode" --agent "$agent_name"
        fi
    elif [ "$tool_target" = "oc2" ] || [ "$tool_target" = "opencode-v2" ]; then
        if [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2" --agent "$agent_name"
        fi
    fi

    # Auto select: Prefer OpenCode v2 if available, else Antigravity
    if [ -f "$HOME_DIR/.config/opencode/agents/$agent_name.md" ]; then
        if [ -x "$PREFIX/bin/opencode-v2" ]; then
            exec "$PREFIX/bin/opencode-v2" --agent "$agent_name"
        elif [ -x "$PREFIX/bin/opencode" ]; then
            exec "$PREFIX/bin/opencode" --agent "$agent_name"
        fi
    fi

    if [ -d "$HOME_DIR/.gemini/config/agents/$agent_name" ]; then
        echo -e "${GREEN}[INFO]${RESET} Persona terdaftar di Antigravity CLI."
        echo -e "Memulai Antigravity CLI... (Panggil persona di prompt dengan: ${CYAN}@$agent_name${RESET} atau ${CYAN}subagent $agent_name${RESET})"
        sleep 1
        if [ -x "$PREFIX/bin/agy" ]; then
            exec "$PREFIX/bin/agy"
        fi
    fi

    echo -e "${RED}[ERROR]${RESET} Persona '$agent_name' tidak ditemukan."
    exit 1
}

# ------------------------------------------------------------------------------
# Interactive Menu Wizard
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "    🤖 Termux AI Tools - AI Subagents & Personas "
        echo -e "==================================================${RESET}"

        run_python_manager "status"
        echo ""
        echo -e "${BOLD}Pilihan Menu:${RESET}"
        echo -e "  ${GREEN}1)${RESET} 📋 Lihat Katalog Template Preset Populer"
        echo -e "  ${GREEN}2)${RESET} ⚡ Pasang Template Preset Baru"
        echo -e "  ${GREEN}3)${RESET} ✨ Buat Persona Spesialis Baru (Custom Wizard)"
        echo -e "  ${CYAN}4)${RESET} 🔄 Sinkronkan Silang Persona (Antigravity <-> OpenCode)"
        echo -e "  ${CYAN}5)${RESET} 🔍 Detail & Pratinjau Persona (Inspect)"
        echo -e "  ${CYAN}6)${RESET} ⏯️ Toggle Aktifkan / Nonaktifkan Persona"
        echo -e "  ${CYAN}7)${RESET} 🚀 Jalankan Persona (Launch OpenCode / Antigravity)"
        echo -e "  ${RED}8)${RESET} 🗑️ Hapus Persona"
        echo -e "  ${YELLOW}9)${RESET} 🩺 Audit & Diagnostik Integritas Persona (Doctor)"
        echo -e "  ${YELLOW}0)${RESET} 🚪 Kembali / Keluar"
        echo ""
        read -r -p "Pilihan Anda [0-9]: " menu_opt

        case "$menu_opt" in
            1)
                echo ""
                run_python_manager "presets"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            2)
                echo ""
                echo -e "${BOLD}Pilih template preset:${RESET}"
                echo "  1) code-reviewer     (Audit kode mendalam & blast radius)"
                echo "  2) android-reverser  (APK/Smali reverse engineering & bypass gate)"
                echo "  3) fullstack-dev     (Modern web developer API & UI)"
                echo "  4) bash-automator    (Termux/Linux automation & shell scripting)"
                echo "  0) Batal"
                echo ""
                read -r -p "Pilihan preset [0-4]: " p_choice
                case "$p_choice" in
                    1) run_python_manager "create" "code-reviewer" ;;
                    2) run_python_manager "create" "android-reverser" ;;
                    3) run_python_manager "create" "fullstack-dev" ;;
                    4) run_python_manager "create" "bash-automator" ;;
                    *) echo "Dibatalkan." ;;
                esac
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            3)
                echo ""
                read -r -p "Nama ID persona baru (contoh: python-expert): " new_name
                if [ -n "$new_name" ]; then
                    echo "Pilih target platform:"
                    echo "  1) Kedua Platform (Antigravity & OpenCode) [Rekomendasi]"
                    echo "  2) Antigravity CLI saja"
                    echo "  3) OpenCode saja"
                    read -r -p "Pilihan target [1-3, default 1]: " plat_choice
                    case "$plat_choice" in
                        2) run_python_manager "create" "$new_name" "--gemini" ;;
                        3) run_python_manager "create" "$new_name" "--opencode" ;;
                        *) run_python_manager "create" "$new_name" ;;
                    esac
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                echo ""
                run_python_manager "sync"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            5)
                echo ""
                read -r -p "Masukkan nama persona yang ingin diperiksa: " inf_name
                if [ -n "$inf_name" ]; then
                    echo ""
                    run_python_manager "info" "$inf_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            6)
                echo ""
                read -r -p "Masukkan nama persona yang ingin di-toggle: " tog_name
                if [ -n "$tog_name" ]; then
                    echo ""
                    run_python_manager "toggle" "$tog_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            7)
                echo ""
                read -r -p "Masukkan nama persona yang ingin dijalankan: " run_name
                if [ -n "$run_name" ]; then
                    run_agent "$run_name"
                fi
                ;;
            8)
                echo ""
                read -r -p "Masukkan nama persona yang ingin dihapus: " del_name
                if [ -n "$del_name" ]; then
                    read -r -p "Yakin ingin menghapus persona '$del_name'? (y/N): " conf_del
                    if [[ "$conf_del" =~ ^[Yy]$ ]]; then
                        echo ""
                        run_python_manager "remove" "$del_name"
                    fi
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            9)
                echo ""
                run_python_manager "doctor"
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            0)
                echo "Selesai."
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
    status|list|ls)
        run_python_manager "status"
        ;;
    presets|preset|catalog)
        run_python_manager "presets"
        ;;
    create|new|add)
        shift
        run_python_manager "create" "$@"
        ;;
    sync)
        shift
        run_python_manager "sync" "$@"
        ;;
    info|show|inspect)
        shift
        run_python_manager "info" "$@"
        ;;
    toggle)
        shift
        run_python_manager "toggle" "$@"
        ;;
    enable)
        shift
        run_python_manager "enable" "$@"
        ;;
    disable)
        shift
        run_python_manager "disable" "$@"
        ;;
    run|start)
        shift
        run_agent "$@"
        ;;
    remove|rm|del|uninstall)
        shift
        run_python_manager "remove" "$@"
        ;;
    doctor|check|audit)
        run_python_manager "doctor"
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - AI Persona & Subagent Manager Usage:${RESET}"
        echo "  aiagent                             Buka menu interaktif TUI"
        echo "  aiagent list                        Tampilkan daftar persona aktif & nonaktif"
        echo "  aiagent presets                     Lihat katalog template persona populer"
        echo "  aiagent create <nama> [--both|--oc] Buat persona baru dengan template terstruktur"
        echo "  aiagent sync [nama]                 Sinkronkan persona antara Antigravity & OpenCode"
        echo "  aiagent info <nama>                 Tampilkan detail metadata, tools & prompt"
        echo "  aiagent toggle <nama>               Aktifkan/nonaktifkan persona"
        echo "  aiagent run <nama>                  Jalankan OpenCode/Antigravity dengan persona tersebut"
        echo "  aiagent remove <nama>               Hapus persona dari sistem"
        echo "  aiagent doctor                      Audit integritas format & kelengkapan persona"
        exit 0
        ;;
    *)
        interactive_menu
        ;;
esac

#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Termux AI Tools - AI Agent Skill Manager (skill.sh / aiskill)
# Manages:
#   - Agent Skills conforming to the open SKILL.md specification
#   - Universal agent directory: ~/.agents/skills/ & ~/.agents/skills-disabled/
#   - Antigravity user directory: ~/.gemini/skills/ & ~/.gemini/skills-disabled/
#   - Preset catalog (prompt-master, antislop, ui-ux-pro-max, banner-design, etc.)
#   - Git-based install, update, remove, inspect, enable/disable, and doctor audit
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
    log_err "Python3 diperlukan untuk mengelola AI Agent Skills."
    echo "Jalankan: pkg install python"
    exit 1
fi

# Ensure base directories exist
mkdir -p "$HOME_DIR/.agents/skills" "$HOME_DIR/.agents/skills-disabled"
mkdir -p "$HOME_DIR/.gemini/skills" "$HOME_DIR/.gemini/skills-disabled"

# ------------------------------------------------------------------------------
# Python Core Skill Manager Engine
# ------------------------------------------------------------------------------
run_python_manager() {
    python3 - "$@" << 'EOF'
import sys, os, shutil, re, subprocess, json

HOME = os.path.expanduser("~")
UNIVERSAL_ACTIVE = os.path.join(HOME, ".agents", "skills")
UNIVERSAL_DISABLED = os.path.join(HOME, ".agents", "skills-disabled")
GEMINI_ACTIVE = os.path.join(HOME, ".gemini", "skills")
GEMINI_DISABLED = os.path.join(HOME, ".gemini", "skills-disabled")

PRESETS = {
    "prompt-master": {
        "name": "prompt-master",
        "desc": "Generates optimized, high-performance prompts for any AI tool (Cursor, Midjourney, Claude, Gemini, etc.)",
        "url": "https://github.com/nidhinjs/prompt-master.git",
        "author": "nidhinjs"
    },
    "antislop": {
        "name": "antislop",
        "desc": "Anti-slop filters & code hygiene, eliminates generic AI boilerplate & fluff",
        "url": "https://github.com/thevahidal/antislop.git",
        "author": "thevahidal"
    },
    "ui-ux-pro-max": {
        "name": "ui-ux-pro-max",
        "desc": "UI/UX design intelligence, design tokens, 192 product palettes, responsive layouts",
        "url": "https://github.com/nextlevelcoder/ui-ux-pro-max.git",
        "author": "nextlevelcoder"
    },
    "banner-design": {
        "name": "banner-design",
        "desc": "Design banners for ads, social media, web heroes, and creative marketing assets",
        "url": "https://github.com/nextlevelcoder/banner-design.git",
        "author": "nextlevelcoder"
    },
    "code-review-graph": {
        "name": "code-review-graph",
        "desc": "Knowledge graph assisted code exploration, blast radius analysis & reviews",
        "url": "https://github.com/raghavdua/code-review-graph.git",
        "author": "raghavdua"
    }
}

def parse_frontmatter(skill_dir):
    skill_file = None
    for name in ["SKILL.md", "skill.md", "Skill.md"]:
        candidate = os.path.join(skill_dir, name)
        if os.path.isfile(candidate):
            skill_file = candidate
            break

    if not skill_file:
        return {"file": None, "name": os.path.basename(skill_dir), "description": "(SKILL.md tidak ditemukan)", "valid": False}

    try:
        with open(skill_file, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read(8192)
    except Exception as e:
        return {"file": skill_file, "name": os.path.basename(skill_dir), "description": f"(Error membaca: {e})", "valid": False}

    meta = {"file": skill_file, "name": os.path.basename(skill_dir), "description": "", "valid": False}
    m = re.match(r"^---\s*\n(.*?)\n---", content, re.DOTALL)
    if m:
        meta["valid"] = True
        raw = m.group(1)
        for line in raw.splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if ":" in line:
                k, v = line.split(":", 1)
                k = k.strip().lower()
                v = v.strip().strip("\"'")
                if k in ["name", "description", "version", "author"]:
                    meta[k] = v
    if not meta.get("description"):
        meta["description"] = "(Tanpa deskripsi)"
    return meta

def get_dir_size(path):
    total = 0
    file_count = 0
    try:
        for root, dirs, files in os.walk(path):
            for f in files:
                fp = os.path.join(root, f)
                if not os.path.islink(fp):
                    total += os.path.getsize(fp)
                    file_count += 1
    except Exception:
        pass
    if total < 1024:
        s = f"{total} B"
    elif total < 1024 * 1024:
        s = f"{total / 1024:.1f} KB"
    else:
        s = f"{total / (1024 * 1024):.1f} MB"
    return s, file_count

def get_git_info(path):
    git_dir = os.path.join(path, ".git")
    if not os.path.isdir(git_dir):
        return None
    try:
        remote = subprocess.check_output(
            ["git", "-C", path, "remote", "get-url", "origin"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        return remote
    except Exception:
        return "git-repo"

def scan_skills():
    results = []
    locations = [
        ("Universal (~/.agents/skills)", UNIVERSAL_ACTIVE, True),
        ("Universal Disabled (~/.agents/skills-disabled)", UNIVERSAL_DISABLED, False),
        ("Antigravity (~/.gemini/skills)", GEMINI_ACTIVE, True),
        ("Antigravity Disabled (~/.gemini/skills-disabled)", GEMINI_DISABLED, False)
    ]
    for loc_name, path, is_active in locations:
        if not os.path.isdir(path):
            continue
        try:
            entries = sorted(os.listdir(path))
        except Exception:
            entries = []
        for e in entries:
            full = os.path.join(path, e)
            if os.path.isdir(full) and not e.startswith("."):
                meta = parse_frontmatter(full)
                size_str, count = get_dir_size(full)
                git_url = get_git_info(full)
                results.append({
                    "id": e,
                    "name": meta.get("name", e),
                    "description": meta.get("description", ""),
                    "version": meta.get("version", ""),
                    "location_name": loc_name,
                    "dir": full,
                    "is_active": is_active,
                    "is_universal": "agents" in path,
                    "size": size_str,
                    "files": count,
                    "git": git_url,
                    "valid": meta.get("valid", False)
                })
    return results

# ------------------------------------------------------------------------------
# Action: LIST / STATUS
# ------------------------------------------------------------------------------
def action_list():
    skills = scan_skills()
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                         STATUS AI AGENT SKILLS TERPASANG                               \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m")

    if not skills:
        print("  \033[33m(Belum ada AI Agent Skill yang terpasang di ~/.agents/skills atau ~/.gemini/skills)\033[0m")
        print("\n  \033[36mTip:\033[0m Pasang skill siap pakai dengan: \033[1maiskill presets\033[0m atau \033[1maiskill install <nama|url>\033[0m")
        return

    # Group by category
    categories = {}
    for s in skills:
        cat = s["location_name"]
        categories.setdefault(cat, []).append(s)

    for cat_name, cat_skills in categories.items():
        print(f"\n\033[1m{cat_name}:\033[0m")
        for s in cat_skills:
            status = "\033[32m[AKTIF]\033[0m" if s["is_active"] else "\033[33m[NONAKTIF]\033[0m"
            git_badge = " \033[35m[Git]\033[0m" if s["git"] else ""
            desc = s["description"]
            if len(desc) > 65:
                desc = desc[:62] + "..."
            print(f"  • {status} \033[1m{s['id']:<18}\033[0m ({s['size']}){git_badge}")
            print(f"      \033[2m{desc}\033[0m")

    active_count = sum(1 for s in skills if s["is_active"])
    disabled_count = len(skills) - active_count
    print(f"\n\033[1mRingkasan:\033[0m Total: \033[1m{len(skills)}\033[0m skill | Aktif: \033[32m{active_count}\033[0m | Nonaktif: \033[33m{disabled_count}\033[0m")

# ------------------------------------------------------------------------------
# Action: PRESETS
# ------------------------------------------------------------------------------
def action_presets():
    installed = {s["id"] for s in scan_skills()}
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                    KATALOG PRESET AI AGENT SKILLS POPULER                              \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m\n")

    for pid, p in PRESETS.items():
        is_inst = pid in installed
        status = "\033[32m[TERPASANG]\033[0m" if is_inst else "\033[36m[TERSEDIA]\033[0m"
        print(f"  • {status} \033[1m{pid:<18}\033[0m by @{p['author']}")
        print(f"      {p['desc']}")
        print(f"      \033[2mRepo: {p['url']}\033[0m\n")

    print("\033[1mCara Pasang:\033[0m")
    print("  aiskill install <preset-name>    (Contoh: \033[32maiskill install prompt-master\033[0m)")

# ------------------------------------------------------------------------------
# Action: INSTALL
# ------------------------------------------------------------------------------
def action_install(target_arg, dest_type="universal"):
    if not target_arg:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama preset atau URL Git repo.")
        sys.exit(1)

    repo_url = None
    skill_name = None

    # Check if preset
    if target_arg in PRESETS:
        repo_url = PRESETS[target_arg]["url"]
        skill_name = target_arg
    elif target_arg.startswith("http://") or target_arg.startswith("https://") or target_arg.startswith("git@"):
        repo_url = target_arg
        skill_name = os.path.basename(repo_url.rstrip("/")).replace(".git", "")
    elif "/" in target_arg and not os.path.exists(target_arg):
        # GitHub shorthand e.g. nidhinjs/prompt-master
        repo_url = f"https://github.com/{target_arg}.git"
        skill_name = target_arg.split("/")[-1]
    elif os.path.isdir(target_arg):
        # Local directory
        src_dir = os.path.abspath(target_arg)
        skill_name = os.path.basename(src_dir)
        dest_base = GEMINI_ACTIVE if dest_type == "gemini" else UNIVERSAL_ACTIVE
        dest_dir = os.path.join(dest_base, skill_name)
        if os.path.exists(dest_dir):
            print(f"\033[33m[WARN]\033[0m Skill '{skill_name}' sudah ada di {dest_dir}. Timpa? (y/N): ", end="", flush=True)
            conf = sys.stdin.readline().strip().lower()
            if conf != "y":
                print("Instalasi dibatalkan.")
                return
            shutil.rmtree(dest_dir)
        shutil.copytree(src_dir, dest_dir)
        print(f"\033[32m[OK]\033[0m Skill '{skill_name}' lokal berhasil dipasang ke {dest_dir}")
        return
    else:
        print(f"\033[31m[ERROR]\033[0m Preset atau URL Git '{target_arg}' tidak dikenali.")
        print("Ketik 'aiskill presets' untuk melihat daftar preset yang tersedia.")
        sys.exit(1)

    dest_base = GEMINI_ACTIVE if dest_type == "gemini" else UNIVERSAL_ACTIVE
    dest_dir = os.path.join(dest_base, skill_name)

    if os.path.exists(dest_dir):
        print(f"\033[33m[WARN]\033[0m Skill '{skill_name}' sudah terpasang di {dest_dir}.")
        print("Gunakan 'aiskill update " + skill_name + "' untuk memperbarui atau hapus dulu dengan 'aiskill remove " + skill_name + "'.")
        return

    print(f"\033[36m[INFO]\033[0m Mengunduh skill '{skill_name}' dari {repo_url}...")
    tmp_dest = os.path.join(HOME, ".agents", f"tmp-{skill_name}")
    if os.path.exists(tmp_dest):
        shutil.rmtree(tmp_dest)

    try:
        subprocess.check_call(["git", "clone", "--depth", "1", repo_url, tmp_dest])
    except subprocess.CalledProcessError as e:
        print(f"\033[31m[ERROR]\033[0m Gagal melakukan git clone: {e}")
        if os.path.exists(tmp_dest):
            shutil.rmtree(tmp_dest)
        sys.exit(1)

    # Validate SKILL.md
    meta = parse_frontmatter(tmp_dest)
    if not meta.get("file"):
        # Check subdirectories (some repos put skills in a subfolder)
        found_sub = None
        for root, dirs, files in os.walk(tmp_dest):
            for f in files:
                if f in ["SKILL.md", "skill.md"]:
                    found_sub = root
                    break
            if found_sub:
                break
        if found_sub and found_sub != tmp_dest:
            print(f"\033[36m[INFO]\033[0m SKILL.md ditemukan di subdirektori: {os.path.relpath(found_sub, tmp_dest)}")
            shutil.move(found_sub, dest_dir)
            shutil.rmtree(tmp_dest)
            meta = parse_frontmatter(dest_dir)
        else:
            print(f"\033[33m[WARN]\033[0m Peringatan: Tidak ditemukan file SKILL.md di repository.")
            shutil.move(tmp_dest, dest_dir)
    else:
        shutil.move(tmp_dest, dest_dir)

    print(f"\033[32m[OK]\033[0m Skill '\033[1m{skill_name}\033[0m' berhasil dipasang ke \033[36m{dest_dir}\033[0m!")
    meta = parse_frontmatter(dest_dir)
    if meta.get("description"):
        print(f"      Deskripsi: {meta['description']}")

# ------------------------------------------------------------------------------
# Action: REMOVE
# ------------------------------------------------------------------------------
def action_remove(skill_id):
    if not skill_id:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama skill yang ingin dihapus.")
        sys.exit(1)

    targets = [
        os.path.join(UNIVERSAL_ACTIVE, skill_id),
        os.path.join(UNIVERSAL_DISABLED, skill_id),
        os.path.join(GEMINI_ACTIVE, skill_id),
        os.path.join(GEMINI_DISABLED, skill_id)
    ]
    found = [p for p in targets if os.path.isdir(p)]

    if not found:
        print(f"\033[31m[ERROR]\033[0m Skill '{skill_id}' tidak ditemukan di sistem.")
        return

    for p in found:
        try:
            shutil.rmtree(p)
            print(f"\033[32m[OK]\033[0m Berhasil menghapus: {p}")
        except Exception as e:
            print(f"\033[31m[ERROR]\033[0m Gagal menghapus {p}: {e}")

# ------------------------------------------------------------------------------
# Action: ENABLE / DISABLE / TOGGLE
# ------------------------------------------------------------------------------
def action_toggle(skill_id, explicit_state=None):
    if not skill_id:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama skill.")
        sys.exit(1)

    # Check universal first, then gemini
    pairs = [
        (UNIVERSAL_ACTIVE, UNIVERSAL_DISABLED, "Universal"),
        (GEMINI_ACTIVE, GEMINI_DISABLED, "Antigravity")
    ]

    for act_dir, dis_dir, label in pairs:
        act_path = os.path.join(act_dir, skill_id)
        dis_path = os.path.join(dis_dir, skill_id)

        if os.path.isdir(act_path):
            if explicit_state == "enable":
                print(f"\033[33m[INFO]\033[0m Skill '{skill_id}' ({label}) sudah dalam status AKTIF.")
                return
            # Disable it
            os.makedirs(dis_dir, exist_ok=True)
            shutil.move(act_path, dis_path)
            print(f"\033[32m[OK]\033[0m Skill '\033[1m{skill_id}\033[0m' ({label}) dinonaktifkan (dipindahkan ke {dis_path}).")
            return
        elif os.path.isdir(dis_path):
            if explicit_state == "disable":
                print(f"\033[33m[INFO]\033[0m Skill '{skill_id}' ({label}) sudah dalam status NONAKTIF.")
                return
            # Enable it
            os.makedirs(act_dir, exist_ok=True)
            shutil.move(dis_path, act_path)
            print(f"\033[32m[OK]\033[0m Skill '\033[1m{skill_id}\033[0m' ({label}) diaktifkan (dipindahkan ke {act_path}).")
            return

    print(f"\033[31m[ERROR]\033[0m Skill '{skill_id}' tidak ditemukan.")

# ------------------------------------------------------------------------------
# Action: UPDATE
# ------------------------------------------------------------------------------
def action_update(skill_id=None):
    skills = scan_skills()
    if skill_id:
        skills = [s for s in skills if s["id"] == skill_id]
        if not skills:
            print(f"\033[31m[ERROR]\033[0m Skill '{skill_id}' tidak ditemukan.")
            return

    updated_count = 0
    for s in skills:
        if s["git"]:
            print(f"\033[36m[INFO]\033[0m Memperbarui skill '{s['id']}' via git pull...")
            try:
                out = subprocess.check_output(
                    ["git", "-C", s["dir"], "pull", "--ff-only"],
                    stderr=subprocess.STDOUT, text=True
                ).strip()
                print(f"  \033[32m->\033[0m {out}")
                updated_count += 1
            except subprocess.CalledProcessError as e:
                print(f"  \033[31m-> Gagal git pull: {e.output.strip()}\033[0m")
        else:
            if skill_id:
                print(f"\033[33m[WARN]\033[0m Skill '{s['id']}' bukan repository Git (instalasi manual).")

    if not skill_id:
        print(f"\n\033[32m[OK]\033[0m Selesai memeriksa pembaruan ({updated_count} skill berbasis Git diproses).")

# ------------------------------------------------------------------------------
# Action: INFO / INSPECT
# ------------------------------------------------------------------------------
def action_info(skill_id):
    if not skill_id:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama skill.")
        sys.exit(1)

    skills = [s for s in scan_skills() if s["id"] == skill_id]
    if not skills:
        print(f"\033[31m[ERROR]\033[0m Skill '{skill_id}' tidak ditemukan.")
        return

    s = skills[0]
    meta = parse_frontmatter(s["dir"])
    skill_file = meta.get("file")

    print("\033[1m\033[36m========================================================================================\033[0m")
    print(f"\033[1m                          DETAIL AI AGENT SKILL: {s['id'].upper()}                     \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m")
    print(f"  • Nama Asli       : \033[1m{meta.get('name', s['id'])}\033[0m")
    print(f"  • Status          : {'\033[32m[AKTIF]\033[0m' if s['is_active'] else '\033[33m[NONAKTIF]\033[0m'}")
    print(f"  • Cakupan         : {s['location_name']}")
    print(f"  • Lokasi Direktori: {s['dir']}")
    print(f"  • Ukuran Disk     : {s['size']} ({s['files']} file)")
    if s["git"]:
        print(f"  • Git Remote      : {s['git']}")
    print(f"  • Versi           : {meta.get('version', 'Tidak tercantum')}")
    print(f"  • Penulis/Author  : {meta.get('author', 'Tidak tercantum')}")
    print(f"  • Deskripsi       : {meta.get('description', '')}\n")

    if skill_file and os.path.exists(skill_file):
        print("\033[1mPratinjau Isi SKILL.md:\033[0m")
        print("\033[2m" + "-" * 70 + "\033[0m")
        try:
            with open(skill_file, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
            # Skip frontmatter
            in_fm = False
            preview_lines = []
            fm_count = 0
            for line in lines:
                if line.strip() == "---":
                    fm_count += 1
                    if fm_count == 2:
                        continue
                if fm_count >= 2:
                    preview_lines.append(line)
                    if len(preview_lines) >= 20:
                        break
            if preview_lines:
                print("".join(preview_lines).rstrip())
            else:
                print("  (File instruksi kosong)")
        except Exception as e:
            print(f"  (Error membaca file: {e})")
        print("\033[2m" + "-" * 70 + "\033[0m")

    # Check references and scripts
    ref_dir = os.path.join(s["dir"], "references")
    if os.path.isdir(ref_dir):
        refs = os.listdir(ref_dir)
        print(f"\n\033[1mFile Referensi ({len(refs)}): \033[0m" + ", ".join(refs[:5]) + ("..." if len(refs) > 5 else ""))

# ------------------------------------------------------------------------------
# Action: CREATE (Scaffold new skill)
# ------------------------------------------------------------------------------
def action_create(skill_name):
    if not skill_name:
        print("\033[31m[ERROR]\033[0m Harap masukkan nama skill baru (misal: my-automation).")
        sys.exit(1)

    skill_name = re.sub(r"[^a-zA-Z0-9_-]", "-", skill_name).lower()
    target_dir = os.path.join(UNIVERSAL_ACTIVE, skill_name)

    if os.path.exists(target_dir):
        print(f"\033[31m[ERROR]\033[0m Direktori skill '{skill_name}' sudah ada di {target_dir}.")
        return

    os.makedirs(target_dir, exist_ok=True)
    os.makedirs(os.path.join(target_dir, "references"), exist_ok=True)

    template = f"""---
name: {skill_name}
version: 1.0.0
description: Deskripsi singkat tentang fungsi dan peran skill {skill_name}. Jelaskan kapan AI harus memanggil skill ini.
---

# {skill_name.replace('-', ' ').title()} Skill

## Ringkasan Peran
Jelaskan aturan utama dan output yang diharapkan saat skill ini aktif.

## Aturan Utama (Hard Rules)
- Selalu patuhi standar format yang ditentukan.
- Hindari membuat asumsi tanpa memeriksa berkas terkait terlebih dahulu.

## Panduan Langkah demi Langkah
1. Analisis masukan dari pengguna.
2. Eksekusi alur kerja spesifik.
3. Berikan output yang terstruktur dan siap pakai.
"""

    with open(os.path.join(target_dir, "SKILL.md"), "w", encoding="utf-8") as f:
        f.write(template)

    print(f"\033[32m[OK]\033[0m Template skill '\033[1m{skill_name}\033[0m' berhasil dibuat!")
    print(f"      File utama: \033[36m{os.path.join(target_dir, 'SKILL.md')}\033[0m")
    print(f"      Folder referensi: \033[36m{os.path.join(target_dir, 'references')}\033[0m")
    print("      Silakan edit SKILL.md untuk mendefinisikan instruksi khusus AI Anda.")

# ------------------------------------------------------------------------------
# Action: DOCTOR / AUDIT
# ------------------------------------------------------------------------------
def action_doctor():
    skills = scan_skills()
    print("\033[1m\033[36m========================================================================================\033[0m")
    print("\033[1m                         AUDIT & DIAGNOSTIK KESEHATAN SKILL                             \033[0m")
    print("\033[1m\033[36m========================================================================================\033[0m\n")

    total = len(skills)
    passed = 0
    warnings = 0
    errors = 0

    seen_ids = {}

    for s in skills:
        skill_id = s["id"]
        meta = parse_frontmatter(s["dir"])
        issues = []

        # Check collision
        if skill_id in seen_ids:
            issues.append(f"Duplikat nama skill terdeteksi di {s['location_name']} dan {seen_ids[skill_id]}")
        else:
            seen_ids[skill_id] = s["location_name"]

        # Check SKILL.md existence
        if not meta.get("file"):
            issues.append("File SKILL.md tidak ditemukan di root direktori skill")
            errors += 1
        elif not meta.get("valid"):
            issues.append("YAML frontmatter di SKILL.md hilang atau formatnya tidak valid (perlu diawali '---')")
            errors += 1
        else:
            if not meta.get("description") or meta.get("description") == "(Tanpa deskripsi)":
                issues.append("Field 'description' kosong di YAML frontmatter")
                warnings += 1
            elif len(meta.get("description", "")) > 600:
                issues.append("Field 'description' terlalu panjang (> 600 karakter), boros context window")
                warnings += 1

        if not issues:
            print(f"  [\033[32mPASS\033[0m] \033[1m{skill_id:<20}\033[0m ({s['location_name']})")
            passed += 1
        else:
            status_tag = "\033[31mFAIL\033[0m" if any("tidak ditemukan" in i or "hilang" in i for i in issues) else "\033[33mWARN\033[0m"
            print(f"  [{status_tag}] \033[1m{skill_id:<20}\033[0m ({s['location_name']})")
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
elif cmd in ["install", "add"]:
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    dest = "gemini" if "--gemini" in sys.argv else "universal"
    action_install(target, dest)
elif cmd in ["remove", "rm", "del", "uninstall"]:
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_remove(target)
elif cmd == "enable":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_toggle(target, explicit_state="enable")
elif cmd == "disable":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_toggle(target, explicit_state="disable")
elif cmd == "toggle":
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_toggle(target)
elif cmd in ["update", "up"]:
    target = sys.argv[2] if len(sys.argv) > 2 else None
    action_update(target)
elif cmd in ["info", "show"]:
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_info(target)
elif cmd in ["create", "new"]:
    target = sys.argv[2] if len(sys.argv) > 2 else ""
    action_create(target)
elif cmd in ["doctor", "check", "audit"]:
    action_doctor()
else:
    print(f"\033[31m[ERROR]\033[0m Perintah '{cmd}' tidak dikenal.")
    sys.exit(1)
EOF
}

# ------------------------------------------------------------------------------
# Interactive Menu Wizard
# ------------------------------------------------------------------------------
interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        echo -e "${BOLD}${CYAN}=================================================="
        echo "      🧠 Termux AI Tools - AI Agent Skills       "
        echo -e "==================================================${RESET}"

        run_python_manager "status"
        echo ""
        echo -e "${BOLD}Pilihan Menu:${RESET}"
        echo -e "  ${GREEN}1)${RESET} 📋 Lihat Katalog Preset Populer (Prompt Master, Antislop, UI/UX)"
        echo -e "  ${GREEN}2)${RESET} ⚡ Pasang Skill dari Preset Populer"
        echo -e "  ${GREEN}3)${RESET} 🌐 Pasang Skill dari Git URL / GitHub Repo"
        echo -e "  ${CYAN}4)${RESET} 🔄 Toggle Aktifkan / Nonaktifkan Skill (Hemat Token)"
        echo -e "  ${CYAN}5)${RESET} 🚀 Perbarui Skill Terpasang (Git Pull Update)"
        echo -e "  ${CYAN}6)${RESET} 🔍 Detail & Pratinjau SKILL.md (Inspect)"
        echo -e "  ${CYAN}7)${RESET} ✨ Buat Template Skill Baru (Scaffold SKILL.md)"
        echo -e "  ${RED}8)${RESET} 🗑️ Hapus Skill Terpasang"
        echo -e "  ${YELLOW}9)${RESET} 🩺 Audit & Diagnostik Kesehatan Skill (Doctor)"
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
                echo -e "${BOLD}Pilih preset untuk dipasang:${RESET}"
                echo "  1) prompt-master   (Optimizer & generator prompt multi-AI)"
                echo "  2) antislop        (Pembersih fluff/boilerplate AI)"
                echo "  3) ui-ux-pro-max   (Design system, 192 palettes & UI intelligence)"
                echo "  4) banner-design   (Pembuat banner & visual kreatif)"
                echo "  5) code-review-graph (Knowledge graph code review)"
                echo "  0) Batal"
                echo ""
                read -r -p "Pilihan preset [0-5]: " p_choice
                case "$p_choice" in
                    1) run_python_manager "install" "prompt-master" ;;
                    2) run_python_manager "install" "antislop" ;;
                    3) run_python_manager "install" "ui-ux-pro-max" ;;
                    4) run_python_manager "install" "banner-design" ;;
                    5) run_python_manager "install" "code-review-graph" ;;
                    *) echo "Dibatalkan." ;;
                esac
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            3)
                echo ""
                read -r -p "Masukkan URL Git atau GitHub repo (contoh: nidhinjs/prompt-master): " git_input
                if [ -n "$git_input" ]; then
                    echo ""
                    run_python_manager "install" "$git_input"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            4)
                echo ""
                read -r -p "Masukkan nama skill yang ingin diaktifkan/dinonaktifkan: " tog_name
                if [ -n "$tog_name" ]; then
                    echo ""
                    run_python_manager "toggle" "$tog_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            5)
                echo ""
                read -r -p "Nama skill yang ingin diupdate (kosongkan untuk update semua): " up_name
                echo ""
                if [ -n "$up_name" ]; then
                    run_python_manager "update" "$up_name"
                else
                    run_python_manager "update"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            6)
                echo ""
                read -r -p "Masukkan nama skill yang ingin diperiksa: " inf_name
                if [ -n "$inf_name" ]; then
                    echo ""
                    run_python_manager "info" "$inf_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            7)
                echo ""
                read -r -p "Masukkan nama skill baru yang ingin dibuat (misal: my-automation): " new_name
                if [ -n "$new_name" ]; then
                    echo ""
                    run_python_manager "create" "$new_name"
                fi
                echo ""
                read -r -p "Tekan ENTER untuk kembali..." _
                ;;
            8)
                echo ""
                read -r -p "Masukkan nama skill yang ingin dihapus: " del_name
                if [ -n "$del_name" ]; then
                    read -r -p "Yakin ingin menghapus skill '$del_name'? (y/N): " conf_del
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
    install|add)
        shift
        run_python_manager "install" "$@"
        ;;
    remove|rm|del|uninstall)
        shift
        run_python_manager "remove" "$@"
        ;;
    enable)
        shift
        run_python_manager "enable" "$@"
        ;;
    disable)
        shift
        run_python_manager "disable" "$@"
        ;;
    toggle)
        shift
        run_python_manager "toggle" "$@"
        ;;
    update|up)
        shift
        run_python_manager "update" "$@"
        ;;
    info|show|inspect)
        shift
        run_python_manager "info" "$@"
        ;;
    create|new|init)
        shift
        run_python_manager "create" "$@"
        ;;
    doctor|check|audit)
        run_python_manager "doctor"
        ;;
    help|--help|-h)
        echo -e "${BOLD}${CYAN}Termux AI Tools - AI Agent Skill Manager Usage:${RESET}"
        echo "  aiskill                            Buka menu interaktif TUI"
        echo "  aiskill list                       Tampilkan daftar skill aktif & nonaktif"
        echo "  aiskill presets                    Lihat katalog skill populer siap pasang"
        echo "  aiskill install <nama|url>         Pasang skill dari preset, GitHub URL, atau lokal"
        echo "  aiskill toggle <nama>              Aktifkan/nonaktifkan skill untuk hemat token"
        echo "  aiskill enable <nama>              Aktifkan skill yang dinonaktifkan"
        echo "  aiskill disable <nama>             Nonaktifkan skill tanpa menghapus berkas"
        echo "  aiskill update [nama]              Perbarui skill berbasis Git (git pull)"
        echo "  aiskill info <nama>                Tampilkan detail metadata & pratinjau SKILL.md"
        echo "  aiskill create <nama>              Buat template skill baru (scaffold SKILL.md)"
        echo "  aiskill remove <nama>              Hapus skill dari sistem"
        echo "  aiskill doctor                     Audit kepatuhan format & integritas skill"
        exit 0
        ;;
    *)
        interactive_menu
        ;;
esac

#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==============================================================================
# Comprehensive Test Suite for Multi-Account & Quota Manager
# Repository: https://github.com/ngewa/termux-ai-tools
# ==============================================================================

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCOUNT_BIN="$TOOLS_DIR/account.sh"
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
echo "    🧪 Testing Suite: Multi-Account & Quota Mgr   "
echo -e "==================================================${RESET}\n"

# 1. Verifikasi File & Eksekusi
echo -e "${BOLD}1. Verifikasi File & Hak Akses:${RESET}"
assert_success "account.sh dapat dieksekusi" test -x "$ACCOUNT_BIN"
assert_success "account-manager.sh dapat dieksekusi" test -x "$TOOLS_DIR/bin/account-manager.sh"

# 2. Status & Profil Awal
echo -e "\n${BOLD}2. Pemeriksaan Status & Registri Profil:${RESET}"
assert_output_contains "account.sh list menampilkan header registri" "REGISTRY MULTI-ACCOUNT" bash "$ACCOUNT_BIN" list
assert_output_contains "account.sh current menampilkan profil aktif" "Detail Profil Aktif" bash "$ACCOUNT_BIN" current

BASE_PROF=$(python3 -c "import json, os; p=os.path.expanduser('~/.config/termux-ai/accounts.json'); print(json.load(open(p)).get('active_profile', 'default') if os.path.exists(p) else 'default')" 2>/dev/null || echo "default")

# 3. Pembuatan Profil Baru (Work & Testing)
echo -e "\n${BOLD}3. Pembuatan Multi-Account Profil Baru:${RESET}"
assert_success "Tambah profil qa-test" bash "$ACCOUNT_BIN" add qa-test "Akun Testing QA"
assert_output_contains "Profil qa-test terdaftar di list" "qa-test" bash "$ACCOUNT_BIN" list
assert_success "Simpan API key google ke qa-test" bash "$ACCOUNT_BIN" set-key qa-test google "AIzaSyTestMockKey999" "google/gemini-2.5-flash" all
assert_output_contains "Info profil qa-test memiliki provider google" "google" bash "$ACCOUNT_BIN" info qa-test
assert_output_contains "List menampilkan 1 provider pada qa-test" "1 provider" bash "$ACCOUNT_BIN" list

# 4. Pengalihan Akun (Account Switching)
echo -e "\n${BOLD}4. Pengalihan Akun Cepat (Account Switching):${RESET}"
assert_output_contains "Beralih ke profil qa-test" "Berhasil beralih ke profil: qa-test" bash "$ACCOUNT_BIN" switch qa-test
assert_output_contains "Profil aktif sekarang qa-test" "Profil Aktif : qa-test" bash "$ACCOUNT_BIN" list
assert_output_contains "Beralih kembali ke $BASE_PROF" "Berhasil beralih ke profil: $BASE_PROF" bash "$ACCOUNT_BIN" switch "$BASE_PROF"
assert_output_contains "Profil aktif kembali $BASE_PROF" "Profil Aktif : $BASE_PROF" bash "$ACCOUNT_BIN" list

# 5. Konfigurasi Failover Pool Rotasi
echo -e "\n${BOLD}5. Manajemen Failover Pool Rotasi:${RESET}"
assert_output_contains "Pool list menampilkan konfigurasi" "Konfigurasi Failover Pool" bash "$ACCOUNT_BIN" pool list
assert_success "Set urutan pool rotasi" bash "$ACCOUNT_BIN" pool set "$BASE_PROF,qa-test"
assert_output_contains "Pool berisi $BASE_PROF -> qa-test" "$BASE_PROF -> qa-test" bash "$ACCOUNT_BIN" pool list
assert_output_contains "List menandai qa-test dengan [POOL]" "[POOL]" bash "$ACCOUNT_BIN" list

# 6. Rotasi Akun Otomatis
echo -e "\n${BOLD}6. Rotasi Akun Otomatis (Quota Failover):${RESET}"
assert_output_contains "Rotasi dari $BASE_PROF ke qa-test" "Ke Profil   : qa-test" bash "$ACCOUNT_BIN" rotate
assert_output_contains "Profil aktif kini qa-test setelah rotasi" "Profil Aktif : qa-test" bash "$ACCOUNT_BIN" list
assert_output_contains "Rotasi balik ke $BASE_PROF" "Ke Profil   : $BASE_PROF" bash "$ACCOUNT_BIN" rotate
assert_output_contains "Profil aktif kembali $BASE_PROF" "Profil Aktif : $BASE_PROF" bash "$ACCOUNT_BIN" list

# 7. Pemantauan Kuota & Waktu Reset
echo -e "\n${BOLD}7. Pemantauan Kuota & Waktu Reset:${RESET}"
assert_output_contains "Quota monitor menampilkan reset harian" "Reset Kuota Harian" bash "$ACCOUNT_BIN" quota
assert_output_contains "Quota monitor mendeteksi profil $BASE_PROF" "Profil: $BASE_PROF" bash "$ACCOUNT_BIN" quota
assert_output_contains "Quota --all menampilkan semua profil" "Profil: qa-test" bash "$ACCOUNT_BIN" quota --all

# 8. Snapshot Kredensial Terenkripsi AES-256 + SHA256 Checksum
echo -e "\n${BOLD}8. Backup & Restore Kredensial Terenkripsi:${RESET}"
TEMP_BACKUP="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/test_accounts.enc"
rm -f "$TEMP_BACKUP"
assert_success "Backup enkripsi AES-256" bash "$ACCOUNT_BIN" backup "$TEMP_BACKUP" --password "TestPassPhrase2026!"
assert_success "File berkas backup .enc tercipta" test -f "$TEMP_BACKUP"
assert_output_contains "Restore snapshot terenkripsi sukses" "Berhasil memulihkan akun" bash "$ACCOUNT_BIN" restore "$TEMP_BACKUP" --password "TestPassPhrase2026!"
rm -f "$TEMP_BACKUP"

# 9. Integrasi Dispatcher 'ai account'
echo -e "\n${BOLD}9. Integrasi Perintah Global 'ai account':${RESET}"
assert_output_contains "ai account list berjalan via ai-launcher" "REGISTRY MULTI-ACCOUNT" bash "$AI_BIN" account list
assert_output_contains "ai account quota berjalan via ai-launcher" "PEMANTAUAN KUOTA" bash "$AI_BIN" account quota
assert_output_contains "ai account whoami berjalan via ai-launcher" "Detail Profil Aktif" bash "$AI_BIN" account whoami

# 10. Integrasi Antigravity-Swap (aswap)
echo -e "\n${BOLD}10. Integrasi Antigravity-Swap (aswap):${RESET}"
assert_success "aswap binary tersedia dan dapat dijalankan" command -v aswap
assert_output_contains "aswap list menampilkan akun Antigravity" "chraigmenholadi@gmail.com" aswap list
assert_output_contains "ai aswap list berjalan via ai-launcher" "chraigmenholadi@gmail.com" bash "$AI_BIN" aswap list
assert_output_contains "quota monitor menyertakan akun Google agy" "AKUN GOOGLE ANTIGRAVITY" bash "$ACCOUNT_BIN" quota

# 11. Pembersihan Profil Uji
echo -e "\n${BOLD}11. Pembersihan Profil Uji (Cleanup):${RESET}"
assert_success "Hapus profil qa-test" bash "$ACCOUNT_BIN" remove qa-test
assert_success "Reset pool rotasi ke default" bash "$ACCOUNT_BIN" pool set default

echo -e "\n${BOLD}${CYAN}=================================================="
echo "Total Pengujian: $((PASSED + FAILED))"
echo -e "  • ${GREEN}Lolos (Passed) : ${PASSED}${RESET}"
echo -e "  • ${RED}Gagal (Failed) : ${FAILED}${RESET}"
echo -e "==================================================${RESET}\n"

if [ "$FAILED" -eq 0 ]; then
    echo -e "${BOLD}${GREEN}🎉 Seluruh pengujian Multi-Account & Quota Manager berhasil 100%!${RESET}\n"
    exit 0
else
    echo -e "${BOLD}${RED}❌ Ada pengujian yang gagal! Silakan periksa output di atas.${RESET}\n"
    exit 1
fi

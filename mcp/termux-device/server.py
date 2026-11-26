#!/data/data/com.termux/files/usr/bin/python3
"""
Termux Device Bridge - Model Context Protocol (MCP) Server
Allows AI Coding Agents (OpenCode, Antigravity CLI) to interact natively with Android/Termux:
- termux_battery: Get battery level, status, temperature
- termux_clipboard: Read or write Android clipboard
- termux_notify: Send push notification to Android status bar
- termux_toast: Display popup toast on Android screen
- termux_vibrate: Vibrate Android phone on task completion
- termux_open_url: Open a web URL in the Android default browser
"""

import json
import os
import shutil
import signal
import subprocess
import sys
import time

SERVER_NAME = "termux-device"
SERVER_VERSION = "1.1.0"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
BRIDGE_JAR = os.path.join(BASE_DIR, "termux-device-bridge.jar")

_API_APP_CACHE = {"checked_at": 0.0, "installed": False}


def has_termux_api_app():
    now = time.monotonic()
    if now - _API_APP_CACHE["checked_at"] < 30.0:
        return _API_APP_CACHE["installed"]
    installed = False
    if os.path.exists("/system/bin/pm"):
        rc, out, _ = run_cmd_safe(["/system/bin/pm", "path", "com.termux.api"], timeout=2.0)
        installed = rc == 0 and "package:" in out
    _API_APP_CACHE["checked_at"] = now
    _API_APP_CACHE["installed"] = installed
    return installed


def run_cmd_safe(cmd, timeout=4.0, input_text=None, env_override=None):
    """Run a command isolated from MCP stdio pipes and kill the whole process group on timeout."""
    env = os.environ.copy()
    if env_override is not None:
        env.update(env_override)

    stdin_cfg = subprocess.PIPE if input_text is not None else subprocess.DEVNULL
    proc = subprocess.Popen(
        cmd,
        stdin=stdin_cfg,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        start_new_session=True,
    )
    try:
        out, err = proc.communicate(input=input_text, timeout=timeout)
        return proc.returncode, out or "", err or ""
    except subprocess.TimeoutExpired:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
        proc.communicate()
        raise


def run_native_bridge(subcommand, *args, timeout=4.0):
    if not os.path.isfile(BRIDGE_JAR):
        raise FileNotFoundError(f"Bridge DEX tidak ditemukan: {BRIDGE_JAR}")
    if os.access(BRIDGE_JAR, os.W_OK):
        try:
            os.chmod(BRIDGE_JAR, 0o400)
        except OSError:
            pass
    env = os.environ.copy()
    env.pop("LD_LIBRARY_PATH", None)
    env.pop("LD_PRELOAD", None)
    env["CLASSPATH"] = BRIDGE_JAR
    cmd = [
        "/system/bin/app_process",
        "-Xnoimage-dex2oat",
        "/",
        "com.termux.devicebridge.Bridge",
        subcommand,
        *[str(a) for a in args],
    ]
    return run_cmd_safe(cmd, timeout=timeout, env_override=env)


TOOLS = [
    {
        "name": "termux_battery",
        "description": "Dapatkan informasi persentase baterai, status charging, dan suhu perangkat Android.",
        "inputSchema": {
            "type": "object",
            "properties": {}
        }
    },
    {
        "name": "termux_clipboard",
        "description": "Baca atau salin teks ke clipboard Android.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "action": {
                    "type": "string",
                    "enum": ["get", "set"],
                    "description": "'get' untuk membaca clipboard saat ini, 'set' untuk menyalin teks baru"
                },
                "text": {
                    "type": "string",
                    "description": "Teks yang ingin disalin jika action='set'"
                }
            },
            "required": ["action"]
        }
    },
    {
        "name": "termux_notify",
        "description": "Kirim notifikasi ke status bar Android (berguna saat tugas panjang / build / review selesai).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Judul notifikasi"},
                "content": {"type": "string", "description": "Isi pesan notifikasi"},
                "sound": {"type": "boolean", "description": "Putar suara notifikasi sistem Android (default: true)"}
            },
            "required": ["title", "content"]
        }
    },
    {
        "name": "termux_toast",
        "description": "Tampilkan pesan toast singkat (pop-up) di layar HP Android.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "message": {"type": "string", "description": "Pesan yang ingin ditampilkan"}
            },
            "required": ["message"]
        }
    },
    {
        "name": "termux_vibrate",
        "description": "Getarkan HP Android selama beberapa milidetik sebagai penanda tugas coding selesai.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "duration_ms": {"type": "integer", "description": "Durasi getar dalam milidetik (default: 500)"}
            }
        }
    },
    {
        "name": "termux_open_url",
        "description": "Buka URL web di browser bawaan Android (Chrome / Firefox).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "url": {"type": "string", "description": "URL lengkap yang ingin dibuka (contoh: http://localhost:4097)"}
            },
            "required": ["url"]
        }
    }
]


def handle_battery():
    if has_termux_api_app() and shutil.which("termux-battery-status"):
        try:
            rc, out, _ = run_cmd_safe(["termux-battery-status"], timeout=3.5)
            if rc == 0 and out.strip():
                return out.strip()
        except Exception:
            pass
    try:
        cap = open("/sys/class/power_supply/battery/capacity").read().strip()
        stat = open("/sys/class/power_supply/battery/status").read().strip()
        info = {"percentage": int(cap), "status": stat, "source": "sysfs"}
        try:
            temp_raw = int(open("/sys/class/power_supply/battery/temp").read().strip())
            info["temperature"] = round(temp_raw / 10.0, 1)
        except Exception:
            pass
        return json.dumps(info)
    except Exception:
        return json.dumps({"status": "unknown", "note": "Gagal membaca status baterai."})


def handle_clipboard(action, text=""):
    if action == "get":
        if has_termux_api_app() and shutil.which("termux-clipboard-get"):
            try:
                rc, out, _ = run_cmd_safe(["termux-clipboard-get"], timeout=3.0)
                if rc == 0:
                    return out
            except Exception:
                pass
        try:
            rc, out, err = run_native_bridge("clipboard-get", timeout=3.0)
            if rc == 0:
                return out
            return f"Error: {err.strip()}"
        except Exception as e:
            return f"Error: {e}"
    elif action == "set":
        if has_termux_api_app() and shutil.which("termux-clipboard-set"):
            try:
                rc, _, _ = run_cmd_safe(["termux-clipboard-set"], timeout=3.0, input_text=text)
                if rc == 0:
                    return f"Berhasil menyalin {len(text)} karakter ke clipboard."
            except Exception:
                pass
        try:
            rc, _, err = run_native_bridge("clipboard-set", text, timeout=3.0)
            if rc == 0:
                return f"Berhasil menyalin {len(text)} karakter ke clipboard."
            return f"Error: {err.strip()}"
        except Exception as e:
            return f"Error: {e}"
    return "Action tidak valid."


def handle_notify(title, content, sound=True):
    if has_termux_api_app() and shutil.which("termux-notification"):
        try:
            cmd = ["termux-notification", "--title", title, "--content", content]
            if sound:
                cmd.append("--sound")
            rc, _, _ = run_cmd_safe(cmd, timeout=4.0)
            if rc == 0:
                return "Notifikasi terkirim ke status bar Android."
        except Exception:
            pass

    try:
        rc, _, err = run_native_bridge(
            "notify", title, content, "true" if sound else "false", "13370", timeout=4.0
        )
        if rc == 0:
            return "Notifikasi terkirim ke status bar Android."
        return f"Error: {err.strip()}"
    except Exception as e:
        return f"Error: {e}"


def handle_toast(message):
    if has_termux_api_app() and shutil.which("termux-toast"):
        try:
            rc, _, _ = run_cmd_safe(["termux-toast", message], timeout=3.5)
            if rc == 0:
                return "Toast ditampilkan di layar."
        except Exception:
            pass
    try:
        rc, _, err = run_native_bridge("toast", message, timeout=3.5)
        if rc == 0:
            return "Toast ditampilkan di layar."
        return f"Error: {err.strip()}"
    except Exception as e:
        return f"Error: {e}"


def handle_vibrate(duration_ms=500):
    duration_ms = max(1, min(int(duration_ms), 10000))
    timeout_sec = max(3.5, (duration_ms / 1000.0) + 2.5)
    if has_termux_api_app() and shutil.which("termux-vibrate"):
        try:
            rc, _, _ = run_cmd_safe(["termux-vibrate", "-d", str(duration_ms)], timeout=timeout_sec)
            if rc == 0:
                return f"Perangkat bergetar selama {duration_ms}ms."
        except Exception:
            pass
    try:
        rc, _, err = run_native_bridge("vibrate", str(duration_ms), timeout=timeout_sec)
        if rc == 0:
            return f"Perangkat bergetar selama {duration_ms}ms."
        return f"Error: {err.strip()}"
    except Exception as e:
        return f"Error: {e}"


def handle_open_url(url):
    for tool in ("termux-open-url", "termux-open"):
        if shutil.which(tool):
            try:
                rc, _, err = run_cmd_safe([tool, url], timeout=3.5)
                if rc == 0:
                    return f"Membuka URL di browser: {url}"
                return f"Error: {err.strip()}"
            except Exception as e:
                return f"Error: {e}"
    return "Tidak dapat menemukan handler termux-open-url."


def process_message(msg):
    method = msg.get("method")
    msg_id = msg.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": SERVER_NAME,
                    "version": SERVER_VERSION
                }
            }
        }
    elif method == "notifications/initialized":
        return None
    elif method == "ping":
        return {"jsonrpc": "2.0", "id": msg_id, "result": {}}
    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "tools": TOOLS
            }
        }
    elif method == "tools/call":
        params = msg.get("params", {})
        tool_name = params.get("name")
        args = params.get("arguments", {})

        result_text = ""
        if tool_name == "termux_battery":
            result_text = handle_battery()
        elif tool_name == "termux_clipboard":
            result_text = handle_clipboard(args.get("action", "get"), args.get("text", ""))
        elif tool_name == "termux_notify":
            result_text = handle_notify(
                args.get("title", "AI Notifikasi"),
                args.get("content", ""),
                args.get("sound", True),
            )
        elif tool_name == "termux_toast":
            result_text = handle_toast(args.get("message", ""))
        elif tool_name == "termux_vibrate":
            result_text = handle_vibrate(args.get("duration_ms", 500))
        elif tool_name == "termux_open_url":
            result_text = handle_open_url(args.get("url", ""))
        else:
            result_text = f"Tool '{tool_name}' tidak dikenal."

        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": str(result_text)
                    }
                ]
            }
        }
    else:
        if msg_id is not None:
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {
                    "code": -32601,
                    "message": f"Method '{method}' tidak didukung."
                }
            }
        return None


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
            resp = process_message(req)
            if resp is not None:
                sys.stdout.write(json.dumps(resp) + "\n")
                sys.stdout.flush()
        except Exception as e:
            err_resp = {
                "jsonrpc": "2.0",
                "id": None,
                "error": {
                    "code": -32700,
                    "message": f"Parse error: {e}"
                }
            }
            sys.stdout.write(json.dumps(err_resp) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()

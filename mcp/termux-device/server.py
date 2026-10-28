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

import sys
import json
import subprocess
import shutil

SERVER_NAME = "termux-device"
SERVER_VERSION = "1.0.0"

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
                "content": {"type": "string", "description": "Isi pesan notifikasi"}
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
    if shutil.which("termux-battery-status"):
        try:
            res = subprocess.run(["termux-battery-status"], capture_output=True, text=True, timeout=5)
            if res.returncode == 0:
                return res.stdout.strip()
        except Exception:
            pass
    # Fallback to sysfs
    try:
        cap = open("/sys/class/power_supply/battery/capacity").read().strip()
        stat = open("/sys/class/power_supply/battery/status").read().strip()
        return json.dumps({"percentage": int(cap), "status": stat, "source": "sysfs"})
    except Exception:
        return json.dumps({"status": "unknown", "note": "Install 'pkg install termux-api' untuk info baterai lengkap."})

def handle_clipboard(action, text=""):
    if action == "get":
        if shutil.which("termux-clipboard-get"):
            try:
                res = subprocess.run(["termux-clipboard-get"], capture_output=True, text=True, timeout=3)
                return res.stdout
            except Exception as e:
                return f"Error: {e}"
        return "Install 'pkg install termux-api' untuk membaca clipboard."
    elif action == "set":
        if shutil.which("termux-clipboard-set"):
            try:
                subprocess.run(["termux-clipboard-set"], input=text, text=True, timeout=3)
                return f"Berhasil menyalin {len(text)} karakter ke clipboard."
            except Exception as e:
                return f"Error: {e}"
        return "Install 'pkg install termux-api' untuk menulis clipboard."
    return "Action tidak valid."

def handle_notify(title, content):
    if shutil.which("termux-notification"):
        try:
            subprocess.run(["termux-notification", "--title", title, "--content", content], timeout=3)
            return "Notifikasi terkirim ke status bar Android."
        except Exception as e:
            return f"Error: {e}"
    # Fallback to toast
    if shutil.which("termux-toast"):
        try:
            subprocess.run(["termux-toast", f"{title}: {content}"], timeout=3)
            return "Notifikasi ditampilkan sebagai toast."
        except Exception:
            pass
    return f"[NOTIFY] {title}: {content}"

def handle_toast(message):
    if shutil.which("termux-toast"):
        try:
            subprocess.run(["termux-toast", message], timeout=3)
            return "Toast ditampilkan di layar."
        except Exception as e:
            return f"Error: {e}"
    return f"[TOAST] {message}"

def handle_vibrate(duration_ms=500):
    if shutil.which("termux-vibrate"):
        try:
            subprocess.run(["termux-vibrate", "-d", str(duration_ms)], timeout=3)
            return f"Perangkat bergetar selama {duration_ms}ms."
        except Exception as e:
            return f"Error: {e}"
    return "Perintah termux-vibrate tidak tersedia (instal via: pkg install termux-api)."

def handle_open_url(url):
    if shutil.which("termux-open-url"):
        try:
            subprocess.run(["termux-open-url", url], timeout=3)
            return f"Membuka URL di browser: {url}"
        except Exception as e:
            return f"Error: {e}"
    elif shutil.which("termux-open"):
        try:
            subprocess.run(["termux-open", url], timeout=3)
            return f"Membuka URL: {url}"
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
            result_text = handle_notify(args.get("title", "AI Notifikasi"), args.get("content", ""))
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

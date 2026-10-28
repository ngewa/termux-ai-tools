import { exec } from "child_process"

/**
 * Termux Notifier Plugin for OpenCode (v2 & v1 compatible)
 * Sends an Android status bar notification or toast when tasks complete or when user input is needed.
 */

function notify(title = "OpenCode Selesai", content = "Tugas coding telah selesai diproses.") {
  const cmd = `command -v termux-notification >/dev/null 2>&1 && termux-notification --title "${title}" --content "${content}" || termux-toast "OpenCode: Selesai"`
  exec(cmd, () => {})
}

export const TermuxNotifierPlugin = {
  id: "termux-notifier",
  setup(context: any) {
    if (context?.event?.subscribe) {
      ;(async () => {
        try {
          const events = context.event.subscribe({
            types: [
              "session.idle",
              "session.execution.succeeded",
              "session.execution.failed"
            ]
          })
          for await (const ev of events) {
            if (ev?.type === "session.execution.failed") {
              notify("OpenCode Error", "Terjadi kesalahan saat memproses tugas.")
            } else {
              notify("OpenCode Selesai", "Tugas coding telah selesai diproses.")
            }
          }
        } catch {
          // Stream closed or ignored
        }
      })()
    }
  }
}

export default TermuxNotifierPlugin

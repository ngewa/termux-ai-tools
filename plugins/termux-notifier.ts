import type { Plugin } from "@opencode-ai/plugin"

/**
 * Termux Notifier Plugin for OpenCode
 * Sends an Android status bar notification or toast when tasks complete or when user input is needed.
 */

export const TermuxNotifierPlugin: Plugin = async ({ $ }) => {
  return {
    "session.idle": async () => {
      try {
        await $`which termux-notification && termux-notification --title "OpenCode Selesai" --content "Tugas coding telah selesai diproses." || termux-toast "OpenCode: Selesai"`.quiet().nothrow()
      } catch {
        // Ignore if notification fails
      }
    }
  }
}

export default TermuxNotifierPlugin

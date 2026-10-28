import { execSync } from "child_process"

/**
 * RTK OpenCode plugin — rewrites commands to use rtk for token savings.
 * Compatible with OpenCode v2.
 * Requires: rtk in PATH.
 */
export const RtkOpenCodePlugin = {
  id: "rtk",
  setup(context: any) {
    if (context?.tool?.hook) {
      context.tool.hook("execute.before", async (event: any) => {
        const tool = String(event?.tool ?? "").toLowerCase()
        if (tool !== "bash" && tool !== "shell") return
        const input = event?.input
        if (!input || typeof input !== "object") return

        const command = input.command
        if (typeof command !== "string" || !command) return

        try {
          const rewritten = execSync(`rtk rewrite ${JSON.stringify(command)}`, {
            encoding: "utf-8",
            stdio: ["ignore", "pipe", "ignore"],
            timeout: 2000
          }).trim()

          if (rewritten && rewritten !== command) {
            input.command = rewritten
          }
        } catch {
          // rtk rewrite failed — pass through unchanged
        }
      })
    }
  }
}

export default RtkOpenCodePlugin

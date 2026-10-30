---
name: termux-ai-tools-dev
description: Developer guide, architecture reference, and quality assurance workflow for termux-ai-tools. Use whenever developing, modifying, debugging, testing, or extending scripts in the termux-ai-tools repository (e.g., ai-launcher, skill-manager, agent-manager, session-manager, doctor, config-helper, deb packaging, or updating Git repos). Always trigger when working on or adding features to termux-ai-tools.
---

# Termux AI Tools Developer & Maintenance Skill

Comprehensive guide for maintaining, extending, debugging, and testing **Termux AI Tools** (`termux-ai-tools`), the CLI ecosystem for running and orchestrating AI developer tools (OpenCode, Antigravity CLI, Agent Skills, Personas, Session History, and MCP Servers) on Android/Termux.

---

## 1. Project Architecture & Directory Layout

`termux-ai-tools` follows a modular hybrid architecture combining Bash launchers with embedded Python 3 management engines for complex data handling.

```
termux-ai-tools/
├── bin/
│   ├── ai-launcher.sh       # Main CLI dispatcher & interactive AI selector (`ai`)
│   ├── skill-manager.sh     # Agent Skills engine (~/.agents & ~/.gemini, Claude catalog)
│   ├── agent-manager.sh     # AI Subagents & Persona manager (Roblox, Toolkit, etc.)
│   ├── session-manager.sh   # Session database explorer, log viewer, history search
│   ├── memory-manager.sh    # Persistent SQLite Knowledge Brain memory manager
│   ├── plugin-installer.sh  # MCP server & plugin installer
│   ├── config-helper.sh     # API keys & default model configuration wizard
│   ├── doctor.sh            # System health diagnostics & environment auditor
│   ├── export-config.sh     # Configuration & OAuth tokens backup generator
│   └── restore-config.sh    # Restore configuration from backup archive
├── tests/
│   ├── test_skill.sh        # Automated test suite for skill-manager.sh
│   └── test_agent.sh        # Automated test suite for agent-manager.sh
├── skill.sh                 # Symlink target for `aiskill` -> bin/skill-manager.sh
├── agent.sh                 # Symlink target for `aiagent` -> bin/agent-manager.sh
├── session.sh               # Symlink target for `session.sh`
├── memory.sh                # Symlink target for `memory.sh`
├── doctor.sh                # Symlink target for `doctor.sh`
├── config.sh                # Symlink target for `config.sh`
├── update.sh                # Upstream Git sync & binary updater
├── build-deb.sh             # Debian (.deb) package builder
└── README.md                # User & command reference documentation
```

### Symlink Targets in `$PREFIX/bin`
During installation (`install.sh`), symlinks are registered into `$PREFIX/bin/`:
- `ai` -> `$HOME/termux-ai-tools/bin/ai-launcher.sh`
- `aiskill` -> `$HOME/termux-ai-tools/skill.sh`
- `aiagent` -> `$HOME/termux-ai-tools/agent.sh`
- `aidoc` -> `$HOME/termux-ai-tools/doctor.sh`

---

## 2. Termux & Android Execution Rules

When writing or executing code in Termux AI Tools, strictly adhere to these platform constraints:

1. **Path Conventions**:
   - Never hardcode `/usr/bin/` or standard Linux paths.
   - Use `$PREFIX` (`/data/data/com.termux/files/usr`) and `$HOME` (`/data/data/com.termux/files/home`).
   - Temporary directory: Standard `/tmp` does **not** exist or is read-only. Always use `$TMPDIR` or `$PREFIX/tmp`, or create temporary folders under `$HOME/.agents/tmp-...`.

2. **Sandbox & Permissions**:
   - The Termux environment uses `proot` or Android namespaces. Standard sandboxing with glibc linkers (`ld-linux-aarch64.so.1`) can fail unless unsandboxed execution is used where appropriate.
   - Always verify executable bits: `chmod +x <script.sh>`.

3. **Subprocess & Pipes**:
   - When calling python inside bash scripts, pass arguments cleanly via `python3 - "$@" << 'EOF'`.
   - Ensure interactive prompts (`input()`, `read -r -p`) check `sys.stdin.isatty()` or provide non-interactive fallbacks so automated scripts and test suites do not hang.

---

## 3. Extension Guidelines

### A. Modifying AI Quick Launcher (`bin/ai-launcher.sh`)
- Keep subcommand routing clean in the `case "$1" in` block.
- If a subcommand has a local script in `$TOOLS_DIR/`, prefer executing it locally; keep the `curl ... | bash` fallback for remote standalone execution.
- Maintain consistency between CLI direct execution (`ai <command>`) and the interactive menu (`interactive_menu`).

### B. Extending Skill Manager (`bin/skill-manager.sh`)
- **Agent Skill Format**: All skills must adhere to the open standard:
  ```markdown
  ---
  name: <skill-name>
  description: <When to trigger, what it does>
  ---
  # Instructions ...
  ```
- **Supported Skill Directory Locations**:
  - `~/.agents/skills/` (Universal active)
  - `~/.agents/skills-disabled/` (Universal inactive)
  - `~/.gemini/skills/` (Antigravity active)
  - `~/.gemini/skills-disabled/` (Antigravity inactive)
- **Claude Official Plugins (`CLAUDE_OFFICIAL_SKILLS`)**:
  - Filter rule: **Only include components with valid `SKILL.md`**. Pure MCP servers without instructions or desktop binary LSP wrappers must be excluded.
  - Download mechanism: Use Git sparse-checkout (`--depth 1 --filter=blob:none --no-checkout`) targeting the specific skill directory, with an HTTP Raw CDN fallback.

### C. Extending Subagents & Personas (`bin/agent-manager.sh`)
- Agent templates reside in `~/.config/opencode/agents/` and `~/.gemini/config/agents/`.
- Ensure prompts maintain clean role descriptions, tool grants, and safety rules.

---

## 4. Quality Assurance & Testing Workflow

**Rule**: Before pushing any changes to Git, always execute and pass the automated test suites.

### Running Test Suites
```bash
# Test AI Agent Skill Manager
bash ~/termux-ai-tools/tests/test_skill.sh

# Test AI Subagents Manager
bash ~/termux-ai-tools/tests/test_agent.sh
```

### Adding New Test Cases
When adding a new feature or command to `skill-manager.sh` or `agent-manager.sh`:
1. Open the corresponding test file in `tests/`.
2. Add an assertion using `assert_output_contains` or `assert_success`.
3. Verify that tests pass in both CLI and interactive dispatch forms.
4. Clean up any temporary files or test skills created during tests.

---

## 5. Git Commit & Release Protocol

1. **Check Status & Diffs**:
   ```bash
   cd ~/termux-ai-tools
   git status
   git diff
   ```

2. **Commit Convention**:
   Use semantic commit messages:
   - `feat(skill): ...` for new skill manager features
   - `feat(agent): ...` for persona / subagent additions
   - `fix(...): ...` for bug fixes
   - `test(...): ...` for new test cases
   - `docs(...): ...` for README and documentation updates

3. **Push to Remote**:
   ```bash
   git push origin main
   ```
   Verify that `git status` reports `Your branch is up to date with 'origin/main'`.

# Chill.nvim

**A custom Neovim setup built for speed, a Claude Code-native workflow, and machine learning projects.**

VS Code is powerful, but it runs on Electron: higher memory usage, more background
processes, a heavier environment. Chill.nvim takes the other route — Neovim + Lua,
tuned around three things:

- ⚡ **Fast** — quick startup, low resource usage, lazy-loaded plugins, mouse-free
- 🤖 **Claude Code friendly** — Claude lives inside the editor, pinned across tabs, anchored to the real project root
- 🧠 **ML friendly** — live conda/virtualenv switching for pyright, no restarts

---

## 📸 Screenshots

### 🤖 Claude Code Integration
AI-assisted development directly inside Neovim.

![Claude Code Integration](https://github.com/user-attachments/assets/c96beef5-6963-4dc6-8694-286768576738)

### 🏠 Project Dashboard
Launch into your projects with a clean dashboard featuring recent projects and quick actions.

![Project Dashboard](https://github.com/user-attachments/assets/a9a9aa1d-c237-4be7-888d-275cf02d3610)

### 💻 Coding Experience
A focused editing environment with clean splits, floating windows, and AI-powered workflows.

![Editor](https://github.com/user-attachments/assets/1f28516c-4d2e-4478-bc55-ae316ee507ec)

### 🔍 Fast File Search
Navigate large codebases instantly using fuzzy search.

![File Search](https://github.com/user-attachments/assets/1db06675-95c6-46f6-875e-01c29ba4a1c0)

### 📝 Git Diff Workflow
Review changes directly inside Neovim with a clean diff interface.

![Git Diff](https://github.com/user-attachments/assets/588947cf-254b-40c2-a417-46961f259699)

### ⌨️ Keymap Discovery
Find shortcuts quickly without leaving your editing workflow.

![Keymap Helper](https://github.com/user-attachments/assets/294eeab8-63aa-42ba-9be6-708e1056585e)

### 😴 Idle Screen Saver
A custom animation displayed when Neovim is idle.

![Screen Saver](https://github.com/user-attachments/assets/d0149bb7-2937-4ca2-b500-9342ade413ee)

---

## 🚀 Features

### 🤖 Claude Code, properly wired
The AI workflow is the reason this config exists, so it gets the careful parts:

- Claude opens in a terminal split **pinned identically across every tab** (`lua/core/pin.lua`)
- Its launch directory is anchored to the **project root**, not nvim's cwd — so
  session history never leaks between projects when auto-session restores a different `curdir`
- Send the visual selection straight to Claude with `>`
- All AI keymaps under `<leader>a`

### 🧠 Built for machine learning work
- **Interpreter picker** (`<leader>l`): detects conda envs, virtualenvs and system
  pythons, then repoints pyright at the chosen one *live* via
  `workspace/didChangeConfiguration` — no LSP restart, no reopening files
- `pyright` + `pylsp` together: fast type checking plus pycodestyle/mccabe linting
- Sane defaults for the long-file, wide-dataframe, many-notebook-adjacent reality of ML repos

### ⌨️ Keyboard-first workflow
Zero mouse dependency, a shortcut for everything, and which-key to discover it.
Keymaps follow a **subject → action** scheme:

| Prefix | Group |
| --- | --- |
| `<leader>a` | AI / Claude Code |
| `<leader>b` | Buffer (`bm` = move) |
| `<leader>e` | Explorer (Neo-tree) |
| `<leader>f` | Find (Telescope) |
| `<leader>g` | Git (`gd` diff, `gh` hunk, `gt` toggle) |
| `<leader>l` | LSP env — choose interpreter |
| `<leader>m` | Multicursor |
| `<leader>q` | Quit / Session |
| `<leader>t` | Tab |
| `<leader>u` | UI / Toggle |

### 🪟 Windows, buffers, terminals
Smart buffer switching, clean tab workflow, and **one shell terminal per tab**
that is reliably reused (`lua/core/terminal.lua`) — for git, builds, tests,
`pip`/`uv`, or anything else.

### 🎨 Minimal, theme-aware UI
A custom heirline statusline and winbar that build their palette **dynamically
from the active colorscheme**, so the bar always matches. `<leader>uc` lists every
installed theme (light and dark); `rose-pine-dawn` is the default, and kitty
opacity follows the light/dark choice automatically.

### 🔍 Search & Git
Telescope fuzzy finding across large projects, gitsigns for inline hunks, Neogit
for the full commit workflow, and side-by-side diffs without leaving the editor.

### 😴 Custom screen saver
When Neovim goes idle, it shows a custom animation instead of a static screen.

---

## 📦 Requirements

- Neovim **0.12+**
- A terminal with good key handling — **Kitty** is what this is tuned for
- `git`, `ripgrep`, `fd`
- `node` + `npm` (needed by `tree-sitter-cli` for the treesitter main branch)
- `wl-clipboard` (Wayland) for system clipboard
- [Claude Code CLI](https://claude.com/claude-code) for the AI workflow

---

## ⚡ Installation

```bash
# back up any existing config first
mv ~/.config/nvim ~/.config/nvim.bak

git clone https://github.com/sayidmabrur/chill-nvim ~/.config/nvim
nvim
```

lazy.nvim bootstraps itself on first launch and installs everything.

---

## 🗂️ Layout

```
init.lua              -- entry point: core, then lazy.nvim
lua/core/             -- options, keymaps, terminal, pinning, focus, autoreload
lua/config/           -- per-plugin config (lsp, heirline, alpha, cmp, telescope)
lua/config/lsp/       -- servers, diagnostics, keymaps, python_env (interpreter picker)
lua/config/heirline/  -- statusline + winbar components and layouts
lua/plugins/          -- one file per plugin spec
lua/milli/            -- splash art
```

---

## 🛠️ Philosophy

- Keep the editor fast
- Avoid unnecessary complexity
- Prefer keyboard workflows
- Make features discoverable
- Customize everything with Lua
- Build an environment that stays out of the way

Your editor should help you think, not slow you down.

---

## 📜 License

Copyright (c) All rights reserved.

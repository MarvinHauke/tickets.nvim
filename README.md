<!-- Badges -->
<div align="center">

# 🎫 tickets.nvim

**Manage your tasks and view GitHub issues directly within Neovim.**

[![CI](https://github.com/marvinhauke/tickets.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/marvinhauke/tickets.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docs](https://img.shields.io/badge/docs-website-blue.svg)](https://marvinhauke.github.io/tickets.nvim/)

[**Documentation**](https://marvinhauke.github.io/tickets.nvim/) • [**Features**](#-features) • [**Installation**](#-installation) • [**Usage**](#-usage)

</div>

---

## 📖 Documentation

For detailed information on installation, configuration, and advanced usage, check out the **[Official Documentation](https://marvinhauke.github.io/tickets.nvim/)**.

---

## 📋 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Usage](#-usage)
- [Configuration](#-configuration)
- [Contributing](#-contributing)
- [License](#-license)

## ✨ Features

**tickets.nvim** is designed to keep you in the flow by integrating task management and issue tracking directly into your editor.

### 📝 Local Task Management
*   **Instant Access**: Open your project's `TODO.md` in a centered floating window with `:Tickets`.
*   **Context Aware**: Keeps your task list attached to your current project context.
*   **Data Safety**: Prevents accidental closing of unsaved buffers.

### 🐙 GitHub Integration
*   **Auto-Detection**: Automatically detects the repository from your git remote.
*   **Issue Browser**: View open issues with `:TicketsGithubFetch`.
*   **Deep Dive**: Press `<Enter>` on an issue to view the full description, metadata, and comments.
*   **Performance**: Smart in-memory caching for instant subsequent loads.
*   **Flexible Auth**: Works seamlessly with the `gh` CLI or `GITHUB_TOKEN`.

## 📦 Installation

Install with your favorite package manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "marvinhauke/tickets.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  config = true, -- Runs require("tickets").setup()
}
```

## 🚀 Usage

| Command | Description |
|---------|-------------|
| `:Tickets` | Open or create the local `TODO.md` file in a floating window. |
| `:TicketsGithubFetch` | Fetch and list issues for the current repository (uses cache if available). |
| `:TicketsGithubRefresh` | Force fetch issues from GitHub, updating the cache. |
| `:TicketsCacheClear` | Clear the issue cache for the current or specified repository. |
| `:TicketsCacheStats` | Display statistics about the current issue cache. |

## ⚙️ Configuration

Get started with the default configuration:

```lua
require("tickets").setup({
  width_pct = 0.8,
  height_pct = 0.8,
  target_file = "TODO.md",
  storage_path = vim.fn.stdpath("data") .. "/tickets/cache.json",
})
```

For a comprehensive list of options, see the [Configuration Guide](https://marvinhauke.github.io/tickets.nvim/configuration/).

## 🤝 Contributing

Contributions are welcome! Please check the [Contributing Guide](docs/contributing.md) for details on how to get started.

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

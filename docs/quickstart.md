# Quick Start

Once installed, you can start using Tickets.nvim immediately.

## Requirements

To use the GitHub integration features:

1.  **Git Repository**: You must be inside a git repository with a remote named `origin` pointing to GitHub.
2.  **Authentication**:
    *   **gh CLI** (Recommended): Install and authenticate with `gh auth login`.
    *   **GITHUB_TOKEN**: Alternatively, set the `GITHUB_TOKEN` environment variable.

## Basic Setup

In your `init.lua` or plugin configuration file, call the setup function:

```lua
require("tickets").setup({
    target_file = "todo.md" -- Optional: Defaults to "todo.md"
})
```

## Commands

### Open Todo List

To open your designated todo file in a floating window:

```vim
:Tickets
```

*   Edit the file as normal.
*   Press `q` in Normal mode to close the window (only if saved).

### Fetch GitHub Issues

To fetch issues from the **current repository**:

```vim
:TicketsGithubFetch
```

The plugin will:
1.  Detect the repository from your git remote (`origin`).
2.  Check cache first; if cached, display instantly.
3.  Otherwise, fetch open issues using `gh` CLI or `curl` (fallback).
4.  Display them in a floating window.
5.  Notify you of the number of issues found (or if none exist).

### Additional GitHub Commands

```vim
:TicketsGithubRefresh      " Force refresh from API (bypass cache)
:TicketsCacheClear         " Clear all cached data
:TicketsCacheClear owner/repo  " Clear cache for specific repository
:TicketsCacheStats         " Show cache statistics
```

### Viewing Issue Details

When the issues list is open:

*   Press `<CR>` (Enter) on any issue to view full details including description, labels, assignees, and comments
*   Press `q` to close the detail view
*   Press `gx` to open the issue in your browser

## Configuration

You can pass options to the setup function:

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `target_file` | `string` | `"todo.md"` | The file path to open when running `:Tickets`. |

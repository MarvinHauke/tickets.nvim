# Quick Start

Once installed, you can start using Tickets.nvim immediately.

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

To fetch issues from the configured repository:

```vim
:TicketsGithubFetch
```

*(Note: Opens issues in a floating window. Press `q` to close.)*

## Configuration

You can pass options to the setup function:

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `target_file` | `string` | `"todo.md"` | The file path to open when running `:Tickets`. |

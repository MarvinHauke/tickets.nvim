# Configuration

Tickets.nvim can be customized through the `setup()` function. All configuration is optional and validated automatically.

## Basic Setup

```lua
require("tickets").setup({
    target_file = "todo.md"
})
```

## Full Configuration

Here's a complete configuration with all available options and their defaults:

```lua
require("tickets").setup({
    -- Path to your local todo file
    target_file = "todo.md",

    -- Background prefetching configuration
    prefetch = {
        enabled = true,           -- Enable/disable background prefetching
        delay = 500,              -- Milliseconds between fetches (100-5000)
        max_concurrent = 1,       -- Maximum concurrent fetches (1-5)
    },

    -- UI configuration
    ui = {
        -- Window layout settings
        window = {
            total_width_ratio = 0.9,    -- Total window width (0.5-1.0)
            total_height_ratio = 0.8,   -- Total window height (0.5-1.0)
            list_width_ratio = 0.35,    -- Issue list width ratio (0.1-0.9)
            detail_width_ratio = 0.65,  -- Detail pane width ratio (0.1-0.9)
            spacing = 2,                -- Spacing between windows (0-10)
        },
        -- Border style for floating windows
        -- Options: "none", "single", "double", "rounded", "solid", "shadow"
        border = "rounded",
    },
})
```

## Configuration Options

### `target_file`

**Type:** `string`
**Default:** `"todo.md"`

Path to your local todo file. Can be absolute or relative to your current working directory.

**Examples:**

```lua
-- Relative path
target_file = "todo.md"

-- Absolute path
target_file = vim.fn.expand("~/notes/todo.md")

-- Project-specific
target_file = ".todo.md"
```

### `prefetch`

**Type:** `table`

Controls background prefetching of issue details to improve performance.

#### `prefetch.enabled`

**Type:** `boolean`
**Default:** `true`

Enable or disable background prefetching. When enabled, issue details are fetched in the background after opening the issue list.

#### `prefetch.delay`

**Type:** `number`
**Range:** `100-5000`
**Default:** `500`

Milliseconds to wait between fetching each issue. Lower values fetch faster but may strain the API.

**Recommendations:**
- **Fast connection, few issues:** `200-300ms`
- **Balanced (default):** `500ms`
- **Slow connection, many issues:** `1000-2000ms`

#### `prefetch.max_concurrent`

**Type:** `number`
**Range:** `1-5`
**Default:** `1`

Maximum number of issues to fetch concurrently.

!!! warning
    Higher values may trigger GitHub API rate limiting. Use `1` unless you have specific needs.

### `ui`

**Type:** `table`

Controls the appearance and layout of floating windows.

#### `ui.window`

**Type:** `table`

Window sizing and layout configuration.

##### `ui.window.total_width_ratio`

**Type:** `number`
**Range:** `0.5-1.0`
**Default:** `0.9`

Total window area as a ratio of editor width (90% by default).

##### `ui.window.total_height_ratio`

**Type:** `number`
**Range:** `0.5-1.0`
**Default:** `0.8`

Total window area as a ratio of editor height (80% by default).

##### `ui.window.list_width_ratio`

**Type:** `number`
**Range:** `0.1-0.9`
**Default:** `0.35`

Issue list width as a ratio of total window width (35% by default).

##### `ui.window.detail_width_ratio`

**Type:** `number`
**Range:** `0.1-0.9`
**Default:** `0.65`

Detail pane width as a ratio of total window width (65% by default).

!!! note
    `list_width_ratio` + `detail_width_ratio` should approximately equal 1.0 for best layout.

##### `ui.window.spacing`

**Type:** `number`
**Range:** `0-10`
**Default:** `2`

Spacing in characters between the issue list and detail pane.

#### `ui.border`

**Type:** `string`
**Default:** `"rounded"`

Border style for floating windows.

**Options:**
- `"none"` - No border
- `"single"` - Single line border: `┌─┐│└┘`
- `"double"` - Double line border: `╔═╗║╚╝`
- `"rounded"` - Rounded corners: `╭─╮│╰╯`
- `"solid"` - Solid block border
- `"shadow"` - Drop shadow effect

## Validation

All configuration is automatically validated on setup. Invalid values will:

1. Display an error notification
2. List all validation errors
3. Prevent the plugin from loading

### Example Validation Error

```lua
-- Invalid configuration
require("tickets").setup({
    prefetch = {
        delay = 50,  -- Too low! Must be 100-5000
    }
})
```

**Error message:**
```
Tickets.nvim configuration errors:
Value for 'prefetch.delay' must be between 100 and 5000, got 50
```

## Advanced Examples

### Minimal Configuration

```lua
require("tickets").setup({
    target_file = "TODO.md"
})
```

### Performance Optimized

For repositories with many issues:

```lua
require("tickets").setup({
    prefetch = {
        delay = 200,           -- Faster prefetching
        max_concurrent = 2,    -- Fetch 2 at a time
    }
})
```

### Conservative API Usage

For slow connections or to minimize API calls:

```lua
require("tickets").setup({
    prefetch = {
        enabled = false,       -- Disable prefetching entirely
    }
})
```

### Custom Layout

Wider detail pane for reading long issue descriptions:

```lua
require("tickets").setup({
    ui = {
        window = {
            list_width_ratio = 0.25,    -- Narrower list
            detail_width_ratio = 0.75,  -- Wider details
        }
    }
})
```

### Full Screen Windows

Maximize screen usage:

```lua
require("tickets").setup({
    ui = {
        window = {
            total_width_ratio = 1.0,    -- Full width
            total_height_ratio = 1.0,   -- Full height
            spacing = 0,                -- No gap
        },
        border = "none",                -- No borders
    }
})
```

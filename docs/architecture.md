# Architecture

This document describes the internal architecture of Tickets.nvim.

## Module Overview

```
lua/tickets/
├── init.lua              Plugin entry point
├── config.lua            Configuration validation
├── commands.lua          User command registration
├── notifications.lua     Centralized messaging
├── cache.lua             In-memory caching
├── github.lua            GitHub API integration
├── utils.lua             Utility functions
├── ui.lua                Public UI API
└── ui/
    ├── config.lua        Window configuration
    ├── formatters.lua    Display formatting
    ├── issue_detail.lua  Detail preview logic
    ├── issue_list.lua    Issue list logic
    └── prefetch.lua      Background prefetching
```

## Module Responsibilities

### Core Modules

#### `init.lua` (16 lines)
**Purpose:** Plugin entry point

- Validates user configuration
- Initializes plugin modules
- Exposes public API

#### `config.lua` (211 lines)
**Purpose:** Configuration management

- Defines default configuration
- Validates user options
- Merges user config with defaults
- Provides helpful error messages

#### `commands.lua` (91 lines)
**Purpose:** Command registration

- Registers all user commands
- Sets up buffer keymaps
- Handles command callbacks

#### `notifications.lua` (108 lines)
**Purpose:** User messaging

- Centralizes all vim.notify calls
- Provides consistent message formatting
- Categorizes by type (INFO/WARN/ERROR)

### Data Modules

#### `cache.lua` (110 lines)
**Purpose:** In-memory caching

- Caches issue lists per repository
- Caches detailed issue data
- Provides cache statistics
- Supports cache invalidation

**Data Structure:**
```lua
{
  ["owner/repo"] = {
    issues = { ... },
    issue_details = {
      [123] = { ... },
      [456] = { ... }
    }
  }
}
```

#### `github.lua` (252 lines)
**Purpose:** GitHub API integration

- Authenticates with gh CLI or GITHUB_TOKEN
- Fetches issue lists
- Fetches detailed issue data with comments
- Handles API errors gracefully

**Features:**
- Automatic fallback from gh CLI to curl
- Forces keyring auth when GITHUB_TOKEN is invalid
- Caches all responses
- Async callbacks with vim.schedule

#### `utils.lua` (51 lines)
**Purpose:** Helper functions

- Path expansion (`~/path` → absolute path)
- Repository detection from git remote
- Buffer management utilities

### UI Modules

#### `ui.lua` (48 lines)
**Purpose:** Public UI API

Thin coordinator layer that exposes:
- `open_floating_file(path)` - Opens todo file
- `open_issues_window(issues)` - Opens issue list

#### `ui/config.lua` (102 lines)
**Purpose:** Window configuration

- Defines layout ratios and spacing
- Calculates window positions and sizes
- Creates window config objects
- Normalizes position values

**Functions:**
- `get_base_dimensions()` - Calculates centered window dimensions
- `create_list_window_config()` - Config for issue list
- `create_detail_window_config(list_win)` - Config for detail pane
- `create_file_window_config()` - Config for todo file

#### `ui/formatters.lua` (92 lines)
**Purpose:** Data formatting

- Formats timestamps for display
- Formats issue details as markdown
- Formats issue list entries

**Output:** Markdown-formatted text arrays for display

#### `ui/issue_list.lua` (137 lines)
**Purpose:** Issue list window

- Creates and manages issue list buffer
- Sets up keymaps (q, Enter, gx)
- Sets up autocmds (cursor movement, window close)
- Starts background prefetching
- Finds issue at cursor position

**Keymaps:**
- `q` - Close window and detail preview
- `<CR>` - Toggle detail preview
- `gx` - Open issue in browser

#### `ui/issue_detail.lua` (139 lines)
**Purpose:** Detail preview window

- Manages detail preview lifecycle
- Tracks currently viewed issue
- Handles async detail loading
- Updates preview on cursor move

**Features:**
- Issue number tracking (prevents redundant fetches)
- Synchronous cache check (instant display)
- Stale request detection
- Auto-cleanup on window close

#### `ui/prefetch.lua` (139 lines)
**Purpose:** Background prefetching

- Queue-based prefetching system
- Fetches uncached issues in background
- Configurable delay and concurrency
- Cancellable when window closes
- Progress tracking and notifications

## Data Flow

### Opening Issue List

```
User runs :TicketsGithubFetch
    ↓
commands.lua → github.fetch_issues()
    ↓
github.lua checks cache.get_issues()
    ↓
├─ Cache hit: Return cached issues immediately
└─ Cache miss: Fetch from API, cache, and return
    ↓
ui.open_issues_window(issues)
    ↓
issue_list.lua creates window and starts prefetch
    ↓
prefetch.lua queues uncached issues for background loading
```

### Viewing Issue Details

```
User presses <CR> on issue
    ↓
issue_list.lua → issue_detail.show_issue_detail_preview()
    ↓
issue_detail.lua checks if same issue (tracking)
    ↓
├─ Same issue: Skip (no-op)
└─ Different issue: Continue
    ↓
issue_detail.lua checks cache.get_issue_details()
    ↓
├─ Cache hit: Display instantly (synchronous)
└─ Cache miss: Show "Loading...", fetch from API
    ↓
formatters.format_issue_details() → Display
```

### Cursor Movement

```
CursorMoved event fires
    ↓
issue_list.lua autocmd callback
    ↓
Check if detail preview is open
    ↓
├─ No: Skip
└─ Yes: Continue
    ↓
Find issue at cursor position
    ↓
issue_detail.update_detail_preview(issue)
    ↓
Check if same issue number
    ↓
├─ Same: Skip (prevents redundant fetch)
└─ Different: Update preview (see "Viewing Issue Details" above)
```

## Performance Optimizations

### 1. Issue Number Tracking

**Problem:** CursorMoved fires on every cursor movement
**Solution:** Track last viewed issue number, skip if unchanged

```lua
local last_viewed_issue = {}

if last_viewed_issue[buf] == issue.number then
    return  -- Already viewing this issue
end
```

### 2. Synchronous Cache Check

**Problem:** Showing "Loading..." even for cached data
**Solution:** Check cache synchronously before async fetch

```lua
local cached = cache.get_issue_details(repo, issue_num)
if cached then
    display(cached)  -- Instant!
    return
end

-- Not cached, fetch async
fetch_from_api(...)
```

### 3. Background Prefetching

**Problem:** First view of each issue requires API call
**Solution:** Prefetch all uncached issues in background

```lua
-- Queue-based: fetches one at a time with delays
prefetch.start_prefetch(buf, repo, issues, {
    delay = 500,         -- 500ms between fetches
    max_concurrent = 1,  -- Don't overwhelm API
})
```

### 4. Stale Request Detection

**Problem:** Fast navigation causes old responses to overwrite new ones
**Solution:** Track expected issue, discard stale responses

```lua
-- After fetch completes
if last_viewed_issue[buf] ~= issue.number then
    return  -- User moved on, discard this response
end
```

## Extension Points

### Adding a New Command

1. Define command in `commands.lua`:
   ```lua
   vim.api.nvim_create_user_command("TicketsMyCommand", function()
       -- Implementation
   end, { desc = "Description" })
   ```

2. Add notification in `notifications.lua`:
   ```lua
   function M.my_command_success()
       vim.notify("Command succeeded!", INFO)
   end
   ```

### Adding UI Configuration

1. Add to defaults in `config.lua`:
   ```lua
   M.defaults = {
       ui = {
           my_option = "default_value"
       }
   }
   ```

2. Add validation in `config.validate()`:
   ```lua
   if config.ui.my_option ~= nil then
       validate_type(config.ui.my_option, "string", "ui.my_option")
   end
   ```

3. Use in `ui/config.lua`:
   ```lua
   local init = require("tickets")
   local my_value = init.config.ui.my_option
   ```

### Adding a New Data Source

1. Create module `lua/tickets/my_source.lua`
2. Implement `fetch_issues(callback)` function
3. Update `commands.lua` to support new source
4. Cache responses in `cache.lua`

## Testing Strategy

### Unit Tests (Recommended)

Each module can be tested independently:

```lua
-- Test config validation
local config = require("tickets.config")
local validated, errors = config.validate({ target_file = 123 })
assert(#errors > 0, "Should reject non-string target_file")
```

### Integration Tests

Test command → API → UI flow:

```lua
-- Mock GitHub API
local github = require("tickets.github")
github.fetch_issues = function(callback)
    callback({ { number = 1, title = "Test" } })
end

-- Test command
vim.cmd("TicketsGithubFetch")
-- Assert window opened, buffer created, etc.
```

## Debugging

### Enable Verbose Notifications

Modify `notifications.lua` to log all calls:

```lua
local function notify_with_log(msg, level)
    print("[TICKETS]", msg)  -- Log to :messages
    vim.notify(msg, level)
end
```

### Inspect Cache State

```lua
:lua print(vim.inspect(require("tickets.cache").stats()))
```

### Monitor Prefetch Queue

```lua
:lua print(vim.inspect(require("tickets.ui.prefetch").get_status(vim.api.nvim_get_current_buf())))
```

### Check Configuration

```lua
:lua print(vim.inspect(require("tickets").config))
```

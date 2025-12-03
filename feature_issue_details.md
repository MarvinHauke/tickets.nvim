# Feature Implementation: View Issue Details on <CR> (Enter)

This document outlines the architecture and step-by-step implementation plan for allowing users to press `<CR>` (Enter) on an issue in the main list to view its complete details (body, labels, assignees, and comments) in a floating window.

The implementation will be modular, separating data retrieval (API/Cache) from UI presentation.

---

## Architecture Overview

```
User presses <CR>
    ↓
lua/tickets/ui.lua (M.open_issues_window) - captures keypress
    ↓
lua/tickets/github.lua (M.fetch_issue_details) - fetches full issue data
    ↓
lua/tickets/ui.lua (M.open_issue_details) - renders detailed view
```

---

## 1. Data Structure

The GitHub API returns different structures for list vs. details. We'll work with the actual API response format.

### GitHub Issues API Response (List)

Already implemented in `fetch_issues_gh()`:
```lua
{
    number = 123,
    title = "Bug: Crashing when saving file",
    state = "open" or "closed",
    html_url = "https://github.com/user/repo/issues/123",
    user = { login = "username" },
    created_at = "2023-10-27T10:00:00Z",
    updated_at = "2023-10-27T10:05:00Z",
    assignees = { { login = "user_a" }, { login = "user_b" } },
    labels = {
        { name = "bug", color = "f03434" },
        { name = "priority:high", color = "ffc107" }
    },
    body = "Issue description (may be truncated in list view)"
}
```

### GitHub Issue Details API Response

For full details (including comments), we need two API calls:
1. `gh api repos/{repo}/issues/{number}` - full issue with body
2. `gh api repos/{repo}/issues/{number}/comments` - all comments

Combined structure:
```lua
{
    -- All fields from list view, plus:
    body = "Full markdown content of the issue description.",
    comments = {
        {
            user = { login = "commenter_user" },
            created_at = "2023-10-27T10:02:00Z",
            body = "I can reproduce this on Windows.",
            html_url = "https://github.com/user/repo/issues/123#issuecomment-456"
        }
    }
}
```

---

## 2. Implementation Steps

### Step 2.1: Modify `M.open_issues_window()` in `lua/tickets/ui.lua`

**Current state:** Lines 37-60 create a floating window with issue list formatted as `#123 Title`

**Required changes:**
1. Store the full `issues` table in the buffer for later retrieval
2. Add `<CR>` keymap to open details view

```lua
function M.open_issues_window(issues)
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {}

    for _, issue in ipairs(issues) do
        table.insert(lines, string.format("#%d %s", issue.number, issue.title))
    end

    if #lines == 0 then
        table.insert(lines, "No issues found.")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"

    -- NEW: Store issues data and repo in buffer variables
    vim.b[buf].tickets_issues = issues
    vim.b[buf].tickets_repo = require("tickets.utils").get_current_repo()

    local win = vim.api.nvim_open_win(buf, true, win_config())

    -- Existing keymap
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })

    -- NEW: Add <CR> keymap to open issue details
    vim.keymap.set("n", "<CR>", function()
        local line_num = vim.api.nvim_win_get_cursor(0)[1]
        local issue = issues[line_num]
        if issue then
            M.open_issue_details(issue, vim.b[buf].tickets_repo)
        end
    end, { buffer = buf, silent = true, desc = "View issue details" })
end
```

**Key decisions:**
- Use buffer-local variables (`vim.b[buf]`) to store context
- Parse issue by line number instead of regex (more reliable)
- Reuse existing `utils.get_current_repo()` for repo detection

---

### Step 2.2: Create `M.fetch_issue_details()` in `lua/tickets/github.lua`

**Location:** Add after `M.fetch_issues()` (after line 126)

This function fetches full issue details + comments using two parallel API calls.

```lua
-- Fetch full issue details including comments
-- @param repo string: "owner/repo"
-- @param issue_number number: Issue number
-- @param callback function: Called with (issue_with_comments) or (nil, error)
function M.fetch_issue_details(repo, issue_number, callback)
    if not is_gh_available() then
        vim.notify("gh CLI is required for fetching issue details", vim.log.levels.ERROR)
        return
    end

    local issue_url = "repos/" .. repo .. "/issues/" .. issue_number
    local comments_url = "repos/" .. repo .. "/issues/" .. issue_number .. "/comments"

    local issue_data = nil
    local comments_data = nil
    local issue_done = false
    local comments_done = false

    local function check_complete()
        if issue_done and comments_done then
            if issue_data and comments_data then
                issue_data.comments = comments_data
                vim.schedule(function()
                    callback(issue_data)
                end)
            else
                vim.schedule(function()
                    callback(nil, "Failed to fetch issue details")
                end)
            end
        end
    end

    -- Fetch issue details
    vim.fn.jobstart({ "gh", "api", issue_url }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                local output = table.concat(data, "\n")
                if output and output ~= "" then
                    local ok, result = pcall(vim.fn.json_decode, output)
                    if ok then
                        issue_data = result
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            issue_done = true
            if exit_code ~= 0 then
                issue_data = nil
            end
            check_complete()
        end,
    })

    -- Fetch comments
    vim.fn.jobstart({ "gh", "api", comments_url }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                local output = table.concat(data, "\n")
                if output and output ~= "" then
                    local ok, result = pcall(vim.fn.json_decode, output)
                    if ok then
                        comments_data = result
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            comments_done = true
            if exit_code ~= 0 then
                comments_data = {}  -- Empty array if comments fail
            end
            check_complete()
        end,
    })
end
```

**Key decisions:**
- Parallel API calls for better performance
- Graceful degradation if comments fail (show issue without comments)
- Reuse existing `is_gh_available()` check
- Follow existing error handling patterns from `fetch_issues_gh()`

---

### Step 2.3: Create `M.open_issue_details()` in `lua/tickets/ui.lua`

**Location:** Add after `M.open_issues_window()` (after line 60)

This function creates a larger floating window and formats the issue details.

```lua
-- Format a timestamp for display
local function format_timestamp(iso_time)
    if not iso_time then return "Unknown" end
    -- Simple format: "2023-10-27 10:00"
    return iso_time:match("(%d+-%d+-%d+T%d+:%d+)") or iso_time
end

-- Create a larger floating window for issue details
local function details_win_config()
    local width = math.floor(vim.o.columns * 0.8)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    return {
        relative = "editor",
        width = width,
        height = height,
        row = row,
        col = col,
        style = "minimal",
        border = "rounded",
    }
end

-- Open detailed view of a single issue
function M.open_issue_details(issue, repo)
    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_open_win(buf, true, details_win_config())

    -- Set buffer options
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"

    -- Show loading message
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading issue details..." })
    vim.bo[buf].modifiable = false

    -- Fetch full details
    require("tickets.github").fetch_issue_details(repo, issue.number, function(detailed_issue, err)
        if err or not detailed_issue then
            vim.schedule(function()
                vim.notify("Failed to fetch issue details: " .. (err or "unknown error"), vim.log.levels.ERROR)
                vim.api.nvim_win_close(win, true)
            end)
            return
        end

        -- Format the content
        local lines = {}

        -- Header
        table.insert(lines, "# " .. detailed_issue.title)
        table.insert(lines, "")
        table.insert(lines, string.format("**Issue #%d** • %s", detailed_issue.number, detailed_issue.state))
        table.insert(lines, string.format("**Author:** @%s", detailed_issue.user.login))
        table.insert(lines, string.format("**Created:** %s", format_timestamp(detailed_issue.created_at)))
        table.insert(lines, string.format("**Updated:** %s", format_timestamp(detailed_issue.updated_at)))

        -- Labels
        if detailed_issue.labels and #detailed_issue.labels > 0 then
            local label_names = {}
            for _, label in ipairs(detailed_issue.labels) do
                table.insert(label_names, label.name)
            end
            table.insert(lines, string.format("**Labels:** %s", table.concat(label_names, ", ")))
        end

        -- Assignees
        if detailed_issue.assignees and #detailed_issue.assignees > 0 then
            local assignee_names = {}
            for _, assignee in ipairs(detailed_issue.assignees) do
                table.insert(assignee_names, "@" .. assignee.login)
            end
            table.insert(lines, string.format("**Assignees:** %s", table.concat(assignee_names, ", ")))
        end

        -- URL
        table.insert(lines, string.format("**URL:** %s", detailed_issue.html_url))
        table.insert(lines, "")
        table.insert(lines, "---")
        table.insert(lines, "")

        -- Body
        if detailed_issue.body and detailed_issue.body ~= "" then
            for line in detailed_issue.body:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
        else
            table.insert(lines, "*No description provided.*")
        end

        -- Comments
        if detailed_issue.comments and #detailed_issue.comments > 0 then
            table.insert(lines, "")
            table.insert(lines, "---")
            table.insert(lines, "")
            table.insert(lines, string.format("## Comments (%d)", #detailed_issue.comments))
            table.insert(lines, "")

            for _, comment in ipairs(detailed_issue.comments) do
                table.insert(lines, string.format("### @%s • %s",
                    comment.user.login,
                    format_timestamp(comment.created_at)))
                table.insert(lines, "")
                for line in comment.body:gmatch("[^\n]+") do
                    table.insert(lines, line)
                end
                table.insert(lines, "")
                table.insert(lines, "---")
                table.insert(lines, "")
            end
        end

        -- Update buffer content
        vim.schedule(function()
            vim.bo[buf].modifiable = true
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].modifiable = false

            -- Store issue URL for gx mapping
            vim.b[buf].tickets_issue_url = detailed_issue.html_url

            -- Keymaps
            vim.keymap.set("n", "q", function()
                vim.api.nvim_win_close(win, true)
            end, { buffer = buf, silent = true, desc = "Close details" })

            vim.keymap.set("n", "gx", function()
                local url = vim.b[buf].tickets_issue_url
                if url then
                    vim.fn.jobstart({ "open", url }, { detach = true })
                end
            end, { buffer = buf, silent = true, desc = "Open in browser" })
        end)
    end)
end
```

**Key decisions:**
- 80% screen size for comfortable reading
- Loading state before async fetch completes
- Markdown formatting for consistency with existing `filetype = "markdown"`
- Handle missing/empty fields gracefully
- `gx` mapping uses `open` command (works on macOS, may need adjustment for Linux/Windows)
- Store URL in buffer variable for keymap access

---

## 3. Optional Enhancements (Future Work)

### 3.1 Caching
Add simple in-memory cache to avoid refetching same issue:

```lua
-- In lua/tickets/github.lua
local issue_cache = {}

function M.fetch_issue_details(repo, issue_number, callback)
    local cache_key = repo .. "#" .. issue_number

    -- Check cache first
    if issue_cache[cache_key] then
        vim.schedule(function()
            callback(issue_cache[cache_key])
        end)
        return
    end

    -- ... existing fetch logic ...
    -- On success, store in cache:
    issue_cache[cache_key] = issue_data
end
```

### 3.2 Cross-platform Browser Opening
Replace `open` command with cross-platform solution:

```lua
-- In lua/tickets/ui.lua
local function open_url(url)
    local cmd
    if vim.fn.has("mac") == 1 then
        cmd = { "open", url }
    elseif vim.fn.has("unix") == 1 then
        cmd = { "xdg-open", url }
    elseif vim.fn.has("win32") == 1 then
        cmd = { "cmd.exe", "/c", "start", url }
    else
        vim.notify("Unsupported platform for opening URLs", vim.log.levels.ERROR)
        return
    end
    vim.fn.jobstart(cmd, { detach = true })
end
```

### 3.3 Custom Highlight Groups
Define in `lua/tickets/init.lua` or separate `lua/tickets/highlights.lua`:

```lua
vim.api.nvim_set_hl(0, "TicketsStatusOpen", { fg = "#2ea043", bold = true })
vim.api.nvim_set_hl(0, "TicketsStatusClosed", { fg = "#8b949e", bold = true })
vim.api.nvim_set_hl(0, "TicketsCommentAuthor", { fg = "#58a6ff", bold = true })
vim.api.nvim_set_hl(0, "TicketsLabel", { fg = "#f78166" })
```

Then use `vim.api.nvim_buf_add_highlight()` when rendering content.

### 3.4 Fallback to cURL
Similar to `fetch_issues()`, support cURL when `gh` CLI is unavailable.

---

## 4. Implementation Checklist

Use this checklist to track progress:

- [ ] **Step 2.1:** Modify `M.open_issues_window()` in `lua/tickets/ui.lua`
  - [ ] Add buffer variables for `tickets_issues` and `tickets_repo`
  - [ ] Add `<CR>` keymap to call `M.open_issue_details()`

- [ ] **Step 2.2:** Create `M.fetch_issue_details()` in `lua/tickets/github.lua`
  - [ ] Implement parallel fetching of issue + comments
  - [ ] Add proper error handling
  - [ ] Test with issues that have 0, 1, and many comments

- [ ] **Step 2.3:** Create `M.open_issue_details()` in `lua/tickets/ui.lua`
  - [ ] Create `format_timestamp()` helper
  - [ ] Create `details_win_config()` helper
  - [ ] Implement main `M.open_issue_details()` function
  - [ ] Add loading state
  - [ ] Format metadata (title, status, author, labels, assignees)
  - [ ] Format body with line-by-line parsing
  - [ ] Format comments section
  - [ ] Add `q` and `gx` keymaps

- [ ] **Testing:**
  - [ ] Test with open/closed issues
  - [ ] Test with issues with no body
  - [ ] Test with issues with no comments
  - [ ] Test with issues with many comments (10+)
  - [ ] Test with issues containing markdown formatting
  - [ ] Test with issues containing code blocks
  - [ ] Test `gx` browser opening
  - [ ] Test window resizing behavior

- [ ] **Documentation:**
  - [ ] Update README with `<CR>` keymap documentation
  - [ ] Add screenshots/GIFs of the feature
  - [ ] Document `gx` and `q` keymaps

---

## 5. Testing Commands

```bash
# Manual testing steps:
1. Open Neovim in a git repository with GitHub remote
2. Run :TicketsGithubFetch
3. Press <CR> on any issue in the list
4. Verify:
   - Loading message appears briefly
   - Issue details render correctly
   - Comments are formatted properly
   - Press 'q' to close
   - Press <CR> again and press 'gx' to open in browser
```

---

## 6. Known Limitations & Future Work

1. **No caching:** Every `<CR>` press fetches from API (can be slow)
2. **macOS-only browser opening:** `open` command needs cross-platform support
3. **No syntax highlighting:** Comments/body are plain text (could use treesitter)
4. **No pagination:** Large comment threads load all at once
5. **No comment posting:** Read-only view (mentioned in original plan with `<C-a>`)
6. **No label colors:** Labels show name only, not GitHub's color badges

These can be addressed in follow-up PRs after core functionality is working.

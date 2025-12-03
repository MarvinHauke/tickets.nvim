-- Issue list window management
local M = {}

local config = require("tickets.ui.config")
local formatters = require("tickets.ui.formatters")
local issue_detail = require("tickets.ui.issue_detail")
local prefetch = require("tickets.ui.prefetch")

-- Find which issue line the cursor is on
-- @param buf number: Buffer handle
-- @param issues table: Array of issue objects
-- @return table|nil, number|nil: Issue object and cursor line number, or nil if not found
local function find_issue_at_cursor(buf, issues)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local current_line_text = all_lines[cursor_line]

    -- Check if we're on an issue title line (starts with #)
    local issue_num = current_line_text:match("^#(%d+)")

    if issue_num then
        -- Find the issue object
        for _, issue in ipairs(issues) do
            if issue.number == tonumber(issue_num) then
                return issue, cursor_line
            end
        end
    end

    return nil, nil
end

-- Setup keymaps for the issue list buffer
-- @param buf number: Buffer handle
-- @param win number: Window handle
-- @param issues table: Array of issue objects
-- @param repo string: Repository in "owner/repo" format
local function setup_keymaps(buf, win, issues, repo)
    -- Map `q` to close window
    vim.keymap.set("n", "q", function()
        issue_detail.close_detail_preview(buf)
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })

    -- Map <CR> to show issue details in side pane
    vim.keymap.set("n", "<CR>", function()
        local issue, _ = find_issue_at_cursor(buf, issues)
        issue_detail.show_issue_detail_preview(buf, issue, repo, win)
    end, { buffer = buf, silent = true, desc = "Show issue details" })

    -- Map gx to open issue URL in browser
    vim.keymap.set("n", "gx", function()
        local issue, _ = find_issue_at_cursor(buf, issues)
        if issue then
            local url = issue.html_url
            if url then
                vim.fn.jobstart({ "open", url }, { detach = true })
                vim.notify("Opening issue in browser...", vim.log.levels.INFO)
            end
        end
    end, { buffer = buf, silent = true, desc = "Open issue in browser" })
end

-- Setup autocmds for the issue list buffer
-- @param buf number: Buffer handle
-- @param issues table: Array of issue objects
-- @param repo string: Repository in "owner/repo" format
-- @param win number: Window handle
local function setup_autocmds(buf, issues, repo, win)
    -- Auto-update preview on cursor move
    -- No debouncing - issue tracking prevents redundant fetches
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = buf,
        callback = function()
            -- Only update if detail preview is open
            if not issue_detail.has_detail_preview(buf) then
                return
            end

            local issue, _ = find_issue_at_cursor(buf, issues)
            if issue then
                issue_detail.update_detail_preview(buf, issue, repo)
            end
        end,
    })

    -- Ensure detail window is closed when list window/buffer is closed
    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
        buffer = buf,
        callback = function()
            issue_detail.close_detail_preview(buf)
            prefetch.cancel_prefetch(buf)  -- Stop background prefetching
        end,
    })
end

-- Open a floating window with the GitHub issues list
-- @param issues table: Array of issue objects from GitHub API
-- @param repo string: Repository in "owner/repo" format
function M.open_issues_window(issues, repo)
    local buf = vim.api.nvim_create_buf(false, true) -- scratch buffer
    local lines = {}

    for _, issue in ipairs(issues) do
        table.insert(lines, formatters.format_issue_list_entry(issue))
    end

    if #lines == 0 then
        table.insert(lines, "No issues found.")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"

    -- Store issues data and repo in buffer variables for keymaps
    vim.b[buf].tickets_issues = issues
    vim.b[buf].tickets_repo = repo

    local win = vim.api.nvim_open_win(buf, true, config.create_list_window_config())

    setup_keymaps(buf, win, issues, repo)
    setup_autocmds(buf, issues, repo, win)

    -- Start background prefetching of issue details
    -- Delay: 500ms between fetches to keep UI responsive
    -- Only fetches 1 at a time to avoid overwhelming the API
    vim.schedule(function()
        prefetch.start_prefetch(buf, repo, issues, {
            delay = 500,           -- ms between fetches
            max_concurrent = 1,    -- fetch one at a time
        })
    end)
end

return M

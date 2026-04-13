-- Issue list window management
local M = {}

local config = require("tickets.ui.config")
local formatters = require("tickets.ui.formatters")
local issue_detail = require("tickets.ui.issue_detail")
local detail_mode = require("tickets.ui.detail_mode")
local prefetch = require("tickets.ui.prefetch")
local utils = require("tickets.utils")
local github = require("tickets.github")

-- Track current state per buffer for pagination and filtering
local buffer_state = {}

-- Extmark namespace for footer hint styling
local hint_ns = vim.api.nvim_create_namespace("tickets_hint")

-- Build display lines with header and footer hint
-- @param issues table: Array of issue objects
-- @param state string: "open" or "closed"
-- @param has_more boolean: Whether more pages are available
-- @return table: Array of display lines
local function build_lines(issues, state, has_more)
    local header = string.format("── %s Issues (%d) ──", state:sub(1, 1):upper() .. state:sub(2), #issues)
    local lines = { header, "" }

    for _, issue in ipairs(issues) do
        table.insert(lines, formatters.format_issue_list_entry(issue))
    end

    if #issues == 0 then
        table.insert(lines, "No " .. state .. " issues found.")
    end

    if has_more then
        table.insert(lines, "")
        table.insert(lines, "── Press L to load more ──")
    end

    -- Footer hints (multi-line for narrow windows)
    table.insert(lines, "")
    local hint_lines = formatters.format_hint_lines(state)
    for _, hint in ipairs(hint_lines) do
        table.insert(lines, hint)
    end

    return lines
end

-- Apply Comment highlight to the footer hint lines
local function style_hint_lines(buf)
    vim.api.nvim_buf_clear_namespace(buf, hint_ns, 0, -1)
    local line_count = vim.api.nvim_buf_line_count(buf)
    local hint_count = #formatters.format_hint_lines("open") -- number of hint lines
    for i = line_count - hint_count, line_count - 1 do
        if i >= 0 then
            vim.api.nvim_buf_set_extmark(buf, hint_ns, i, 0, {
                line_hl_group = "Comment",
            })
        end
    end
end

-- Find which issue line the cursor is on
-- @param buf number: Buffer handle
-- @param issues table: Array of issue objects
-- @return table|nil, number|nil
local function find_issue_at_cursor(buf, issues)
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local current_line_text = all_lines[cursor_line]

    local issue_num = current_line_text:match("^#(%d+)")
    if issue_num then
        for _, issue in ipairs(issues) do
            if issue.number == tonumber(issue_num) then
                return issue, cursor_line
            end
        end
    end

    return nil, nil
end

-- Get current issues for a buffer (from state or fallback)
local function get_issues(buf, fallback)
    local st = buffer_state[buf]
    return st and st.issues or fallback
end

-- Refresh the buffer content with current state
-- @param buf number: Buffer handle
local function refresh_buffer(buf)
    local st = buffer_state[buf]
    if not st then
        return
    end
    local lines = build_lines(st.issues, st.state, st.has_more)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    style_hint_lines(buf)
end

-- Setup keymaps for the issue list buffer
local function setup_keymaps(buf, win, issues, repo)
    -- q: close everything
    vim.keymap.set("n", "q", function()
        issue_detail.close_detail_preview(buf)
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })

    -- <CR>: toggle detail preview
    vim.keymap.set("n", "<CR>", function()
        local issue, _ = find_issue_at_cursor(buf, get_issues(buf, issues))
        issue_detail.show_issue_detail_preview(buf, issue, repo, win)
    end, { buffer = buf, silent = true, desc = "Show issue details" })

    -- gx: open in browser
    vim.keymap.set("n", "gx", function()
        local issue, _ = find_issue_at_cursor(buf, get_issues(buf, issues))
        if issue then
            local url = issue.html_url
            if url then
                utils.open_url(url)
                vim.notify("Opening issue in browser...", vim.log.levels.INFO)
            end
        end
    end, { buffer = buf, silent = true, desc = "Open issue in browser" })

    -- c: toggle issue state with confirmation
    vim.keymap.set("n", "c", function()
        local issue, _ = find_issue_at_cursor(buf, get_issues(buf, issues))
        if issue then
            local new_state = issue.state == "open" and "closed" or "open"
            local action = new_state == "closed" and "Close" or "Reopen"
            vim.ui.select({ "Yes", "No" }, {
                prompt = action .. " issue #" .. issue.number .. "?",
            }, function(choice)
                if choice == "Yes" then
                    vim.notify("Setting issue #" .. issue.number .. " to " .. new_state .. "...", vim.log.levels.INFO)
                    github.toggle_issue_state(repo, issue.number, new_state, function(success, err)
                        if success then
                            issue.state = new_state
                            vim.notify("Issue #" .. issue.number .. " " .. new_state, vim.log.levels.INFO)
                        else
                            vim.notify("Failed to update issue: " .. (err or "unknown error"), vim.log.levels.ERROR)
                        end
                    end)
                end
            end)
        end
    end, { buffer = buf, silent = true, desc = "Toggle issue state" })

    -- f: filter by state
    vim.keymap.set("n", "f", function()
        vim.ui.select({ "open", "closed" }, {
            prompt = "Show issues:",
        }, function(choice)
            if not choice then
                return
            end
            local st = buffer_state[buf]
            if st and st.state == choice then
                return
            end

            issue_detail.close_detail_preview(buf)

            if choice == "closed" then
                vim.notify("Fetching closed issues...", vim.log.levels.INFO)
                github.fetch_issues(function(closed_issues)
                    vim.schedule(function()
                        if not vim.api.nvim_buf_is_valid(buf) then
                            return
                        end
                        local has_more = #closed_issues >= 10
                        buffer_state[buf] = {
                            issues = closed_issues,
                            state = "closed",
                            page = 1,
                            has_more = has_more,
                            repo = repo,
                        }
                        refresh_buffer(buf)
                    end)
                end, true, { state = "closed", per_page = 10, page = 1 })
            else
                github.fetch_issues(function(open_issues)
                    vim.schedule(function()
                        if not vim.api.nvim_buf_is_valid(buf) then
                            return
                        end
                        buffer_state[buf] = {
                            issues = open_issues,
                            state = "open",
                            page = 1,
                            has_more = false,
                            repo = repo,
                        }
                        refresh_buffer(buf)
                        prefetch.cancel_prefetch(buf)
                        prefetch.start_prefetch(buf, repo, open_issues, {
                            delay = 500,
                            max_concurrent = 1,
                        })
                    end)
                end)
            end
        end)
    end, { buffer = buf, silent = true, desc = "Filter issues by state" })

    -- L: load more closed issues
    vim.keymap.set("n", "L", function()
        local st = buffer_state[buf]
        if not st or not st.has_more then
            vim.notify("No more issues to load", vim.log.levels.INFO)
            return
        end
        local next_page = st.page + 1
        vim.notify("Loading more closed issues...", vim.log.levels.INFO)
        github.fetch_issues(function(more_issues)
            vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(buf) then
                    return
                end
                for _, issue in ipairs(more_issues) do
                    table.insert(st.issues, issue)
                end
                st.page = next_page
                st.has_more = #more_issues >= 10
                refresh_buffer(buf)
            end)
        end, true, { state = "closed", per_page = 10, page = next_page })
    end, { buffer = buf, silent = true, desc = "Load more issues" })

    -- n: create new issue in detail pane
    vim.keymap.set("n", "n", function()
        issue_detail.enter_create_mode(buf, repo, win)
    end, { buffer = buf, silent = true, desc = "Create new issue" })

    -- e: edit issue in detail pane
    vim.keymap.set("n", "e", function()
        local issue, _ = find_issue_at_cursor(buf, get_issues(buf, issues))
        if issue then
            issue_detail.enter_edit_mode(buf, issue, repo, win)
        end
    end, { buffer = buf, silent = true, desc = "Edit issue" })

    -- C: comment on issue in detail pane
    vim.keymap.set("n", "C", function()
        local issue, _ = find_issue_at_cursor(buf, get_issues(buf, issues))
        if issue then
            issue_detail.enter_comment_mode(buf, issue, repo, win)
        end
    end, { buffer = buf, silent = true, desc = "Comment on issue" })
end

-- Setup autocmds for the issue list buffer
local function setup_autocmds(buf, issues, repo, win)
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = buf,
        callback = function()
            -- Only auto-update detail in view mode
            if not issue_detail.has_detail_preview(buf) then
                return
            end
            if detail_mode.is_active(buf) then
                return
            end

            local issue, _ = find_issue_at_cursor(buf, get_issues(buf, issues))
            if issue then
                issue_detail.update_detail_preview(buf, issue, repo)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
        buffer = buf,
        callback = function()
            issue_detail.close_detail_preview(buf)
            prefetch.cancel_prefetch(buf)
            buffer_state[buf] = nil
        end,
    })
end

-- Open a loading window immediately
function M.open_loading_window(repo)
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = {
        "Loading issues from " .. repo .. "...",
        "",
        "Please wait...",
    }

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"
    vim.b[buf].tickets_repo = repo

    local win = vim.api.nvim_open_win(buf, true, config.create_list_window_config())

    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })

    return buf, win
end

-- Update an existing window with fetched issues
function M.update_issues_window(buf, win, issues, repo)
    if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_win_is_valid(win) then
        M.open_issues_window(issues, repo)
        return
    end

    buffer_state[buf] = {
        issues = issues,
        state = "open",
        page = 1,
        has_more = false,
        repo = repo,
    }

    local lines = build_lines(issues, "open", false)

    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    style_hint_lines(buf)

    vim.b[buf].tickets_issues = issues

    setup_keymaps(buf, win, issues, repo)
    setup_autocmds(buf, issues, repo, win)

    vim.schedule(function()
        prefetch.start_prefetch(buf, repo, issues, {
            delay = 500,
            max_concurrent = 1,
        })
    end)
end

-- Open a floating window with the GitHub issues list
function M.open_issues_window(issues, repo)
    local buf = vim.api.nvim_create_buf(false, true)

    buffer_state[buf] = {
        issues = issues,
        state = "open",
        page = 1,
        has_more = false,
        repo = repo,
    }

    local lines = build_lines(issues, "open", false)

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"

    vim.b[buf].tickets_issues = issues
    vim.b[buf].tickets_repo = repo

    local win = vim.api.nvim_open_win(buf, true, config.create_list_window_config())
    style_hint_lines(buf)

    setup_keymaps(buf, win, issues, repo)
    setup_autocmds(buf, issues, repo, win)

    vim.schedule(function()
        prefetch.start_prefetch(buf, repo, issues, {
            delay = 500,
            max_concurrent = 1,
        })
    end)
end

return M

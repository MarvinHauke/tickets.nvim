local M = {}

local utils = require("tickets.utils")

local function win_config()
    -- List window takes up left portion (40% of available space)
    local total_width = math.floor(vim.o.columns * 0.9)
    local width = math.floor(total_width * 0.35)
    local height = math.floor(vim.o.lines * 0.8)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - total_width) / 2)

    return {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        border = "rounded",
    }
end

function M.open_floating_file(target_file)
    local expanded_path = utils.expand_path(target_file)

    -- Create the file if it doesn't exist
    if vim.fn.filereadable(expanded_path) == 0 then
        local file = io.open(expanded_path, "w")
        if file then
            file:close()
            vim.notify("Created new todo file at: " .. expanded_path, vim.log.levels.INFO)
        else
            vim.notify("Failed to create todo file at: " .. expanded_path, vim.log.levels.ERROR)
            return
        end
    end

    local buf = vim.fn.bufnr(expanded_path, true)
    if buf == -1 then
        buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, expanded_path)
    end

    vim.bo[buf].swapfile = false

    local win = vim.api.nvim_open_win(buf, true, win_config())
end

-- Track the detail preview window per list buffer
local detail_windows = {}

-- New function to open a floating window with the GitHub issues
function M.open_issues_window(issues)
    local buf = vim.api.nvim_create_buf(false, true) -- scratch buffer
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

    -- Store issues data and repo in buffer variables for <CR> keymap
    vim.b[buf].tickets_issues = issues
    vim.b[buf].tickets_repo = utils.get_current_repo()

    local win = vim.api.nvim_open_win(buf, true, win_config())

    -- Optional: map `q` to close window
    vim.keymap.set("n", "q", function()
        M.close_detail_preview(buf)
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })

    -- Map <CR> to show issue details in side pane
    vim.keymap.set("n", "<CR>", function()
        M.show_issue_detail_preview(buf, issues, win)
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

    -- Auto-update preview on cursor move
    vim.api.nvim_create_autocmd({ "CursorMoved" }, {
        buffer = buf,
        callback = function()
            if detail_windows[buf] and detail_windows[buf].auto_preview then
                M.update_detail_preview(buf, issues, win)
            end
        end,
    })

    -- Ensure detail window is closed when list window/buffer is closed
    vim.api.nvim_create_autocmd({ "BufWipeout", "WinClosed" }, {
        buffer = buf,
        callback = function()
            M.close_detail_preview(buf)
        end,
    })
end

-- Format a timestamp for display
local function format_timestamp(iso_time)
    if not iso_time then
        return "Unknown"
    end
    -- Simple format: "2023-10-27 10:00"
    return iso_time:match("(%d+-%d+-%d+T%d+:%d+)") or iso_time
end

-- Find which issue line the cursor is on
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

-- Calculate position for detail preview window (right side of list window)
local function detail_preview_config(list_win)
    local list_config = vim.api.nvim_win_get_config(list_win)
    local list_width = list_config.width
    local list_height = list_config.height

    -- Handle row/col which can be either a number or a table with [false] key
    local list_row = type(list_config.row) == "table" and list_config.row[false] or list_config.row
    local list_col = type(list_config.col) == "table" and list_config.col[false] or list_config.col

    -- Detail window takes up the remaining 65% of space
    local total_width = math.floor(vim.o.columns * 0.9)
    local detail_width = math.floor(total_width * 0.65) - 2
    local detail_height = list_height

    return {
        relative = "editor",
        width = detail_width,
        height = detail_height,
        row = list_row,
        col = list_col + list_width + 2,
        style = "minimal",
        border = "rounded",
    }
end

-- Format issue details as lines for preview pane
local function format_issue_details(detailed_issue)
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
            table.insert(lines, string.format("### @%s • %s", comment.user.login, format_timestamp(comment.created_at)))
            table.insert(lines, "")
            for line in comment.body:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
            table.insert(lines, "")
            table.insert(lines, "---")
            table.insert(lines, "")
        end
    end

    return lines
end

-- Close detail preview window
function M.close_detail_preview(list_buf)
    if detail_windows[list_buf] then
        local detail_info = detail_windows[list_buf]
        if detail_info.win and vim.api.nvim_win_is_valid(detail_info.win) then
            vim.api.nvim_win_close(detail_info.win, true)
        end
        if detail_info.buf and vim.api.nvim_buf_is_valid(detail_info.buf) then
            vim.api.nvim_buf_delete(detail_info.buf, { force = true })
        end
        detail_windows[list_buf] = nil
    end
end

-- Update detail preview with current issue
function M.update_detail_preview(list_buf, issues, list_win)
    local issue, _ = find_issue_at_cursor(list_buf, issues)
    if not issue then
        return
    end

    if not detail_windows[list_buf] then
        return
    end

    local detail_info = detail_windows[list_buf]
    local repo = vim.b[list_buf].tickets_repo

    -- Show loading in detail pane
    vim.bo[detail_info.buf].modifiable = true
    vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, { "Loading issue details..." })
    vim.bo[detail_info.buf].modifiable = false

    require("tickets.github").fetch_issue_details(repo, issue.number, function(detailed_issue, err)
        vim.schedule(function()
            -- Check if buffer is still valid before accessing it
            if not vim.api.nvim_buf_is_valid(detail_info.buf) then
                return
            end

            if err or not detailed_issue then
                vim.bo[detail_info.buf].modifiable = true
                vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, { "Error loading details: " .. (err or "unknown error") })
                vim.bo[detail_info.buf].modifiable = false
                return
            end

            local lines = format_issue_details(detailed_issue)
            vim.bo[detail_info.buf].modifiable = true
            vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, lines)
            vim.bo[detail_info.buf].modifiable = false
        end)
    end)
end

-- Show or toggle issue detail preview
function M.show_issue_detail_preview(list_buf, issues, list_win)
    local issue, _ = find_issue_at_cursor(list_buf, issues)
    if not issue then
        vim.notify("No issue found at cursor position", vim.log.levels.WARN)
        return
    end

    -- If detail window exists, close it (toggle behavior)
    if detail_windows[list_buf] then
        M.close_detail_preview(list_buf)
        return
    end

    -- Create detail preview window
    local detail_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[detail_buf].bufhidden = "wipe"
    vim.bo[detail_buf].filetype = "markdown"

    local detail_win = vim.api.nvim_open_win(detail_buf, false, detail_preview_config(list_win))

    -- Track this detail window
    detail_windows[list_buf] = {
        buf = detail_buf,
        win = detail_win,
        auto_preview = true,
    }

    -- Add keymaps to detail window
    vim.keymap.set("n", "q", function()
        M.close_detail_preview(list_buf)
    end, { buffer = detail_buf, silent = true, desc = "Close detail preview" })

    -- Load the details
    M.update_detail_preview(list_buf, issues, list_win)
end

return M

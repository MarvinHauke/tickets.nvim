-- Issue detail preview window management
local M = {}

local config = require("tickets.ui.config")
local formatters = require("tickets.ui.formatters")

-- Track the detail preview window per list buffer
local detail_windows = {}

-- Track the last viewed issue number per list buffer to prevent redundant fetches
local last_viewed_issue = {}

-- Close detail preview window
-- @param list_buf number: Buffer handle of the issue list
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
        last_viewed_issue[list_buf] = nil -- Clear tracking
    end
end

-- Update detail preview with current issue
-- @param list_buf number: Buffer handle of the issue list
-- @param issue table: Issue object to display
-- @param repo string: Repository in "owner/repo" format
function M.update_detail_preview(list_buf, issue, repo)
    if not detail_windows[list_buf] then
        return
    end

    -- Skip if we're already viewing this issue
    if last_viewed_issue[list_buf] == issue.number then
        return
    end

    -- Update tracking
    last_viewed_issue[list_buf] = issue.number

    local detail_info = detail_windows[list_buf]
    local cache = require("tickets.cache")

    -- Check cache first for instant display
    local cached_details = cache.get_issue_details(repo, issue.number)
    if cached_details then
        -- Instant display from cache
        local lines = formatters.format_issue_details(cached_details)
        vim.bo[detail_info.buf].modifiable = true
        vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, lines)
        vim.bo[detail_info.buf].modifiable = false
        return
    end

    -- Not in cache - show loading and fetch
    vim.bo[detail_info.buf].modifiable = true
    vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, { "Loading issue details..." })
    vim.bo[detail_info.buf].modifiable = false

    require("tickets.github").fetch_issue_details(repo, issue.number, function(detailed_issue, err)
        vim.schedule(function()
            -- Check if buffer is still valid before accessing it
            if not vim.api.nvim_buf_is_valid(detail_info.buf) then
                return
            end

            -- Check if user has moved to a different issue while we were loading
            if last_viewed_issue[list_buf] ~= issue.number then
                return -- Stale request, ignore
            end

            if err or not detailed_issue then
                vim.bo[detail_info.buf].modifiable = true
                vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, { "Error loading details: " .. (err or "unknown error") })
                vim.bo[detail_info.buf].modifiable = false
                return
            end

            local lines = formatters.format_issue_details(detailed_issue)
            vim.bo[detail_info.buf].modifiable = true
            vim.api.nvim_buf_set_lines(detail_info.buf, 0, -1, false, lines)
            vim.bo[detail_info.buf].modifiable = false
        end)
    end)
end

-- Show or toggle issue detail preview
-- @param list_buf number: Buffer handle of the issue list
-- @param issue table: Issue object to display
-- @param repo string: Repository in "owner/repo" format
-- @param list_win number: Window handle of the issue list
function M.show_issue_detail_preview(list_buf, issue, repo, list_win)
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

    local detail_win = vim.api.nvim_open_win(detail_buf, false, config.create_detail_window_config(list_win))

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
    M.update_detail_preview(list_buf, issue, repo)
end

-- Check if detail preview is open for a given list buffer
-- @param list_buf number: Buffer handle of the issue list
-- @return boolean: True if detail window exists
function M.has_detail_preview(list_buf)
    return detail_windows[list_buf] ~= nil
end

return M

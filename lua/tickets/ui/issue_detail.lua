-- Issue detail preview window management
local M = {}

local config = require("tickets.ui.config")
local detail_mode = require("tickets.ui.detail_mode")

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
        detail_mode.cleanup(list_buf)
        detail_windows[list_buf] = nil
        last_viewed_issue[list_buf] = nil
    end
end

-- Update detail preview with current issue (only in view mode)
-- @param list_buf number: Buffer handle of the issue list
-- @param issue table: Issue object to display
-- @param repo string: Repository in "owner/repo" format
function M.update_detail_preview(list_buf, issue, repo)
    if not detail_windows[list_buf] then
        return
    end

    -- Don't overwrite active edit/create/comment
    if detail_mode.is_active(list_buf) then
        return
    end

    -- Skip if already viewing this issue
    if last_viewed_issue[list_buf] == issue.number then
        return
    end

    last_viewed_issue[list_buf] = issue.number

    local detail_info = detail_windows[list_buf]
    detail_mode.enter_view_mode(list_buf, detail_info.buf, issue, repo)
end

-- Ensure detail window exists, creating it if needed
-- @param list_buf number
-- @param list_win number
-- @return table|nil: detail_info { buf, win }
local function ensure_detail_window(list_buf, list_win)
    if detail_windows[list_buf] then
        return detail_windows[list_buf]
    end

    local detail_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[detail_buf].bufhidden = "wipe"
    vim.bo[detail_buf].filetype = "markdown"

    local detail_win = vim.api.nvim_open_win(detail_buf, false, config.create_detail_window_config(list_win))

    detail_windows[list_buf] = {
        buf = detail_buf,
        win = detail_win,
    }

    -- q on detail buffer returns to list or closes detail
    vim.keymap.set("n", "q", function()
        if detail_mode.is_active(list_buf) then
            detail_mode.cancel_mode(list_buf, detail_buf)
            -- Return focus to list window
            if list_win and vim.api.nvim_win_is_valid(list_win) then
                vim.api.nvim_set_current_win(list_win)
            end
        else
            M.close_detail_preview(list_buf)
        end
    end, { buffer = detail_buf, silent = true, desc = "Close/cancel detail" })

    -- <leader>s on detail buffer submits current mode
    vim.keymap.set("n", "<leader>s", function()
        detail_mode.submit(list_buf, detail_buf, function()
            -- Return focus to list
            if list_win and vim.api.nvim_win_is_valid(list_win) then
                vim.api.nvim_set_current_win(list_win)
            end
        end)
    end, { buffer = detail_buf, silent = true, desc = "Submit" })

    return detail_windows[list_buf]
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

    -- If detail window exists and in view mode, close it (toggle)
    if detail_windows[list_buf] and not detail_mode.is_active(list_buf) then
        M.close_detail_preview(list_buf)
        return
    end

    local detail_info = ensure_detail_window(list_buf, list_win)
    if not detail_info then
        return
    end

    last_viewed_issue[list_buf] = nil -- force refresh
    detail_mode.enter_view_mode(list_buf, detail_info.buf, issue, repo)
end

-- Enter edit mode for an issue in the detail pane
-- @param list_buf number
-- @param issue table
-- @param repo string
-- @param list_win number
function M.enter_edit_mode(list_buf, issue, repo, list_win)
    local detail_info = ensure_detail_window(list_buf, list_win)
    if not detail_info then
        return
    end
    detail_mode.enter_edit_mode(list_buf, detail_info.buf, detail_info.win, issue, repo)
end

-- Enter create mode in the detail pane
-- @param list_buf number
-- @param repo string
-- @param list_win number
-- @param seed_text string|nil
function M.enter_create_mode(list_buf, repo, list_win, seed_text)
    local detail_info = ensure_detail_window(list_buf, list_win)
    if not detail_info then
        return
    end
    detail_mode.enter_create_mode(list_buf, detail_info.buf, detail_info.win, repo, seed_text)
end

-- Enter comment mode in the detail pane
-- @param list_buf number
-- @param issue table
-- @param repo string
-- @param list_win number
function M.enter_comment_mode(list_buf, issue, repo, list_win)
    local detail_info = ensure_detail_window(list_buf, list_win)
    if not detail_info then
        return
    end
    -- First ensure we're showing this issue's details
    if not detail_mode.is_active(list_buf) then
        last_viewed_issue[list_buf] = nil
        detail_mode.enter_view_mode(list_buf, detail_info.buf, issue, repo)
    end
    -- Then enter comment mode (view mode will have just set the content)
    -- Small delay to let view mode render before appending comment area
    vim.schedule(function()
        detail_mode.enter_comment_mode(list_buf, detail_info.buf, detail_info.win, issue, repo)
    end)
end

-- Check if detail preview is open for a given list buffer
-- @param list_buf number: Buffer handle of the issue list
-- @return boolean
function M.has_detail_preview(list_buf)
    return detail_windows[list_buf] ~= nil
end

return M

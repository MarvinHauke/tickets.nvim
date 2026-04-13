-- Detail pane mode manager
-- Modes: "view", "edit", "create", "comment"
local M = {}

local ns = vim.api.nvim_create_namespace("tickets_detail_signs")

-- Per-list-buffer mode state
-- { mode = "view"|"edit"|"create"|"comment", original_lines = {}, issue = {}, repo = "" }
local mode_state = {}

function M.get_mode(list_buf)
    local st = mode_state[list_buf]
    return st and st.mode or "view"
end

function M.is_active(list_buf)
    local mode = M.get_mode(list_buf)
    return mode == "edit" or mode == "create" or mode == "comment"
end

-- Guard: block mode entry if already in an active mode
local function guard(list_buf)
    if M.is_active(list_buf) then
        vim.notify("Finish current action first", vim.log.levels.WARN)
        return false
    end
    return true
end

-- Shared: update +/~ signs comparing current lines to original
function M.update_change_signs(buf, original_lines)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, line in ipairs(current_lines) do
        if i > #original_lines then
            if line ~= "" then
                vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
                    sign_text = "+",
                    sign_hl_group = "DiffAdd",
                })
            end
        elseif line ~= original_lines[i] then
            vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
                sign_text = "~",
                sign_hl_group = "DiffChange",
            })
        end
    end
end

-- Shared: update + signs for comment area (lines below separator)
local COMMENT_SEPARATOR = "── Write your comment below ──"

function M.update_comment_signs(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local past_separator = false
    for i, line in ipairs(lines) do
        if line == COMMENT_SEPARATOR then
            past_separator = true
        elseif past_separator and line ~= "" then
            vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
                sign_text = "+",
                sign_hl_group = "DiffAdd",
            })
        end
    end
end

-- Enter view mode (read-only issue details)
-- @param list_buf number
-- @param detail_buf number
-- @param issue table: issue object
-- @param repo string
function M.enter_view_mode(list_buf, detail_buf, issue, repo)
    local formatters = require("tickets.ui.formatters")
    local cache = require("tickets.cache")

    mode_state[list_buf] = { mode = "view", issue = issue, repo = repo }
    vim.api.nvim_buf_clear_namespace(detail_buf, ns, 0, -1)

    -- Check cache first
    local cached_details = cache.get_issue_details(repo, issue.number)
    if cached_details then
        local lines = formatters.format_issue_details(cached_details)
        vim.bo[detail_buf].modifiable = true
        vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
        vim.bo[detail_buf].modifiable = false
        return
    end

    -- Show loading, fetch async
    vim.bo[detail_buf].modifiable = true
    vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, { "Loading issue details..." })
    vim.bo[detail_buf].modifiable = false

    require("tickets.github").fetch_issue_details(repo, issue.number, function(detailed_issue, err)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(detail_buf) then
                return
            end
            -- Check if still viewing this issue
            local st = mode_state[list_buf]
            if not st or st.mode ~= "view" or (st.issue and st.issue.number ~= issue.number) then
                return
            end
            if err or not detailed_issue then
                vim.bo[detail_buf].modifiable = true
                vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, { "Error loading details: " .. (err or "unknown error") })
                vim.bo[detail_buf].modifiable = false
                return
            end
            local lines = formatters.format_issue_details(detailed_issue)
            vim.bo[detail_buf].modifiable = true
            vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
            vim.bo[detail_buf].modifiable = false
        end)
    end)
end

-- Enter edit mode (editable frontmatter + title + body)
-- @param list_buf number
-- @param detail_buf number
-- @param detail_win number
-- @param issue table
-- @param repo string
function M.enter_edit_mode(list_buf, detail_buf, detail_win, issue, repo)
    if not guard(list_buf) then
        return
    end

    local actions = require("tickets.actions")
    local lines = actions.build_edit_lines(issue)

    mode_state[list_buf] = {
        mode = "edit",
        issue = issue,
        repo = repo,
        original_lines = vim.list_extend({}, lines),
    }

    vim.bo[detail_buf].modifiable = true
    vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
    vim.api.nvim_set_current_win(detail_win)
    vim.api.nvim_win_set_cursor(detail_win, { 6, 2 }) -- cursor on title line

    -- Track changes with signs
    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = detail_buf,
        callback = function()
            local st = mode_state[list_buf]
            if st and st.mode == "edit" and st.original_lines then
                M.update_change_signs(detail_buf, st.original_lines)
            end
        end,
    })
end

-- Enter create mode (issue template)
-- @param list_buf number
-- @param detail_buf number
-- @param detail_win number
-- @param repo string
-- @param seed_text string|nil: optional pre-fill for body
function M.enter_create_mode(list_buf, detail_buf, detail_win, repo, seed_text)
    if not guard(list_buf) then
        return
    end

    local create = require("tickets.create")
    local lines = create.get_issue_template()

    -- Insert seed text into the body area if provided
    if seed_text and seed_text ~= "" then
        for i, line in ipairs(lines) do
            if line:match("Write your issue description here") then
                lines[i] = seed_text
                break
            end
        end
    end

    mode_state[list_buf] = {
        mode = "create",
        repo = repo,
        original_lines = vim.list_extend({}, lines),
    }

    vim.bo[detail_buf].modifiable = true
    vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, lines)
    vim.api.nvim_set_current_win(detail_win)
    vim.api.nvim_win_set_cursor(detail_win, { 6, 2 }) -- cursor on title line

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = detail_buf,
        callback = function()
            local st = mode_state[list_buf]
            if st and st.mode == "create" and st.original_lines then
                M.update_change_signs(detail_buf, st.original_lines)
            end
        end,
    })
end

-- Enter comment mode (append comment area to existing detail view)
-- @param list_buf number
-- @param detail_buf number
-- @param detail_win number
-- @param issue table
-- @param repo string
function M.enter_comment_mode(list_buf, detail_buf, detail_win, issue, repo)
    if not guard(list_buf) then
        return
    end

    mode_state[list_buf] = {
        mode = "comment",
        issue = issue,
        repo = repo,
    }

    vim.bo[detail_buf].modifiable = true
    local line_count = vim.api.nvim_buf_line_count(detail_buf)
    vim.api.nvim_buf_set_lines(detail_buf, line_count, -1, false, {
        "",
        COMMENT_SEPARATOR,
        "",
    })

    local new_count = vim.api.nvim_buf_line_count(detail_buf)
    vim.api.nvim_set_current_win(detail_win)
    vim.api.nvim_win_set_cursor(detail_win, { new_count, 0 })
    vim.cmd("startinsert")

    M.update_comment_signs(detail_buf)

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = detail_buf,
        callback = function()
            local st = mode_state[list_buf]
            if st and st.mode == "comment" then
                M.update_comment_signs(detail_buf)
            end
        end,
    })
end

-- Internal submit logic
local function do_submit(list_buf, detail_buf, refresh_callback)
    local st = mode_state[list_buf]
    if not st then
        return
    end

    local lines = vim.api.nvim_buf_get_lines(detail_buf, 0, -1, false)

    if st.mode == "edit" then
        local actions = require("tickets.actions")
        actions.submit_edit_from_lines(st.repo, st.issue.number, lines, function(success, err)
            if success then
                vim.notify("Issue #" .. st.issue.number .. " updated", vim.log.levels.INFO)
                M.cancel_mode(list_buf, detail_buf)
                if refresh_callback then
                    refresh_callback()
                end
            else
                vim.notify("Failed to update issue: " .. (err or "unknown error"), vim.log.levels.ERROR)
            end
        end)
    elseif st.mode == "create" then
        local create = require("tickets.create")
        local issue, parse_err = create.parse_issue_from_buffer(lines)
        if not issue then
            vim.notify("Error: " .. (parse_err or "Invalid issue format"), vim.log.levels.ERROR)
            return
        end
        vim.notify("Creating issue...", vim.log.levels.INFO)
        create.create_issue_gh(st.repo, issue, function(url, api_err)
            if api_err then
                vim.notify("Failed to create issue: " .. api_err, vim.log.levels.ERROR)
                return
            end
            vim.notify("Issue created: " .. url, vim.log.levels.INFO)
            local cache = require("tickets.cache")
            cache.invalidate(st.repo)
            M.cancel_mode(list_buf, detail_buf)
            if refresh_callback then
                refresh_callback()
            end
        end)
    elseif st.mode == "comment" then
        -- Extract comment text below separator
        local separator_line = nil
        for i, line in ipairs(lines) do
            if line == COMMENT_SEPARATOR then
                separator_line = i
                break
            end
        end
        if not separator_line then
            vim.notify("No comment area found", vim.log.levels.WARN)
            return
        end
        local comment_lines = {}
        for i = separator_line + 1, #lines do
            table.insert(comment_lines, lines[i])
        end
        local body = table.concat(comment_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
        if body == "" then
            vim.notify("Comment is empty", vim.log.levels.WARN)
            return
        end
        vim.notify("Posting comment on #" .. st.issue.number .. "...", vim.log.levels.INFO)
        local github = require("tickets.github")
        github.post_comment(st.repo, st.issue.number, body, function(success, err)
            if success then
                vim.notify("Comment posted on #" .. st.issue.number, vim.log.levels.INFO)
                local cache = require("tickets.cache")
                cache.invalidate_issue_details(st.repo, st.issue.number)
                M.cancel_mode(list_buf, detail_buf)
                -- Re-enter view mode to show the new comment
                if st.issue then
                    M.enter_view_mode(list_buf, detail_buf, st.issue, st.repo)
                end
            else
                vim.notify("Failed to post comment: " .. (err or "unknown error"), vim.log.levels.ERROR)
            end
        end)
    end
end

-- Submit based on current mode (with optional confirmation prompt)
-- @param list_buf number
-- @param detail_buf number
-- @param refresh_callback function
function M.submit(list_buf, detail_buf, refresh_callback)
    local st = mode_state[list_buf]
    if not st then
        return
    end

    local plugin = require("tickets")
    local opts = plugin.config or require("tickets.config").defaults

    if opts.confirm_submit then
        local action_name = st.mode == "edit" and "Submit edit"
            or st.mode == "create" and "Create issue"
            or st.mode == "comment" and "Post comment"
            or "Submit"
        vim.ui.select({ "Yes", "No" }, {
            prompt = action_name .. "?",
        }, function(choice)
            if choice == "Yes" then
                do_submit(list_buf, detail_buf, refresh_callback)
            end
        end)
    else
        do_submit(list_buf, detail_buf, refresh_callback)
    end
end

-- Cancel current mode, return to view
-- @param list_buf number
-- @param detail_buf number
function M.cancel_mode(list_buf, detail_buf)
    local st = mode_state[list_buf]
    if not st then
        return
    end

    vim.api.nvim_buf_clear_namespace(detail_buf, ns, 0, -1)
    vim.bo[detail_buf].modifiable = false
    mode_state[list_buf] = { mode = "view", issue = st.issue, repo = st.repo }
end

-- Clean up state for a list buffer
function M.cleanup(list_buf)
    mode_state[list_buf] = nil
end

return M

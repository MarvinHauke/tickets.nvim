-- Public UI module - thin coordinator for UI components
local M = {}

local utils = require("tickets.utils")
local config = require("tickets.ui.config")
local issue_list = require("tickets.ui.issue_list")

-- Open a floating window for editing a file (e.g., todo.md)
-- @param target_file string: Path to file to open
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

    local win = vim.api.nvim_open_win(buf, true, config.create_file_window_config())
end

-- Open a floating window with GitHub issues
-- @param issues table: Array of issue objects from GitHub API
function M.open_issues_window(issues)
    local repo = utils.get_current_repo()
    if not repo then
        vim.notify("Could not determine repository", vim.log.levels.ERROR)
        return
    end

    issue_list.open_issues_window(issues, repo)
end

-- Open a loading window immediately (before fetching data)
-- @return number, number, string: Buffer, window handles and repo name
function M.open_loading_window()
    local repo = utils.get_current_repo()
    if not repo then
        vim.notify("Could not determine repository", vim.log.levels.ERROR)
        return nil, nil, nil
    end

    local buf, win = issue_list.open_loading_window(repo)
    return buf, win, repo
end

-- Update a loading window with fetched issues
-- @param buf number: Buffer handle from open_loading_window
-- @param win number: Window handle from open_loading_window
-- @param issues table: Array of issue objects from GitHub API
-- @param repo string: Repository in "owner/repo" format
function M.update_issues_window(buf, win, issues, repo)
    issue_list.update_issues_window(buf, win, issues, repo)
end

-- Open the issue list+detail layout with the detail pane in create mode
-- @param seed_text string|nil: Optional text to pre-fill in the issue body
function M.open_with_create_mode(seed_text)
    local repo = utils.get_current_repo()
    if not repo then
        vim.notify("Could not determine repository", vim.log.levels.ERROR)
        return
    end

    local buf, win = issue_list.open_loading_window(repo)
    if not buf then
        return
    end

    local github = require("tickets.github")
    github.fetch_issues(function(issues)
        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(buf) then
                return
            end
            issue_list.update_issues_window(buf, win, issues, repo)
            -- Enter create mode in detail pane after list is ready
            local issue_detail = require("tickets.ui.issue_detail")
            issue_detail.enter_create_mode(buf, repo, win, seed_text)
        end)
    end)
end

return M

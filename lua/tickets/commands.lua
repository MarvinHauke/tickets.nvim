-- User command definitions and registration
local M = {}

local ui = require("tickets.ui")
local utils = require("tickets.utils")
local github = require("tickets.github")
local cache = require("tickets.cache")
local notify = require("tickets.notifications")
local create = require("tickets.create")

-- Register all user commands
-- @param opts table: Configuration options { target_file = "todo.md" }
function M.setup(opts)
    opts = opts or {}
    local target_file = opts.target_file or "todo.md"

    -- Open local todo file
    vim.api.nvim_create_user_command("Tickets", function()
        ui.open_floating_file(target_file)
    end, {
        desc = "Open todo file in floating window",
    })

    -- Fetch GitHub issues (uses cache)
    vim.api.nvim_create_user_command("TicketsGithubFetch", function()
        -- Open loading window immediately for instant feedback
        local buf, win, repo = ui.open_loading_window()
        if not buf then
            return -- Error already notified
        end

        notify.fetching_issues()

        github.fetch_issues(function(issues)
            -- Update the loading window with fetched issues
            ui.update_issues_window(buf, win, issues, repo)
        end)
    end, {
        desc = "Fetch GitHub issues (uses cache if available)",
    })

    -- Fetch GitHub issues (bypass cache)
    vim.api.nvim_create_user_command("TicketsGithubRefresh", function()
        -- Open loading window immediately for instant feedback
        local buf, win, repo = ui.open_loading_window()
        if not buf then
            return -- Error already notified
        end

        notify.fetching_issues()

        github.fetch_issues(function(issues)
            -- Update the loading window with fetched issues
            ui.update_issues_window(buf, win, issues, repo)
        end, true) -- force_refresh = true
    end, {
        desc = "Fetch GitHub issues, bypassing cache",
    })

    -- Clear cache
    vim.api.nvim_create_user_command("TicketsCacheClear", function(cmd_opts)
        local repo = cmd_opts.args
        if repo ~= "" then
            cache.invalidate(repo)
            notify.cache_cleared(repo)
        else
            cache.invalidate()
            notify.cache_cleared()
        end
    end, {
        nargs = "?",
        desc = "Clear cache for a specific repo or all repos",
        complete = function()
            -- TODO: Could add completion for cached repos in the future
            return {}
        end,
    })

    -- Show cache statistics
    vim.api.nvim_create_user_command("TicketsCacheStats", function()
        local stats = cache.stats()
        notify.cache_stats(stats.repos, stats.total_issues, stats.total_details)
    end, {
        desc = "Show cache statistics",
    })

    -- Create new issue
    vim.api.nvim_create_user_command("TicketsCreate", function()
        create.open_create_buffer()
    end, {
        desc = "Create a new GitHub issue",
    })

    -- Setup keymap for todo file buffer
    M.setup_todo_keymap(target_file)
end

-- Setup keymap for the todo file buffer
-- @param target_file string: Path to todo file
function M.setup_todo_keymap(target_file)
    local buf = utils.get_or_create_buf(target_file)

    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = function()
            if vim.api.nvim_get_option_value("modified", { buf = buf }) then
                notify.save_changes_first()
            else
                vim.api.nvim_win_close(0, true)
            end
        end,
        desc = "Close todo window (if saved)",
    })
end

return M

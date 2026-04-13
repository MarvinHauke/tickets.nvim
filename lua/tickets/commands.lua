-- User command definitions and registration
local M = {}

local ui = require("tickets.ui")
local github = require("tickets.github")
local cache = require("tickets.cache")
local notify = require("tickets.notifications")

-- Register all user commands
function M.setup()

    -- Open issues buffer (uses cache for instant display, fetches if no cache)
    vim.api.nvim_create_user_command("Tickets", function()
        local buf, win, repo = ui.open_loading_window()
        if not buf then
            return
        end
        github.fetch_issues(function(issues)
            ui.update_issues_window(buf, win, issues, repo)
        end)
    end, {
        desc = "Open issues overview",
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

    -- Create new issue (opens list+detail layout in create mode)
    vim.api.nvim_create_user_command("TicketsCreate", function()
        ui.open_with_create_mode()
    end, {
        desc = "Create a new GitHub issue",
    })

end

return M

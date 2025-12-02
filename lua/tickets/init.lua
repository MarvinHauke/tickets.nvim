local M = {}

local ui = require("tickets.ui")
local utils = require("tickets.utils")
local github = require("tickets.github")
local cache = require("tickets.cache")

local function setup_user_commands(opts)
    local target_file = opts.target_file or "todo.md"
    vim.api.nvim_create_user_command("Tickets", function()
        ui.open_floating_file(target_file)
    end, {})

    vim.api.nvim_create_user_command("TicketsGithubFetch", function()
        github.fetch_issues(function(issues)
            ui.open_issues_window(issues)
        end)
    end, {})

    vim.api.nvim_create_user_command("TicketsGithubRefresh", function()
        github.fetch_issues(function(issues)
            ui.open_issues_window(issues)
        end, true) -- force_refresh = true
    end, { desc = "Fetch GitHub issues, bypassing cache" })

    vim.api.nvim_create_user_command("TicketsCacheClear", function(opts)
        local repo = opts.args
        if repo ~= "" then
            cache.invalidate(repo)
            vim.notify("Cache cleared for repository: " .. repo, vim.log.levels.INFO)
        else
            cache.invalidate()
            vim.notify("All caches cleared", vim.log.levels.INFO)
        end
    end, {
        nargs = "?",
        desc = "Clear cache for a specific repo or all repos",
        complete = function()
            -- Could add completion for cached repos in the future
            return {}
        end,
    })

    vim.api.nvim_create_user_command("TicketsCacheStats", function()
        local stats = cache.stats()
        vim.notify(
            string.format(
                "Cache Stats:\n- Repositories: %d\n- Total Issues: %d\n- Total Details: %d",
                stats.repos,
                stats.total_issues,
                stats.total_details
            ),
            vim.log.levels.INFO
        )
    end, { desc = "Show cache statistics" })

    local buf = utils.get_or_create_buf(target_file)
    vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
        noremap = true,
        silent = true,
        callback = function()
            if vim.api.nvim_get_option_value("modified", { buf = buf }) then
                vim.notify("save your changes pls", vim.log.levels.WARN)
            else
                vim.api.nvim_win_close(0, true)
            end
        end,
    })
end

M.setup = function(opts)
    setup_user_commands(opts)
end

return M

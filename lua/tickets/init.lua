local M = {}

local ui = require("tickets.ui")
local utils = require("tickets.utils")
local github = require("tickets.github")

local function setup_user_commands(opts)
    local target_file = opts.target_file or "todo.md"
    vim.api.nvim_create_user_command("Tickets", function()
        ui.open_floating_file(target_file)
    end, {})

    vim.api.nvim_create_user_command("GithubFetch", function()
        github.fetch_issues(function(issues)
            for _, issue in ipairs(issues) do
                print(string.format("#%d: %s", issue.number, issue.title))
            end
        end)
    end, {})

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

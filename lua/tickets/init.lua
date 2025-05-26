local M = {}

local ui = require("tickets.ui")
local utils = require("tickets.utils")

local function setup_user_commands(opts)
    local target_file = opts.target_file or "todo.md"
    vim.api.nvim_create_user_command("Td", function()
        ui.open_floating_file(target_file)
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

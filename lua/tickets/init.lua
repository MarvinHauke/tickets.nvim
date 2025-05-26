local M = {}

local ui = require("tickets.ui")

local function setup_user_commands(opts)
    local target_file = opts.target_file or "todo.md"
    vim.api.nvim_create_user_command("Td", function()
        ui.open_floating_file(target_file)
    end, {})
end

M.setup = function(opts)
    setup_user_commands(opts)
end

return M

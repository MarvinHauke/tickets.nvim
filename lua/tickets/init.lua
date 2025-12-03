-- Main plugin entry point
local M = {}

local config = require("tickets.config")
local commands = require("tickets.commands")

-- Setup the plugin
-- @param opts table: Configuration options (see config.lua for defaults)
function M.setup(opts)
    opts = opts or {}

    -- Validate and merge with defaults
    local validated_config, errors = config.validate(opts)

    -- Report validation errors
    if #errors > 0 then
        local error_msg = "Tickets.nvim configuration errors:\n" .. table.concat(errors, "\n")
        vim.notify(error_msg, vim.log.levels.ERROR)
        return
    end

    -- Store validated config globally for other modules
    M.config = validated_config

    -- Register all commands
    commands.setup(validated_config)
end

return M

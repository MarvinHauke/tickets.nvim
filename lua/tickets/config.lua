-- Configuration validation and defaults
local M = {}

-- Default configuration
M.defaults = {
    target_file = "todo.md",
    prefetch = {
        enabled = true,
        delay = 500, -- ms between fetches
        max_concurrent = 1, -- number of concurrent fetches
    },
    ui = {
        window = {
            total_width_ratio = 0.9,
            total_height_ratio = 0.8,
            list_width_ratio = 0.35,
            detail_width_ratio = 0.65,
            spacing = 2,
        },
        border = "rounded", -- "none", "single", "double", "rounded", "solid", "shadow"
    },
}

-- Validate configuration value type
-- @param value any: Value to validate
-- @param expected_type string: Expected type ("string", "number", "boolean", "table")
-- @param path string: Configuration path for error messages
-- @return boolean, string|nil: Valid status and error message
local function validate_type(value, expected_type, path)
    local actual_type = type(value)
    if actual_type ~= expected_type then
        return false, string.format("Invalid type for '%s': expected %s, got %s", path, expected_type, actual_type)
    end
    return true, nil
end

-- Validate number is within range
-- @param value number: Value to validate
-- @param min number: Minimum value (inclusive)
-- @param max number: Maximum value (inclusive)
-- @param path string: Configuration path for error messages
-- @return boolean, string|nil: Valid status and error message
local function validate_range(value, min, max, path)
    if value < min or value > max then
        return false, string.format("Value for '%s' must be between %d and %d, got %d", path, min, max, value)
    end
    return true, nil
end

-- Validate border style
-- @param value string: Border style
-- @param path string: Configuration path
-- @return boolean, string|nil: Valid status and error message
local function validate_border(value, path)
    local valid_borders = {
        "none",
        "single",
        "double",
        "rounded",
        "solid",
        "shadow",
    }

    for _, valid in ipairs(valid_borders) do
        if value == valid then
            return true, nil
        end
    end

    return false, string.format("Invalid border style for '%s': must be one of %s, got '%s'", path, table.concat(valid_borders, ", "), value)
end

-- Validate configuration
-- @param config table: User configuration
-- @return table, table: Merged config and list of validation errors
function M.validate(config)
    config = config or {}
    local errors = {}

    -- Validate target_file
    if config.target_file ~= nil then
        local ok, err = validate_type(config.target_file, "string", "target_file")
        if not ok then
            table.insert(errors, err)
        elseif config.target_file == "" then
            table.insert(errors, "target_file cannot be empty string")
        end
    end

    -- Validate prefetch config
    if config.prefetch ~= nil then
        local ok, err = validate_type(config.prefetch, "table", "prefetch")
        if not ok then
            table.insert(errors, err)
        else
            if config.prefetch.enabled ~= nil then
                ok, err = validate_type(config.prefetch.enabled, "boolean", "prefetch.enabled")
                if not ok then
                    table.insert(errors, err)
                end
            end

            if config.prefetch.delay ~= nil then
                ok, err = validate_type(config.prefetch.delay, "number", "prefetch.delay")
                if not ok then
                    table.insert(errors, err)
                else
                    ok, err = validate_range(config.prefetch.delay, 100, 5000, "prefetch.delay")
                    if not ok then
                        table.insert(errors, err)
                    end
                end
            end

            if config.prefetch.max_concurrent ~= nil then
                ok, err = validate_type(config.prefetch.max_concurrent, "number", "prefetch.max_concurrent")
                if not ok then
                    table.insert(errors, err)
                else
                    ok, err = validate_range(config.prefetch.max_concurrent, 1, 5, "prefetch.max_concurrent")
                    if not ok then
                        table.insert(errors, err)
                    end
                end
            end
        end
    end

    -- Validate UI config
    if config.ui ~= nil then
        local ok, err = validate_type(config.ui, "table", "ui")
        if not ok then
            table.insert(errors, err)
        else
            -- Validate window ratios
            if config.ui.window ~= nil then
                ok, err = validate_type(config.ui.window, "table", "ui.window")
                if not ok then
                    table.insert(errors, err)
                else
                    local ratios = {
                        total_width_ratio = { 0.5, 1.0 },
                        total_height_ratio = { 0.5, 1.0 },
                        list_width_ratio = { 0.1, 0.9 },
                        detail_width_ratio = { 0.1, 0.9 },
                    }

                    for ratio_name, range in pairs(ratios) do
                        if config.ui.window[ratio_name] ~= nil then
                            ok, err = validate_type(config.ui.window[ratio_name], "number", "ui.window." .. ratio_name)
                            if not ok then
                                table.insert(errors, err)
                            else
                                ok, err = validate_range(config.ui.window[ratio_name], range[1], range[2], "ui.window." .. ratio_name)
                                if not ok then
                                    table.insert(errors, err)
                                end
                            end
                        end
                    end

                    if config.ui.window.spacing ~= nil then
                        ok, err = validate_type(config.ui.window.spacing, "number", "ui.window.spacing")
                        if not ok then
                            table.insert(errors, err)
                        else
                            ok, err = validate_range(config.ui.window.spacing, 0, 10, "ui.window.spacing")
                            if not ok then
                                table.insert(errors, err)
                            end
                        end
                    end
                end
            end

            -- Validate border
            if config.ui.border ~= nil then
                ok, err = validate_type(config.ui.border, "string", "ui.border")
                if not ok then
                    table.insert(errors, err)
                else
                    ok, err = validate_border(config.ui.border, "ui.border")
                    if not ok then
                        table.insert(errors, err)
                    end
                end
            end
        end
    end

    -- Deep merge with defaults
    local merged = vim.tbl_deep_extend("force", M.defaults, config)

    return merged, errors
end

return M

-- Window configuration and layout management
local M = {}

-- Centralized layout configuration
-- These ratios control the size and positioning of floating windows
M.LAYOUT = {
    -- Total window area as ratio of editor size
    total_width_ratio = 0.9,
    total_height_ratio = 0.8,

    -- Split ratios for list and detail views
    list_width_ratio = 0.35,  -- List takes 35% of total width
    detail_width_ratio = 0.65, -- Detail takes 65% of total width

    -- Spacing between windows
    spacing = 2,
}

-- Window border styles
M.BORDER = {
    default = "rounded",
    minimal = "rounded",
}

-- Normalize position values that can be either number or table with [false] key
-- Neovim's window API sometimes returns {[false] = value} for row/col
-- @param value number|table: Position value from window config
-- @return number: Normalized position value
function M.normalize_position(value)
    return type(value) == "table" and value[false] or value
end

-- Calculate base dimensions for all floating windows
-- @return table: {total_width, total_height, center_row, center_col}
function M.get_base_dimensions()
    local total_width = math.floor(vim.o.columns * M.LAYOUT.total_width_ratio)
    local total_height = math.floor(vim.o.lines * M.LAYOUT.total_height_ratio)

    -- Calculate centered position
    local center_row = math.floor((vim.o.lines - total_height) / 2)
    local center_col = math.floor((vim.o.columns - total_width) / 2)

    return {
        total_width = total_width,
        total_height = total_height,
        center_row = center_row,
        center_col = center_col,
    }
end

-- Create window configuration for issue list window
-- @return table: Window config suitable for nvim_open_win()
function M.create_list_window_config()
    local dims = M.get_base_dimensions()
    local width = math.floor(dims.total_width * M.LAYOUT.list_width_ratio)

    return {
        relative = "editor",
        width = width,
        height = dims.total_height,
        col = dims.center_col,
        row = dims.center_row,
        border = M.BORDER.default,
    }
end

-- Create window configuration for detail preview window
-- Positioned to the right of the list window
-- @param list_win number: Window handle of the list window
-- @return table: Window config suitable for nvim_open_win()
function M.create_detail_window_config(list_win)
    local list_config = vim.api.nvim_win_get_config(list_win)
    local list_width = list_config.width
    local list_height = list_config.height

    -- Normalize row/col (handle both number and table formats)
    local list_row = M.normalize_position(list_config.row)
    local list_col = M.normalize_position(list_config.col)

    -- Calculate detail window dimensions
    local dims = M.get_base_dimensions()
    local detail_width = math.floor(dims.total_width * M.LAYOUT.detail_width_ratio) - M.LAYOUT.spacing

    return {
        relative = "editor",
        width = detail_width,
        height = list_height,
        row = list_row,
        col = list_col + list_width + M.LAYOUT.spacing,
        style = "minimal",
        border = M.BORDER.minimal,
    }
end

-- Create window configuration for single floating file window (todo file)
-- Uses same dimensions as list window for consistency
-- @return table: Window config suitable for nvim_open_win()
function M.create_file_window_config()
    return M.create_list_window_config()
end

return M

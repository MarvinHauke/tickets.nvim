local M = {}

local utils = require("tickets.utils")

local function win_config()
    local width = math.min(math.floor(vim.o.columns * 0.8), 64)
    local height = math.floor(vim.o.lines * 0.8)

    return {
        relative = "editor",
        width = width,
        height = height,
        col = 1,
        row = 1,
        border = "rounded",
    }
end

function M.open_floating_file(target_file)
    local expanded_path = utils.expand_path(target_file)

    if vim.fn.filereadable(expanded_path) == 0 then
        vim.notify("Todo File does not exist at directory: " .. expanded_path, vim.log.levels.ERROR)
    end

    local buf = vim.fn.bufnr(expanded_path, true)
    if buf == -1 then
        buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, expanded_path)
    end

    vim.bo[buf].swapfile = false

    local win = vim.api.nvim_open_win(buf, true, win_config())
end

-- New function to open a floating window with the GitHub issues
function M.open_issues_window(issues)
    local buf = vim.api.nvim_create_buf(false, true) -- scratch buffer
    local lines = {}

    for _, issue in ipairs(issues) do
        table.insert(lines, string.format("#%d %s", issue.number, issue.title))
    end

    if #lines == 0 then
        table.insert(lines, "No issues found.")
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "markdown"

    local win = vim.api.nvim_open_win(buf, true, win_config())

    -- Optional: map `q` to close window
    vim.keymap.set("n", "q", function()
        vim.api.nvim_win_close(win, true)
    end, { buffer = buf, silent = true })
end

return M

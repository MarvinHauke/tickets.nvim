local M = {}

function M.get_or_create_buf(path)
    local expanded_path = M.expand_path(path) -- reuse your existing expand_path

    local buf = vim.fn.bufnr(expanded_path, true)
    if buf == -1 then
        buf = vim.api.nvim_create_buf(false, false)
        vim.api.nvim_buf_set_name(buf, expanded_path)
    end

    vim.bo[buf].swapfile = false
    return buf
end

function M.expand_path(path)
    if path:sub(1, 1) == "~" then
        return os.getenv("HOME") .. path:sub(2)
    end
    return path
end

return M

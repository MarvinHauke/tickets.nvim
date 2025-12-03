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

function M.get_current_repo()
    local handle = io.popen("git remote get-url origin 2>/dev/null")
    if not handle then
        return nil
    end
    local result = handle:read("*a")
    handle:close()

    if not result or result == "" then
        return nil
    end

    -- Trim whitespace
    result = result:gsub("%s+", "")

    -- Parse owner/repo
    -- Matches: git@github.com:Owner/Repo.git or https://github.com/Owner/Repo.git
    local owner, repo = result:match("github%.com[:/]([%w%-%.]+)/([%w%-%.]+)")

    if owner and repo then
        -- Remove .git suffix if present
        repo = repo:gsub("%.git$", "")
        return owner .. "/" .. repo
    end

    return nil
end

return M

-- lua/tickets/github.lua
local curl = require("plenary.curl")
local M = {}

-- Check if gh CLI is available and authenticated
local function is_gh_available()
    local handle = io.popen("gh auth status 2>&1")
    if not handle then
        return false
    end
    local result = handle:read("*a")
    handle:close()
    return result:match("Logged in") ~= nil
end

-- Get GitHub token from env (optional, for rate limits & private repos)
local function get_github_token()
    return os.getenv("GITHUB_TOKEN") or ""
end

-- Fetch issues using gh CLI
local function fetch_issues_gh(callback)
    local api_url = "repos/MarvinHauke/tickets.nvim/issues"

    vim.fn.jobstart({ "gh", "api", api_url }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if not data then
                return
            end
            local output = table.concat(data, "\n")
            vim.schedule(function()
                if output and output ~= "" then
                    local ok, issues = pcall(vim.fn.json_decode, output)
                    if ok and callback then
                        callback(issues)
                    else
                        vim.notify("Failed to decode GitHub response", vim.log.levels.ERROR)
                    end
                end
            end)
        end,
        on_stderr = function(_, data)
            if data and #data > 0 then
                vim.schedule(function()
                    vim.notify("gh CLI error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
                end)
            end
        end,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                vim.schedule(function()
                    vim.notify("gh CLI failed with exit code: " .. exit_code, vim.log.levels.ERROR)
                end)
            end
        end,
    })
end

-- Fetch issues using curl (fallback when gh CLI unavailable)
local function fetch_issues_curl(callback)
    local api_url = "https://api.github.com/repos/MarvinHauke/tickets.nvim/issues"
    local headers = {
        ["Accept"] = "application/vnd.github.v3+json",
    }
    local token = get_github_token()
    if token ~= "" then
        headers["Authorization"] = "token " .. token
    end

    curl.get(api_url, {
        headers = headers,
        timeout = 5000,
        callback = function(res)
            vim.schedule(function()
                if res.status == 200 then
                    local ok, issues = pcall(vim.fn.json_decode, res.body)
                    if ok then
                        if callback then
                            callback(issues)
                        end
                    else
                        vim.notify("Failed to decode JSON", vim.log.levels.ERROR)
                    end
                else
                    vim.notify("GitHub API error (status " .. res.status .. ")", vim.log.levels.ERROR)
                end
            end)
        end,
    })
end

-- Main fetch function with gh CLI support and fallback
function M.fetch_issues(callback)
    if is_gh_available() then
        fetch_issues_gh(callback)
    else
        local token = get_github_token()
        if token == "" then
            vim.notify(
                "Neither gh CLI nor GITHUB_TOKEN available. Run 'gh auth login' or set GITHUB_TOKEN",
                vim.log.levels.WARN
            )
            return
        end
        fetch_issues_curl(callback)
    end
end

return M

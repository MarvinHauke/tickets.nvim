-- lua/tickets/github.lua
local curl = require("plenary.curl")
local M = {}

-- Get GitHub token from env (optional, for rate limits & private repos)
local function get_github_token()
    return os.getenv("GITHUB_TOKEN") or ""
end

function M.fetch_issues(callback)
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
                print("🌐 GitHub API status:", res.status)
                print("📦 GitHub API body (first 100):", res.body:sub(1, 100))

                if res.status == 200 then
                    local ok, issues = pcall(vim.fn.json_decode, res.body)
                    if ok then
                        if callback then
                            callback(issues)
                        else
                            print("✅ Issues:", vim.inspect(issues))
                        end
                    else
                        vim.notify("❌ Failed to decode JSON", vim.log.levels.ERROR)
                    end
                else
                    vim.notify("❌ GitHub API error (status " .. res.status .. ")", vim.log.levels.ERROR)
                end
            end)
        end,
    })
end
return M

-- lua/tickets/github.lua
local curl = require("plenary.curl")
local utils = require("tickets.utils")
local cache = require("tickets.cache")
local M = {}

-- Check if gh CLI is available and authenticated
local function is_gh_available()
    local handle = io.popen("gh auth status 2>&1")
    if not handle then
        return false
    end
    local result = handle:read("*a")
    handle:close()

    -- Check if logged in AND that there's no invalid token error
    local has_login = result:match("Logged in") ~= nil
    local has_invalid_token = result:match("invalid") ~= nil or result:match("Failed to log in") ~= nil

    return has_login and not has_invalid_token
end

-- Get GitHub token from env (optional, for rate limits & private repos)
local function get_github_token()
    return os.getenv("GITHUB_TOKEN") or ""
end

-- Fetch issues using gh CLI
local function fetch_issues_gh(repo, callback)
    local api_url = "repos/" .. repo .. "/issues"

    local stderr_data = {}

    -- Use env -u to explicitly unset GITHUB_TOKEN to force gh CLI to use keyring authentication
    -- This prevents issues when GITHUB_TOKEN is set but invalid
    vim.fn.jobstart({ "env", "-u", "GITHUB_TOKEN", "gh", "api", api_url }, {
        stdout_buffered = true,
        stderr_buffered = true,
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
                        if #issues == 0 then
                            vim.notify("No issues found for this repository.", vim.log.levels.INFO)
                        else
                            vim.notify(#issues .. " issues fetched.", vim.log.levels.INFO)
                        end
                    else
                        vim.notify("Failed to decode GitHub response", vim.log.levels.ERROR)
                    end
                end
            end)
        end,
        on_stderr = function(_, data)
            if data then
                stderr_data = data
            end
        end,
        on_exit = function(_, exit_code)
            if exit_code ~= 0 then
                local error_msg = table.concat(stderr_data, "\n")
                vim.schedule(function()
                    vim.notify("gh CLI failed (exit code " .. exit_code .. "): " .. error_msg, vim.log.levels.ERROR)
                end)
            end
        end,
    })
end

-- Fetch issues using curl (fallback when gh CLI unavailable)
local function fetch_issues_curl(repo, callback)
    local api_url = "https://api.github.com/repos/" .. repo .. "/issues"
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
                            if #issues == 0 then
                                vim.notify("No issues found for this repository.", vim.log.levels.INFO)
                            else
                                vim.notify(#issues .. " issues fetched.", vim.log.levels.INFO)
                            end
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
function M.fetch_issues(callback, force_refresh)
    local repo = utils.get_current_repo()
    if not repo then
        vim.notify("Could not determine current GitHub repository. Are you in a git repo with a 'github.com' origin?", vim.log.levels.ERROR)
        return
    end

    -- Check cache first (unless force_refresh is true)
    if not force_refresh then
        local cached_issues = cache.get_issues(repo)
        if cached_issues then
            vim.notify("Using cached issues (" .. #cached_issues .. " issues)", vim.log.levels.INFO)
            if callback then
                callback(cached_issues)
            end
            return
        end
    end

    -- Wrap callback to cache the results
    local cache_wrapper = function(issues)
        if issues then
            cache.set_issues(repo, issues)
        end
        if callback then
            callback(issues)
        end
    end

    if is_gh_available() then
        fetch_issues_gh(repo, cache_wrapper)
    else
        local token = get_github_token()
        if token == "" then
            vim.notify("Neither gh CLI nor GITHUB_TOKEN available. Run 'gh auth login' or set GITHUB_TOKEN", vim.log.levels.WARN)
            return
        end
        fetch_issues_curl(repo, cache_wrapper)
    end
end

-- Fetch full issue details including comments
-- @param repo string: "owner/repo"
-- @param issue_number number: Issue number
-- @param callback function: Called with (issue_with_comments) or (nil, error)
function M.fetch_issue_details(repo, issue_number, callback, force_refresh)
    if not is_gh_available() then
        vim.notify("gh CLI is required for fetching issue details", vim.log.levels.ERROR)
        return
    end

    -- Check cache first (unless force_refresh is true)
    if not force_refresh then
        local cached_details = cache.get_issue_details(repo, issue_number)
        if cached_details then
            vim.schedule(function()
                callback(cached_details)
            end)
            return
        end
    end

    local issue_url = "repos/" .. repo .. "/issues/" .. issue_number
    local comments_url = "repos/" .. repo .. "/issues/" .. issue_number .. "/comments"

    local issue_data = nil
    local comments_data = nil
    local issue_done = false
    local comments_done = false

    local function check_complete()
        if issue_done and comments_done then
            if issue_data and comments_data then
                issue_data.comments = comments_data
                -- Cache the result before calling the callback
                cache.set_issue_details(repo, issue_number, issue_data)
                vim.schedule(function()
                    callback(issue_data)
                end)
            else
                vim.schedule(function()
                    callback(nil, "Failed to fetch issue details")
                end)
            end
        end
    end

    -- Fetch issue details
    vim.fn.jobstart({ "env", "-u", "GITHUB_TOKEN", "gh", "api", issue_url }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                local output = table.concat(data, "\n")
                if output and output ~= "" then
                    local ok, result = pcall(vim.fn.json_decode, output)
                    if ok then
                        issue_data = result
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            issue_done = true
            if exit_code ~= 0 then
                issue_data = nil
            end
            check_complete()
        end,
    })

    -- Fetch comments
    vim.fn.jobstart({ "env", "-u", "GITHUB_TOKEN", "gh", "api", comments_url }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
            if data then
                local output = table.concat(data, "\n")
                if output and output ~= "" then
                    local ok, result = pcall(vim.fn.json_decode, output)
                    if ok then
                        comments_data = result
                    end
                end
            end
        end,
        on_exit = function(_, exit_code)
            comments_done = true
            if exit_code ~= 0 then
                comments_data = {} -- Empty array if comments fail
            end
            check_complete()
        end,
    })
end

return M

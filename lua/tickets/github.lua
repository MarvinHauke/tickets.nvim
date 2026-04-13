-- lua/tickets/github.lua
local curl = require("plenary.curl")
local utils = require("tickets.utils")
local cache = require("tickets.cache")
local M = {}

-- Check if gh CLI is available and authenticated via keyring
local function is_gh_available()
    local handle = io.popen("gh auth status 2>&1")
    if not handle then
        return false
    end
    local result = handle:read("*a")
    handle:close()

    -- Check for a valid keyring-based login, which is reliable even when
    -- GITHUB_TOKEN is set but invalid
    local has_keyring = result:match("Logged in to github%.com account %S+ %(keyring%)") ~= nil
    if has_keyring then
        return true
    end

    -- Fall back to checking for any valid login without token errors
    local has_login = result:match("Logged in") ~= nil
    local has_invalid_token = result:match("invalid") ~= nil or result:match("Failed to log in") ~= nil

    return has_login and not has_invalid_token
end

-- Get GitHub token from env (optional, for rate limits & private repos)
local function get_github_token()
    return os.getenv("GITHUB_TOKEN") or ""
end

-- Fetch issues using gh CLI
-- @param repo string: "owner/repo"
-- @param callback function: Called with (issues)
-- @param opts table|nil: { state = "open"|"closed", per_page = number, page = number }
local function fetch_issues_gh(repo, callback, opts)
    opts = opts or {}
    local state = opts.state or "open"
    local per_page = opts.per_page or 30
    local page = opts.page or 1
    local api_url = "repos/" .. repo .. "/issues?state=" .. state .. "&per_page=" .. per_page .. "&page=" .. page

    local stderr_data = {}

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
-- @param opts table|nil: { state = "open"|"closed", per_page = number, page = number }
local function fetch_issues_curl(repo, callback, opts)
    opts = opts or {}
    local state = opts.state or "open"
    local per_page = opts.per_page or 30
    local page = opts.page or 1
    local api_url = "https://api.github.com/repos/" .. repo .. "/issues?state=" .. state .. "&per_page=" .. per_page .. "&page=" .. page
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
-- @param callback function: Called with (issues)
-- @param force_refresh boolean|nil: Bypass cache if true
-- @param opts table|nil: { state = "open"|"closed", per_page = number, page = number }
function M.fetch_issues(callback, force_refresh, opts)
    opts = opts or {}
    local state = opts.state or "open"

    local repo = utils.get_current_repo()
    if not repo then
        vim.notify("Could not determine current GitHub repository. Are you in a git repo with a 'github.com' origin?", vim.log.levels.ERROR)
        return
    end

    -- Only cache open issues; closed issues always fetch fresh
    if not force_refresh and state == "open" then
        local cached_issues = cache.get_issues(repo)
        if cached_issues then
            vim.notify("Using cached issues (" .. #cached_issues .. " issues)", vim.log.levels.INFO)
            if callback then
                callback(cached_issues)
            end
            return
        end
    end

    -- Wrap callback to cache open issues only
    local cache_wrapper = function(issues)
        if issues and state == "open" then
            cache.set_issues(repo, issues)
        end
        if callback then
            callback(issues)
        end
    end

    if is_gh_available() then
        fetch_issues_gh(repo, cache_wrapper, opts)
    else
        local token = get_github_token()
        if token == "" then
            vim.notify("Neither gh CLI nor GITHUB_TOKEN available. Run 'gh auth login' or set GITHUB_TOKEN", vim.log.levels.WARN)
            return
        end
        fetch_issues_curl(repo, cache_wrapper, opts)
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

-- Helper to run a gh api command with JSON payload via stdin
-- @param args table: Arguments for gh api (url, method, etc.)
-- @param payload string: JSON payload to send via stdin
-- @param callback function: Called with (exit_code, stdout, stderr)
local function gh_api_with_payload(args, payload, callback)
    local cmd = { "env", "-u", "GITHUB_TOKEN", "gh", "api" }
    for _, arg in ipairs(args) do
        table.insert(cmd, arg)
    end
    table.insert(cmd, "--input")
    table.insert(cmd, "-")

    local stdout_data = {}
    local stderr_data = {}

    local job_id = vim.fn.jobstart(cmd, {
        stdout_buffered = true,
        stderr_buffered = true,
        on_stdout = function(_, data)
            if data then
                vim.list_extend(stdout_data, data)
            end
        end,
        on_stderr = function(_, data)
            if data then
                vim.list_extend(stderr_data, data)
            end
        end,
        on_exit = function(_, exit_code)
            vim.schedule(function()
                callback(exit_code, table.concat(stdout_data, "\n"), table.concat(stderr_data, "\n"))
            end)
        end,
    })

    if job_id > 0 then
        vim.fn.chansend(job_id, payload)
        vim.fn.chanclose(job_id, "stdin")
    else
        vim.schedule(function()
            callback(-1, "", "Failed to start gh CLI")
        end)
    end
end

-- Toggle issue state (open/closed)
-- @param repo string: "owner/repo"
-- @param issue_number number: Issue number
-- @param new_state string: "open" or "closed"
-- @param callback function: Called with (success, error)
function M.toggle_issue_state(repo, issue_number, new_state, callback)
    if not is_gh_available() then
        vim.notify("gh CLI is required for updating issues", vim.log.levels.ERROR)
        return
    end

    local api_url = "repos/" .. repo .. "/issues/" .. issue_number
    local payload = vim.fn.json_encode({ state = new_state })

    gh_api_with_payload({ api_url, "--method", "PATCH" }, payload, function(exit_code)
        if exit_code == 0 then
            cache.invalidate(repo)
            callback(true, nil)
        else
            callback(false, "Failed to update issue state")
        end
    end)
end

-- Post a comment on an issue
-- @param repo string: "owner/repo"
-- @param issue_number number: Issue number
-- @param body string: Comment body text
-- @param callback function: Called with (success, error)
function M.post_comment(repo, issue_number, body, callback)
    if not is_gh_available() then
        vim.notify("gh CLI is required for posting comments", vim.log.levels.ERROR)
        return
    end

    local api_url = "repos/" .. repo .. "/issues/" .. issue_number .. "/comments"
    local payload = vim.fn.json_encode({ body = body })

    gh_api_with_payload({ api_url, "--method", "POST" }, payload, function(exit_code)
        if exit_code == 0 then
            cache.invalidate_issue_details(repo, issue_number)
            callback(true, nil)
        else
            callback(false, "Failed to post comment")
        end
    end)
end

-- Edit issue metadata (title, body, labels, assignees)
-- @param repo string: "owner/repo"
-- @param issue_number number: Issue number
-- @param updates table: { title?, body?, labels?, assignees? }
-- @param callback function: Called with (success, error)
function M.edit_issue(repo, issue_number, updates, callback)
    if not is_gh_available() then
        vim.notify("gh CLI is required for editing issues", vim.log.levels.ERROR)
        return
    end

    local api_url = "repos/" .. repo .. "/issues/" .. issue_number
    local payload = vim.fn.json_encode(updates)

    gh_api_with_payload({ api_url, "--method", "PATCH" }, payload, function(exit_code)
        if exit_code == 0 then
            cache.invalidate(repo)
            callback(true, nil)
        else
            callback(false, "Failed to edit issue")
        end
    end)
end

return M

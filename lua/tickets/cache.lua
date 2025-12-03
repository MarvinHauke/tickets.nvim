-- In-memory cache for GitHub issues
-- Phase 1: Session-based caching to avoid redundant API calls

local M = {}

-- Cache structure:
-- {
--   ["owner/repo"] = {
--     issues = { ... },           -- List of issues from fetch_issues()
--     issue_details = {           -- Detailed issue data by issue number
--       [123] = { ... },
--       [456] = { ... }
--     }
--   }
-- }
local cache = {}

-- Get cached issues list for a repository
-- @param repo string: Repository in "owner/repo" format
-- @return table|nil: Cached issues array or nil if not cached
function M.get_issues(repo)
    if not repo or not cache[repo] then
        return nil
    end
    return cache[repo].issues
end

-- Set cached issues list for a repository
-- @param repo string: Repository in "owner/repo" format
-- @param issues table: Array of issues to cache
function M.set_issues(repo, issues)
    if not repo or not issues then
        return
    end

    if not cache[repo] then
        cache[repo] = {
            issues = {},
            issue_details = {}
        }
    end

    cache[repo].issues = issues
end

-- Get cached detailed issue data
-- @param repo string: Repository in "owner/repo" format
-- @param issue_number number: Issue number
-- @return table|nil: Cached issue details or nil if not cached
function M.get_issue_details(repo, issue_number)
    if not repo or not issue_number or not cache[repo] then
        return nil
    end
    return cache[repo].issue_details[issue_number]
end

-- Set cached detailed issue data
-- @param repo string: Repository in "owner/repo" format
-- @param issue_number number: Issue number
-- @param details table: Detailed issue data to cache
function M.set_issue_details(repo, issue_number, details)
    if not repo or not issue_number or not details then
        return
    end

    if not cache[repo] then
        cache[repo] = {
            issues = {},
            issue_details = {}
        }
    end

    cache[repo].issue_details[issue_number] = details
end

-- Invalidate cache for a specific repository or all repositories
-- @param repo string|nil: Repository to invalidate, or nil to clear all
function M.invalidate(repo)
    if repo then
        cache[repo] = nil
    else
        cache = {}
    end
end

-- Get cache statistics (for debugging/status)
-- @return table: Cache statistics
function M.stats()
    local stats = {
        repos = 0,
        total_issues = 0,
        total_details = 0
    }

    for repo, data in pairs(cache) do
        stats.repos = stats.repos + 1
        if data.issues then
            stats.total_issues = stats.total_issues + #data.issues
        end
        if data.issue_details then
            for _ in pairs(data.issue_details) do
                stats.total_details = stats.total_details + 1
            end
        end
    end

    return stats
end

return M

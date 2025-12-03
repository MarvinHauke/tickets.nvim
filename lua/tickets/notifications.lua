-- Centralized notification messages
local M = {}

-- Notification levels
local INFO = vim.log.levels.INFO
local WARN = vim.log.levels.WARN
local ERROR = vim.log.levels.ERROR

-- Cache notifications
function M.cache_cleared(repo)
    if repo then
        vim.notify("Cache cleared for repository: " .. repo, INFO)
    else
        vim.notify("All caches cleared", INFO)
    end
end

function M.cache_stats(repos, total_issues, total_details)
    vim.notify(
        string.format(
            "Cache Stats:\n- Repositories: %d\n- Total Issues: %d\n- Total Details: %d",
            repos,
            total_issues,
            total_details
        ),
        INFO
    )
end

function M.using_cached_issues(count)
    vim.notify(string.format("Using cached issues (%d issues)", count), INFO)
end

-- Issue fetching notifications
function M.issues_fetched(count)
    vim.notify(string.format("%d issues fetched.", count), INFO)
end

function M.no_issues_found()
    vim.notify("No issues found for this repository.", INFO)
end

function M.prefetch_complete(count)
    vim.notify(string.format("Prefetched %d issue details", count), INFO)
end

-- Error notifications
function M.repo_not_found()
    vim.notify(
        "Could not determine current GitHub repository. Are you in a git repo with a 'github.com' origin?",
        ERROR
    )
end

function M.repo_determination_failed()
    vim.notify("Could not determine repository", ERROR)
end

function M.gh_auth_missing()
    vim.notify(
        "Neither gh CLI nor GITHUB_TOKEN available. Run 'gh auth login' or set GITHUB_TOKEN",
        WARN
    )
end

function M.gh_cli_required()
    vim.notify("gh CLI is required for fetching issue details", ERROR)
end

function M.gh_cli_failed(exit_code, error_msg)
    vim.notify(string.format("gh CLI failed (exit code %d): %s", exit_code, error_msg), ERROR)
end

function M.github_api_error(status)
    vim.notify(string.format("GitHub API error (status %d)", status), ERROR)
end

function M.json_decode_failed()
    vim.notify("Failed to decode JSON", ERROR)
end

function M.github_response_decode_failed()
    vim.notify("Failed to decode GitHub response", ERROR)
end

-- File operations
function M.todo_file_created(path)
    vim.notify("Created new todo file at: " .. path, INFO)
end

function M.todo_file_creation_failed(path)
    vim.notify("Failed to create todo file at: " .. path, ERROR)
end

function M.save_changes_first()
    vim.notify("Save your changes first", WARN)
end

-- Issue detail view
function M.no_issue_at_cursor()
    vim.notify("No issue found at cursor position", WARN)
end

function M.opening_issue_in_browser()
    vim.notify("Opening issue in browser...", INFO)
end

return M

-- Issue creation functionality
local M = {}

local utils = require("tickets.utils")
local notify = require("tickets.notifications")

-- Template for new issue buffer
local function get_issue_template()
    return {
        "---",
        "labels: []",
        "assignees: []",
        "---",
        "",
        "# Issue Title",
        "",
        "## Description",
        "",
        "Write your issue description here...",
        "",
        "## Additional Context",
        "",
        "<!-- Add any additional context, screenshots, or code examples below -->",
        "",
        "",
        "---",
        "<!-- Instructions:",
        "  1. Replace 'Issue Title' above with your issue title",
        "  2. Write your description in the Description section",
        "  3. (Optional) Add labels in frontmatter: labels: [bug, enhancement]",
        "  4. (Optional) Add assignees in frontmatter: assignees: [username]",
        "  5. Save with :w or :wq to create the issue",
        "  6. Close without saving (:q!) to cancel",
        "-->",
    }
end

-- Parse the issue from the buffer content
-- @param lines table: Array of buffer lines
-- @return table|nil: { title, body, labels, assignees } or nil if invalid
local function parse_issue_from_buffer(lines)
    local title = nil
    local body_lines = {}
    local labels = {}
    local assignees = {}
    local in_frontmatter = false
    local in_body = false

    for i, line in ipairs(lines) do
        -- Detect frontmatter
        if line:match("^%-%-%-$") then
            in_frontmatter = not in_frontmatter
        -- Parse frontmatter
        elseif in_frontmatter then
            -- Parse labels: labels: [bug, enhancement]
            local labels_str = line:match("^labels:%s*%[(.*)%]")
            if labels_str then
                for label in labels_str:gmatch("[^,]+") do
                    local trimmed = label:match("^%s*(.-)%s*$")
                    if trimmed ~= "" then
                        table.insert(labels, trimmed)
                    end
                end
            end
            -- Parse assignees: assignees: [username1, username2]
            local assignees_str = line:match("^assignees:%s*%[(.*)%]")
            if assignees_str then
                for assignee in assignees_str:gmatch("[^,]+") do
                    local trimmed = assignee:match("^%s*(.-)%s*$")
                    if trimmed ~= "" then
                        table.insert(assignees, trimmed)
                    end
                end
            end
        -- Skip comments
        elseif not line:match("^<!%-%-") then
            -- Look for title (first # heading)
            if not title and line:match("^#%s+(.+)") then
                title = line:match("^#%s+(.+)")
                -- Skip generic template title
                if title == "Issue Title" then
                    title = nil
                end
            -- Start collecting body after Description heading
            elseif line:match("^##%s+Description") then
                in_body = true
            -- Stop collecting at Additional Context or separator
            elseif line:match("^##%s+") or line:match("^%-%-%-") then
                if in_body then
                    in_body = false
                end
            -- Collect body lines
            elseif in_body and line ~= "" then
                table.insert(body_lines, line)
            end
        end
    end

    -- Filter out template placeholder
    body_lines = vim.tbl_filter(function(line)
        return not line:match("Write your issue description here")
    end, body_lines)

    local body = table.concat(body_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

    if not title or title == "" then
        return nil, "Issue title is required"
    end

    if not body or body == "" then
        return nil, "Issue description is required"
    end

    return {
        title = title,
        body = body,
        labels = labels,
        assignees = assignees,
    }
end

-- Create issue via gh CLI
-- @param repo string: Repository in "owner/repo" format
-- @param issue table: { title, body, labels, assignees }
-- @param callback function: Called with (issue_url, error)
local function create_issue_gh(repo, issue, callback)
    local cmd = {
        "env",
        "-u",
        "GITHUB_TOKEN",
        "gh",
        "issue",
        "create",
        "--repo",
        repo,
        "--title",
        issue.title,
        "--body",
        issue.body,
    }

    -- Add labels if provided
    if issue.labels and #issue.labels > 0 then
        for _, label in ipairs(issue.labels) do
            table.insert(cmd, "--label")
            table.insert(cmd, label)
        end
    end

    -- Add assignees if provided
    if issue.assignees and #issue.assignees > 0 then
        for _, assignee in ipairs(issue.assignees) do
            table.insert(cmd, "--assignee")
            table.insert(cmd, assignee)
        end
    end

    local stdout_data = {}
    local stderr_data = {}

    vim.fn.jobstart(cmd, {
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
                if exit_code == 0 then
                    local output = table.concat(stdout_data, "\n")
                    -- gh issue create returns the issue URL
                    local url = output:match("https://[^\n]+")
                    callback(url, nil)
                else
                    local error_msg = table.concat(stderr_data, "\n")
                    callback(nil, error_msg)
                end
            end)
        end,
    })
end

-- Open issue creation buffer
function M.open_create_buffer()
    local repo = utils.get_current_repo()
    if not repo then
        notify.repo_not_found()
        return
    end

    -- Create scratch buffer
    local buf = vim.api.nvim_create_buf(false, true)
    local lines = get_issue_template()

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].filetype = "markdown"
    vim.bo[buf].bufhidden = "wipe"

    -- Store repo in buffer variable
    vim.b[buf].tickets_repo = repo
    vim.b[buf].tickets_is_create_buffer = true

    -- Open in current window
    vim.api.nvim_set_current_buf(buf)

    -- Add keymaps for submission
    vim.keymap.set("n", "<leader>s", function()
        M.submit_issue(buf)
    end, { buffer = buf, desc = "Submit issue" })

    vim.keymap.set("n", "<CR><CR>", function()
        M.submit_issue(buf)
    end, { buffer = buf, desc = "Submit issue (press Enter twice)" })

    vim.notify("Create new issue for " .. repo .. " (<leader>s or <CR><CR> to submit, :q to cancel)", vim.log.levels.INFO)
end

-- Submit the issue from the create buffer
-- @param buf number: Buffer handle
function M.submit_issue(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return
    end

    local repo = vim.b[buf].tickets_repo
    if not repo then
        vim.notify("Error: Repository information missing", vim.log.levels.ERROR)
        return
    end

    -- Get buffer content
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    -- Parse issue
    local issue, err = parse_issue_from_buffer(lines)
    if not issue then
        vim.notify("Error: " .. (err or "Invalid issue format"), vim.log.levels.ERROR)
        return
    end

    -- Show loading message
    vim.notify("Creating issue...", vim.log.levels.INFO)

    -- Create issue
    create_issue_gh(repo, issue, function(url, error)
        if error then
            vim.notify("Failed to create issue: " .. error, vim.log.levels.ERROR)
            return
        end

        -- Success!
        vim.notify("Issue created: " .. url, vim.log.levels.INFO)

        -- Close the create buffer
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end

        -- Invalidate cache to fetch fresh data on next view
        local cache = require("tickets.cache")
        cache.invalidate(repo)

        -- Optionally open the URL in browser
        vim.fn.jobstart({ "open", url }, { detach = true })
    end)
end

return M

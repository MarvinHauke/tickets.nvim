-- Formatting utilities for displaying GitHub issues
local M = {}

-- Format a timestamp for display
-- @param iso_time string|nil: ISO 8601 timestamp from GitHub API
-- @return string: Formatted timestamp or "Unknown"
function M.format_timestamp(iso_time)
    if not iso_time then
        return "Unknown"
    end
    -- Simple format: "2023-10-27 10:00"
    return iso_time:match("(%d+-%d+-%d+T%d+:%d+)") or iso_time
end

-- Format issue details as markdown lines for preview pane
-- @param detailed_issue table: Issue object with comments from GitHub API
-- @return table: Array of formatted markdown lines
function M.format_issue_details(detailed_issue)
    local lines = {}

    -- Header
    table.insert(lines, "# " .. detailed_issue.title)
    table.insert(lines, "")
    table.insert(lines, string.format("**Issue #%d** • %s", detailed_issue.number, detailed_issue.state))
    table.insert(lines, string.format("**Author:** @%s", detailed_issue.user.login))
    table.insert(lines, string.format("**Created:** %s", M.format_timestamp(detailed_issue.created_at)))
    table.insert(lines, string.format("**Updated:** %s", M.format_timestamp(detailed_issue.updated_at)))

    -- Labels
    if detailed_issue.labels and #detailed_issue.labels > 0 then
        local label_names = {}
        for _, label in ipairs(detailed_issue.labels) do
            table.insert(label_names, label.name)
        end
        table.insert(lines, string.format("**Labels:** %s", table.concat(label_names, ", ")))
    end

    -- Assignees
    if detailed_issue.assignees and #detailed_issue.assignees > 0 then
        local assignee_names = {}
        for _, assignee in ipairs(detailed_issue.assignees) do
            table.insert(assignee_names, "@" .. assignee.login)
        end
        table.insert(lines, string.format("**Assignees:** %s", table.concat(assignee_names, ", ")))
    end

    -- URL
    table.insert(lines, string.format("**URL:** %s", detailed_issue.html_url))
    table.insert(lines, "")
    table.insert(lines, "---")
    table.insert(lines, "")

    -- Body
    if detailed_issue.body and detailed_issue.body ~= "" then
        for line in detailed_issue.body:gmatch("[^\n]+") do
            table.insert(lines, line)
        end
    else
        table.insert(lines, "*No description provided.*")
    end

    -- Comments
    if detailed_issue.comments and #detailed_issue.comments > 0 then
        table.insert(lines, "")
        table.insert(lines, "---")
        table.insert(lines, "")
        table.insert(lines, string.format("## Comments (%d)", #detailed_issue.comments))
        table.insert(lines, "")

        for _, comment in ipairs(detailed_issue.comments) do
            table.insert(lines, string.format("### @%s • %s", comment.user.login, M.format_timestamp(comment.created_at)))
            table.insert(lines, "")
            for line in comment.body:gmatch("[^\n]+") do
                table.insert(lines, line)
            end
            table.insert(lines, "")
            table.insert(lines, "---")
            table.insert(lines, "")
        end
    end

    return lines
end

-- Format issue list entry
-- @param issue table: Issue object from GitHub API
-- @return string: Formatted line for issue list
function M.format_issue_list_entry(issue)
    return string.format("#%d %s", issue.number, issue.title)
end

return M

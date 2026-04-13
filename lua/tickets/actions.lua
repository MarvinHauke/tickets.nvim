-- Issue actions: edit metadata (parsing and submission logic)
local M = {}

local github = require("tickets.github")

-- Build the editable lines for an issue (frontmatter + title + body)
-- @param issue table: Issue object from GitHub API
-- @return table: Array of lines
function M.build_edit_lines(issue)
    local cache = require("tickets.cache")
    local details = cache.get_issue_details(issue._repo or "", issue.number)

    local label_names = {}
    if issue.labels then
        for _, label in ipairs(issue.labels) do
            table.insert(label_names, type(label) == "table" and label.name or label)
        end
    end

    local assignee_names = {}
    if issue.assignees then
        for _, assignee in ipairs(issue.assignees) do
            table.insert(assignee_names, type(assignee) == "table" and assignee.login or assignee)
        end
    end

    local body_text = ""
    if details and details.body then
        body_text = details.body
    elseif issue.body then
        body_text = issue.body
    end

    local lines = {
        "---",
        "labels: [" .. table.concat(label_names, ", ") .. "]",
        "assignees: [" .. table.concat(assignee_names, ", ") .. "]",
        "---",
        "",
        "# " .. issue.title,
        "",
    }

    if body_text ~= "" then
        for line in body_text:gmatch("[^\n]*") do
            table.insert(lines, line)
        end
    end

    return lines
end

-- Parse edit buffer lines into structured data
-- @param lines table: Array of buffer lines
-- @return table|nil, string|nil: { title, body, labels, assignees } or nil with error
function M.parse_edit_buffer(lines)
    local labels = {}
    local assignees = {}
    local title = nil
    local body_lines = {}
    local in_frontmatter = false
    local past_frontmatter = false
    local past_title = false

    for _, line in ipairs(lines) do
        if line:match("^%-%-%-$") then
            if in_frontmatter then
                in_frontmatter = false
                past_frontmatter = true
            else
                in_frontmatter = true
            end
        elseif in_frontmatter then
            local labels_str = line:match("^labels:%s*%[(.*)%]")
            if labels_str then
                for label in labels_str:gmatch("[^,]+") do
                    local trimmed = label:match("^%s*(.-)%s*$")
                    if trimmed ~= "" then
                        table.insert(labels, trimmed)
                    end
                end
            end
            local assignees_str = line:match("^assignees:%s*%[(.*)%]")
            if assignees_str then
                for assignee in assignees_str:gmatch("[^,]+") do
                    local trimmed = assignee:match("^%s*(.-)%s*$")
                    if trimmed ~= "" then
                        table.insert(assignees, trimmed)
                    end
                end
            end
        elseif past_frontmatter then
            if not title and line:match("^#%s+(.+)") then
                title = line:match("^#%s+(.+)")
                past_title = true
            elseif past_title then
                table.insert(body_lines, line)
            end
        end
    end

    if not title or title == "" then
        return nil, "Issue title is required"
    end

    local body = table.concat(body_lines, "\n"):gsub("^%s+", ""):gsub("%s+$", "")

    return {
        title = title,
        body = body,
        labels = labels,
        assignees = assignees,
    }
end

-- Submit edited issue from buffer lines
-- @param repo string: Repository in "owner/repo" format
-- @param issue_number number: Issue number
-- @param lines table: Buffer lines to parse
-- @param callback function: Called with (success, error)
function M.submit_edit_from_lines(repo, issue_number, lines, callback)
    local parsed, err = M.parse_edit_buffer(lines)
    if not parsed then
        vim.notify("Error: " .. (err or "Invalid format"), vim.log.levels.ERROR)
        if callback then
            callback(false, err)
        end
        return
    end

    vim.notify("Updating issue #" .. issue_number .. "...", vim.log.levels.INFO)

    github.edit_issue(repo, issue_number, parsed, function(success, api_err)
        if callback then
            callback(success, api_err)
        end
    end)
end

return M

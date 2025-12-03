-- Background prefetching of issue details to warm up the cache
local M = {}

-- Track active prefetch jobs per buffer
local prefetch_jobs = {}

-- Prefetch issue details in the background
-- @param repo string: Repository in "owner/repo" format
-- @param issue table: Issue object to prefetch
-- @param on_complete function: Optional callback when done
local function prefetch_issue(repo, issue, on_complete)
    require("tickets.github").fetch_issue_details(repo, issue.number, function(detailed_issue, err)
        if on_complete then
            on_complete(issue.number, detailed_issue, err)
        end
    end)
end

-- Start prefetching issues in the background with a queue
-- @param list_buf number: Buffer handle of the issue list
-- @param repo string: Repository in "owner/repo" format
-- @param issues table: Array of issue objects
-- @param opts table: Options { delay = ms between fetches, max_concurrent = number }
function M.start_prefetch(list_buf, repo, issues, opts)
    opts = opts or {}
    local delay = opts.delay or 500  -- ms between fetches (keeps UI responsive)
    local max_concurrent = opts.max_concurrent or 1  -- Only 1 at a time to avoid spam

    -- Cancel existing prefetch for this buffer if any
    M.cancel_prefetch(list_buf)

    local queue = {}
    local active_count = 0
    local cache = require("tickets.cache")

    -- Build queue of issues that aren't cached yet
    for _, issue in ipairs(issues) do
        if not cache.get_issue_details(repo, issue.number) then
            table.insert(queue, issue)
        end
    end

    if #queue == 0 then
        -- Everything already cached
        return
    end

    local job = {
        stopped = false,
        total = #queue,
        completed = 0,
        queue = queue,
    }

    prefetch_jobs[list_buf] = job

    -- Process queue with delays
    local function process_next()
        -- Check if job was cancelled or buffer closed
        if job.stopped or not vim.api.nvim_buf_is_valid(list_buf) then
            prefetch_jobs[list_buf] = nil
            return
        end

        -- Check if queue is empty
        if #job.queue == 0 then
            prefetch_jobs[list_buf] = nil
            vim.schedule(function()
                vim.notify(
                    string.format("Prefetched %d issue details", job.completed),
                    vim.log.levels.INFO
                )
            end)
            return
        end

        -- Don't exceed concurrent limit
        if active_count >= max_concurrent then
            return
        end

        -- Pop next issue from queue
        local issue = table.remove(job.queue, 1)
        if not issue then
            return
        end

        active_count = active_count + 1

        -- Prefetch this issue
        prefetch_issue(repo, issue, function(issue_number, detailed_issue, err)
            active_count = active_count - 1

            if detailed_issue then
                job.completed = job.completed + 1
            end

            -- Schedule next fetch after delay
            if not job.stopped then
                vim.fn.timer_start(delay, vim.schedule_wrap(process_next))
            end
        end)

        -- Start next one if we have capacity
        if active_count < max_concurrent and #job.queue > 0 then
            vim.fn.timer_start(delay, vim.schedule_wrap(process_next))
        end
    end

    -- Start processing
    vim.schedule(process_next)
end

-- Cancel prefetch for a buffer
-- @param list_buf number: Buffer handle of the issue list
function M.cancel_prefetch(list_buf)
    if prefetch_jobs[list_buf] then
        prefetch_jobs[list_buf].stopped = true
        prefetch_jobs[list_buf] = nil
    end
end

-- Get prefetch status for a buffer
-- @param list_buf number: Buffer handle of the issue list
-- @return table|nil: Status { total, completed, in_progress } or nil
function M.get_status(list_buf)
    local job = prefetch_jobs[list_buf]
    if not job then
        return nil
    end

    return {
        total = job.total,
        completed = job.completed,
        in_progress = job.total - job.completed,
    }
end

return M

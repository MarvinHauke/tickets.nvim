-- Persistent cache storage using JSON files
local M = {}

-- Get the cache directory path
local function get_cache_dir()
    local data_dir = vim.fn.stdpath("data")
    return data_dir .. "/tickets/cache"
end

-- Ensure cache directory exists
local function ensure_cache_dir()
    local cache_dir = get_cache_dir()
    vim.fn.mkdir(cache_dir, "p")
    return cache_dir
end

-- Convert repo name to safe filename
-- "owner/repo" -> "owner_repo.json"
local function repo_to_filename(repo)
    return repo:gsub("/", "_") .. ".json"
end

-- Get full path for a repo's cache file
local function get_cache_file_path(repo)
    local cache_dir = ensure_cache_dir()
    local filename = repo_to_filename(repo)
    return cache_dir .. "/" .. filename
end

-- Load cache from disk for a specific repo
-- @param repo string: Repository in "owner/repo" format
-- @return table|nil: Cached data or nil if not found/invalid
function M.load(repo)
    local file_path = get_cache_file_path(repo)

    -- Check if file exists
    if vim.fn.filereadable(file_path) == 0 then
        return nil
    end

    -- Read file content
    local file = io.open(file_path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()

    -- Parse JSON
    local ok, data = pcall(vim.fn.json_decode, content)
    if not ok or not data then
        vim.notify("Warning: Failed to parse cache file for " .. repo, vim.log.levels.WARN)
        return nil
    end

    return data
end

-- Save cache to disk for a specific repo
-- @param repo string: Repository in "owner/repo" format
-- @param data table: Data to cache { repo, last_sync, issues, issue_details }
-- @return boolean: Success status
function M.save(repo, data)
    local file_path = get_cache_file_path(repo)

    -- Ensure directory exists
    ensure_cache_dir()

    -- Add metadata
    data.repo = repo
    data.last_sync = os.date("!%Y-%m-%dT%H:%M:%SZ") -- ISO 8601 UTC

    -- Encode to JSON
    local ok, json_str = pcall(vim.fn.json_encode, data)
    if not ok or not json_str then
        vim.notify("Error: Failed to encode cache data for " .. repo, vim.log.levels.ERROR)
        return false
    end

    -- Write to file
    local file = io.open(file_path, "w")
    if not file then
        vim.notify("Error: Failed to write cache file for " .. repo, vim.log.levels.ERROR)
        return false
    end

    file:write(json_str)
    file:close()

    return true
end

-- Delete cache file for a specific repo
-- @param repo string: Repository in "owner/repo" format
-- @return boolean: Success status
function M.delete(repo)
    local file_path = get_cache_file_path(repo)

    if vim.fn.filereadable(file_path) == 1 then
        vim.fn.delete(file_path)
        return true
    end

    return false
end

-- Clear all cache files
-- @return number: Number of files deleted
function M.clear_all()
    local cache_dir = get_cache_dir()

    if vim.fn.isdirectory(cache_dir) == 0 then
        return 0
    end

    local files = vim.fn.glob(cache_dir .. "/*.json", false, true)
    local count = 0

    for _, file in ipairs(files) do
        vim.fn.delete(file)
        count = count + 1
    end

    return count
end

-- List all cached repositories
-- @return table: Array of repo names
function M.list_repos()
    local cache_dir = get_cache_dir()

    if vim.fn.isdirectory(cache_dir) == 0 then
        return {}
    end

    local files = vim.fn.glob(cache_dir .. "/*.json", false, true)
    local repos = {}

    for _, file in ipairs(files) do
        local filename = vim.fn.fnamemodify(file, ":t:r") -- Get filename without extension
        local repo = filename:gsub("_", "/") -- Convert back to "owner/repo"
        table.insert(repos, repo)
    end

    return repos
end

-- Get cache statistics
-- @return table: { total_repos, total_size_bytes, repos = {...} }
function M.stats()
    local cache_dir = get_cache_dir()

    if vim.fn.isdirectory(cache_dir) == 0 then
        return { total_repos = 0, total_size_bytes = 0, repos = {} }
    end

    local files = vim.fn.glob(cache_dir .. "/*.json", false, true)
    local total_size = 0
    local repo_stats = {}

    for _, file in ipairs(files) do
        local size = vim.fn.getfsize(file)
        total_size = total_size + size

        local filename = vim.fn.fnamemodify(file, ":t:r")
        local repo = filename:gsub("_", "/")

        table.insert(repo_stats, {
            repo = repo,
            size_bytes = size,
            last_modified = vim.fn.getftime(file),
        })
    end

    return {
        total_repos = #files,
        total_size_bytes = total_size,
        repos = repo_stats,
    }
end

return M

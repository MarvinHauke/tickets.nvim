# Features Overview

Tickets.nvim provides two main functionalities: Local Task Management and GitHub Issue Integration.

## Local Task Management

The core feature is the ability to quickly access a TODO file without leaving your current buffer context.

*   **Command**: `:Tickets`
*   **Behavior**: Opens a floating window centered in the editor.
*   **File Handling**:
    *   If the `target_file` (default `todo.md`) exists, it is opened.
    *   If it doesn't exist, a new buffer is created pointing to that path.
*   **Safety**: The window cannot be closed with `q` if there are unsaved changes, preventing accidental data loss.

## GitHub Integration

Connects to the GitHub API to retrieve issues for your current project.

### Commands

*   **`:TicketsGithubFetch`** - Fetch issues from GitHub (uses cache if available)
*   **`:TicketsGithubRefresh`** - Fetch issues from GitHub, bypassing cache
*   **`:TicketsCacheClear [repo]`** - Clear cache for specific repo (e.g., `owner/repo`) or all repos if no argument provided
*   **`:TicketsCacheStats`** - Display cache statistics (number of cached repos, issues, and details)

### Repository Detection

Automatically detects the repository from your current git remote (`git remote get-url origin`). No configuration needed.

### Authentication

1.  **gh CLI** (Preferred): Checks if you are logged in via `gh auth status`.
2.  **GITHUB_TOKEN**: Falls back to using `curl` with this environment variable if `gh` is unavailable.

### Caching

Issues are cached in-memory during your Neovim session to improve performance and reduce API calls:

*   First fetch from a repository retrieves data from GitHub API
*   Subsequent fetches use cached data for instant access
*   Cache persists only for current session (cleared on restart)
*   Use `:TicketsGithubRefresh` to force-refresh from API
*   Use `:TicketsCacheClear` to manually invalidate cache

### Feedback & UI

*   Displays fetched issues in a clean floating window.
*   Press `<CR>` (Enter) on an issue to view full details, comments, and metadata
*   Provides system notifications (`vim.notify`) for:
    *   Success (e.g., "5 issues fetched", "Using cached issues")
    *   Empty results ("No issues found for this repository")
    *   Configuration errors (e.g., missing repo, missing auth)
    *   API/CLI errors (with specific error messages)

## User Interface

The UI is designed to be minimal:
*   **Floating Windows**: Uses Neovim's native floating window API.
*   **Borders**: Rounded borders for a modern look.
*   **Responsive**: Automatically adjusts size based on editor dimensions (approx 80% width/height).

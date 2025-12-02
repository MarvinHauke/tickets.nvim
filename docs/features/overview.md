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

Connects to the GitHub API to retrieve issues.

*   **Command**: `:GithubFetch`
*   **Authentication**: Uses the `GITHUB_TOKEN` environment variable if available. This is recommended to avoid rate limits and access private repositories.
*   **Output**: currently displays issue numbers and titles in the message area.

## User Interface

The UI is designed to be minimal:
*   **Floating Windows**: Uses Neovim's native floating window API.
*   **Borders**: Rounded borders for a modern look.
*   **Responsive**: Automatically adjusts size based on editor dimensions (approx 80% width/height).

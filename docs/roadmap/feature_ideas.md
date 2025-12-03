# 🚀 Tickets.nvim Feature Ideas & Comprehensive Roadmap

This document outlines planned features, refined concepts, and expanded ideas for the future development of **Tickets.nvim**, aiming to create a powerful, integrated issue-management tool within Neovim.

## Core Functionality Extensions (Deeper Interaction)

Enhance the basic interaction with issues directly within Neovim.

| Feature                           | Status | Refined Description                                                                                                                                                                                                   |
| :-------------------------------- | :----- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **View Issue Details & Comments** | ✅ DONE | Press `Enter` to view the full body, labels, assignees, and the **full comment history** in a split pane. ~~Add the ability to **post new comments** directly from this view.~~ (commenting not yet implemented)     |
| **Open in Browser**               | ✅ DONE | Press `gx` on an issue line to open the corresponding provider page in the default browser.                                                                                                                           |
| **Create Issue (Basic)**          | ✅ DONE | New command `:TicketsCreate` opens a structured buffer template to draft title and body before submission via gh CLI.                                                                                                 |
| **Edit Issue Metadata**           | 📝 Planned | New commands/keymaps to **edit** the issue's **title, body, labels, assignees, and milestone** from the detailed view.                                                                                                |
| **Create Issue (Advanced)**       | 📝 Planned | Extend `:TicketsCreate` to specify **labels, assignees, and milestones** before submission. Support provider-specific markdown templates.                                                                             |
| **Close/Reopen Issue**            | 📝 Planned | Toggle issue state (open/closed) directly from the list view.                                                                                                                                                         |
| **Interactive Filtering**         | 📝 Planned | Support query arguments for fetching (e.g., `:TicketsFetch label:bug assignee:@me`). **Implement a dynamic/interactive filter UI** for on-the-fly filtering and allow **saving favorite filters**.                    |
| **Post Comments**                 | 📝 Planned | Add the ability to **post new comments** directly from the detail view.                                                                                                                                               |

---

## Workflow Integration (Git & VCS Harmony)

Seamlessly integrate issue management with your git workflow.

| Feature                            | Refined Description                                                                                                                                                                                                                   |
| :--------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Branch from Issue (Smart)**      | Keymap (e.g., `<leader>tb`) to create a branch named `feature/#123-issue-title` from the selected issue. Automatically **switch to the new branch** and optionally draft a placeholder first commit message with the issue reference. |
| **Commit Message Helper (Smart)**  | Autocomplete issue references (e.g., `#123`) within commit messages. Expand to suggest **closing keywords** (`fixes #123`) and suggest **conventional commit types** (`feat:`, `fix:`) based on issue labels.                         |
| **Link Issue in Code (Clickable)** | Automatically highlight and detect issue references (e.g., `TODO: #123`, `Fixes: #456`) in code comments and make them **clickable** via a keymap (e.g., `<CR>` or `gO`) to open the issue details view.                              |
| **PR Linking**                     | Display linked Pull Requests alongside the issue in the detailed view, including the **current status** (e.g., `Open`, `Merged`, `Draft`, `Review Required`) and all relevant checks.                                                 |

### Third-Party Integration
| Feature | Refined Description |
| :--- | :--- |
| **`todo-comments.nvim` Integration** | Leverage `todo-comments.nvim` for enhanced workflow: <br/> - **Issue Conversion**: Convert `TODO` comments found by `todo-comments.nvim` directly into GitHub issues via `Tickets.nvim`. <br/> - **Enriched Highlighting**: Display issue details (title, status) as virtual text next to `TODO: #<issue_number>` comments. <br/> - **Unified Dashboard**: Create a view combining local `TODO`s from `todo-comments.nvim` and remote issues from `Tickets.nvim`. |

---

## Multi-Provider Support (Enterprise & Open Source)

Expand support beyond GitHub to other platforms.

| Provider             | Status         | Notes                                                                     |
| :------------------- | :------------- | :------------------------------------------------------------------------ |
| **GitHub**           | ✅ Implemented | Core functionality available.                                             |
| **GitLab**           | 📝 Planned     | Implementation via REST API.                                              |
| **Jira**             | 📝 Planned     | High priority for enterprise users, supporting Jira Query Language (JQL). |
| **Linear**           | 📝 Planned     | For modern, high-speed issue tracking workflows.                          |
| **Forgejo/Gitea**    | 📝 Planned     | Support for self-hosted instances.                                        |
| **Azure DevOps/TFS** | 📝 Planned     | Critical for Microsoft-centric enterprise environments.                   |

---

## Productivity Features (Efficiency & Context)

Tools to speed up navigation and context management.

| Feature                                  | Refined Description                                                                                                                                                                                |
| :--------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Telescope Integration**                | New picker `:Telescope tickets` for fuzzy searching. Allow searching across **multiple configured repositories** and searching through **cached** issues.                                          |
| **Statusline Component & Timer Control** | Display the currently active/working issue in statuslines (like `lualine`). Allow **pausing/resuming** the issue timer via a command or statusline click.                                          |
| **Issue Timer (External Integration)**   | Simple time tracking per issue directly in the editor. **Integrate with external time tracking APIs** (e.g., Toggl Track) for professional use.                                                    |
| **Offline Cache (Smart Sync)**           | Cache fetched issues locally for instant access and offline viewing. Implement **smart synchronization** (only fetch updates) and allow **pre-fetching** issues for specific repositories/queries. |
| **Notifications**                        | Utilize Neovim's `vim.notify` for **pop-up notifications** for new comments or mentions on tracked issues. Allow configuring notification filters and mute options.                                |
| **Bulk Actions**                         | Functionality to select multiple issues in the list view and apply a common action to all of them at once (e.g., change status, apply label).                                                      |

---

## Advanced Features & Project Management

Deepen the connection between code and issues, adding organizational tools.

| Feature                            | Description                                                                                                                                                                         |
| :--------------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Kanban/Board View**              | A visual representation of issues organized by status (e.g., To Do, In Progress, Done) similar to GitHub Projects or Jira Boards, rendered using a dedicated Neovim buffer.         |
| **Configuration per Project**      | Allow a local configuration file (e.g., `.tickets.lua`) in the project root to override global settings (like default repository, preferred provider) for seamless multi-repo work. |
| **Blame to Issue**                 | Enhance `git blame` functionality to show the issue linked to a specific line of code by parsing issue references from commit messages.                                             |
| **Issue to Code (Reverse Lookup)** | Show a list of files and lines where a specific issue is referenced (e.g., in a `TODO: #123` comment), displayed in a **quickfix/location list**.                                   |
| **Custom Status Mapping**          | Allow users to map provider-specific statuses (e.g., "In Review," "Awaiting Feedback") to a simpler set of internal statuses for a unified experience across different providers.   |

---

## Data Persistence & Caching Strategy

Implement a multi-layered approach to issue data management for optimal performance and offline capability.

| Phase | Feature | Status | Description |
| :--- | :--- | :----- | :--- |
| **Phase 1** | **In-Memory Cache** | ✅ DONE | Quick-win implementation: Cache fetched issues in memory for the current session. Avoid redundant API calls when navigating between issue list and details view. Invalidate cache on explicit refresh command. |
| **Phase 2** | **Persistence Layer (JSON)** | ✅ DONE | Persistent storage in `~/.local/share/nvim/tickets/cache/` directory using JSON files. One file per repository (`owner_repo.json`) for lightweight needs. Includes metadata: last sync time. Auto-loads from disk on access. |
| **Phase 2b** | **Persistence Layer (SQLite)** | 📝 Planned | Optional: Structured database for advanced querying, supporting Telescope integration and complex filters. Would enable cache freshness policy (e.g., 15min TTL) and multi-repo queries. |
| **Phase 3** | **User Notes per Issue** | 📝 Planned | Optional `.tickets/notes/` folder in project root for per-issue annotations and local context. User notes are git-trackable for team collaboration. Keep separate from cache data (cache in data dir, notes in workspace). |

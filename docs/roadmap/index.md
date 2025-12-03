# Roadmap

This document tracks the high-level goals and current progress of Tickets.nvim. For a detailed list of feature ideas and future concepts, see [Feature Ideas](feature_ideas.md).

## Completed ✅
- [x] **Dynamic Repository**: Automatically detects the current git repository for fetching issues.
- [x] **Issue UI**: Issues are displayed in a clean floating window.
- [x] **Authentication**: Support for both `gh` CLI and `GITHUB_TOKEN`.
- [x] **Issue Details**: Pressing `Enter` on an issue in the list shows the full description in a split pane.
- [x] **Browser Open**: `gx` keybinding opens the selected issue in the browser.
- [x] **Creating Issues**: `:TicketsCreate` command to draft and submit new issues directly from Neovim.
- [x] **Persistent Cache**: Issues and details are cached to disk for offline access and instant loading.
- [x] **Background Prefetching**: Issue details are prefetched in the background for smooth navigation.

## In Progress 🚧
- [ ] **Cross-platform Browser Support**: Currently uses `open` (macOS only), needs Linux/Windows support.

## Planned (High Priority) 📅
- [ ] **Filtering**: Support fetching issues with specific filters (labels, assignee).
- [ ] **Edit Issue Metadata**: Edit title, body, labels, and assignees from within Neovim.

## Future Scope 🔮
- [ ] **Multi-Provider Support**: GitLab, Jira, Linear integration.
- [ ] **Workflow Integration**: Create branches from issues, commit message helpers.

See [Feature Ideas](feature_ideas.md) for the full brainstorming list.

# Agent Guidelines

## Build Verification Rule
- **Always run `zig build` when a task or code modification is finished.**
- Verify that compilation succeeds with exit code 0 before concluding your response or reporting back to the user.
- If `zig build` produces any compile errors, fix them immediately.

## TODO & Kanban Workflow Rule
- **Purpose:** The Kanban/TODO boards (`TODO.md`, `*.todo.md`, `*.kanban.md`) are for planning and tracking substantive project features, roadmap items, refactors, and bug fixes across workstreams. Do not treat the board as a prompt logger or scratchpad—never auto-inject trivial conversational requests into a board.
- **Format Compliance:** Strictly adhere to the Markdown Kanban specification (`markdown-kanban` skill). Tasks are level-3 headings (`### <Task Title>`) containing atomic metadata, `steps:` checklists, and indented descriptions—never loose `- [ ]` bullets under column headings.
- **Task Lifecycle:**
  - When starting work on a planned task, move the entire task block from `## Backlog` / `## Todo` to `## In Progress`.
  - Check off subtasks under `steps:` (`- [x]`) as implementation progresses and is verified.
  - Keep tasks in `## In Progress` until all steps are complete, code modifications are verified with `zig build`, and the user confirms the feature or fix works as expected. Do not mark tasks as Done prematurely.


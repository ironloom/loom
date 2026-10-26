---
trigger: always_on
---

# TODO & Kanban Workflow Rule

## Purpose
The Kanban/TODO system is a project management tool for organizing, planning, and tracking substantive features, refactors, milestones, and bug fixes across project workstreams.
- **Do NOT** treat the board as a session log or scratchpad. Never automatically add trivial user requests, one-off questions, or conversational prompts to the board.
- Only create or update tasks when actively working on tracked workstreams or when the user explicitly requests task/board management.

## Board Discovery & Structure
- Search for the relevant board using `rg --files -g '*.todo.md' -g '*.kanban.md' -g 'TODO.md' -g 'todo.md'`.
- Match the board to the active workstream (e.g., `TODO.md` or a dedicated `<workstream>.todo.md`). Do not pollute unrelated boards.
- Follow the **Markdown Kanban** format specification (`markdown-kanban` skill):
  - `# <Board Title>`: Level-1 heading for the board.
  - `## <Column>`: Level-2 headings for status columns (e.g., `## Todo` / `## Backlog`, `## In Progress`, `## Blocked`, `## Done`).
  - `### <Task Title>`: Level-3 headings for task cards. Tasks are atomic blocks (heading, properties, checklist steps, fenced description) that move together.
  - **Never** add flat `- [ ] <task>` items directly under column headings. Checklists belong exclusively under the `steps:` property of a task.

## Task Properties & Description Format
Task blocks should follow the Markdown Kanban property structure:
```markdown
### <Task Title>

  - due: YYYY-MM-DD
  - tags: [tag1, tag2]
  - priority: low | medium | high
  - workload: Easy | Normal | Hard | Extreme
  - defaultExpanded: true | false
  - steps:
      - [ ] Subtask step 1
      - [x] Completed step 2
    ```md
    Fenced task description indented by 4 spaces.
    ```
```
Omit unused properties rather than adding empty placeholders.

## Task Lifecycle & Workflow
- **Starting a Task:** When picking up a planned task from `## Backlog` or `## Todo`, move the entire task block to `## In Progress`.
- **Tracking Progress:** Update the `steps:` checkboxes (change `[ ]` to `[x]`) as intermediate work is verified.
- **Adding New Tasks:** When creating a task, use the full card format with short action-oriented titles, relevant properties, concrete `steps:`, and an indented description.
- **Completion:** Move a task block to `## Done` only after all its steps are complete, code changes are verified (e.g., compilation / tests pass), and the user confirms the feature or fix works as expected. Do not mark tasks as Done prematurely.

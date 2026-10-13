---
trigger: always_on
---

# Git Rules

## General Guidelines

You can run most git commands like:
- git add
- git commit
- git log
- git diff
- etc.

But you always need to ask for permission on commands like:
- git push
- git switch
- git checkout
- etc.

## Commit Structure

Every commits title should follow this syntax:
```
<action - add/update/fix/rm/feat/chore>(<module - optional>): <short summary message>
```
The commit description should detail the exact steps taken.
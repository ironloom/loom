---
trigger: always_on
---

# Build Verification Rule

- **Always run `zig build` when a task or code modification is finished.**
- Verify that compilation succeeds with exit code 0 before concluding your response or reporting back to the user.
- If `zig build` produces any compile errors, fix them immediately.

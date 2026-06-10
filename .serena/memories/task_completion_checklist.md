# Task Completion Checklist

When a task is done, verify the following before declaring complete:

1. **New .swift files?** → run `xcodegen generate` (or use `make build`)
2. **Tests pass?** → `xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'`
3. **Build succeeds?** → `make build`
4. **Commit & push** → commit per work unit, push, open PR to main
5. **Update task tracking** → update `tasks/todo.md` and `tasks/knowledge.md` if changed
6. **ADR needed?** → create/update `docs/adr/` for architecture/policy changes

## Branch & PR
- Branch: `feature/xxx` or `fix/xxx`
- PR target: `main`

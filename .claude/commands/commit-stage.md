---
description: Commit already staged files
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git commit:*)
---

Commit the already staged files. Follow the commit message format in CLAUDE.md.

1. Check staged changes: `git diff --cached --stat`
2. Check recent commits for style reference: `git log --oneline -3`
3. Create commit with format: `[type]: description`

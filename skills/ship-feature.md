---
name: ship-feature
description: Commit, PR, review, fix, merge, and cleanup a feature branch. Use when implementation is done and ready to ship.
---

# Ship Feature

Full workflow to ship a completed feature branch: commit, PR, review, fix, merge, cleanup.

**Prerequisites:** Implementation is complete and on a feature branch (not `main`).

## Step 1: Commit

Stage relevant files and create a commit. Commit messages must be in Japanese with a conventional prefix (`feat:`, `fix:`, `chore:`, `refactor:`, etc.).

```bash
git add <files>
git commit -m "feat: パッシブツリー翻訳をi18nシステムに統合"
```

- Use `git diff` and `git status` to understand what changed before writing the message.
- Be specific in the message body about what was done and why.

## Step 2: Push and Create PR

Push the branch and create a PR on the **fork** repo. The `--repo` flag is required because the upstream remote points to `PathOfBuildingCommunity`.

```bash
git push -u origin <branch-name>

gh pr create --repo kokagex/PoB2-for-macOS --base main \
  --title "<Japanese title matching commit convention>" \
  --body "$(cat <<'EOF'
## Summary
- <1-3 bullet points describing the change>

## Changes
- `file1.lua`: <what changed>
- `file2.lua`: <what changed>

## Test plan
- [ ] <manual verification step>
- [ ] <manual verification step>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- PR title should match the main commit message style (Japanese, prefixed).
- The body uses the repo's standard template: **Summary**, **Changes** (per-file), **Test plan** (checklist).

## Step 3: Code Review

Dispatch the `superpowers:code-reviewer` subagent to review the PR diff.

```bash
BASE_SHA=$(git merge-base origin/main HEAD)
HEAD_SHA=$(git rev-parse HEAD)
```

Provide the code-reviewer with:
- What was implemented
- The plan or requirements it should satisfy
- BASE_SHA and HEAD_SHA
- Brief description

Wait for findings. Findings are categorized:
- **Critical** — Must fix before merge
- **Important** — Must fix before merge
- **Suggestion/Minor** — Optional, fix at your discretion

## Step 4: Fix Review Findings

Address all Critical and Important findings:

1. Make the fixes
2. Stage and commit: `git commit -m "fix: コードレビュー指摘対応（C1, C2, I1）"`
3. Push: `git push`

If there are only Suggestion-level findings, you may skip this step.

## Step 5: Merge PR

```bash
gh pr merge <PR-NUMBER> --repo kokagex/PoB2-for-macOS --merge --delete-branch
```

- Uses merge commit strategy (not squash or rebase).
- `--delete-branch` removes the remote branch after merge.

## Step 6: Cleanup

Switch back to main and sync:

```bash
git checkout main && git pull origin main && git branch -d <branch-name>
```

This deletes the local feature branch and ensures main is up to date.

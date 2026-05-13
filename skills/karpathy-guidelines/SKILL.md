# Karpathy-inspired behavioral guidelines

These rules are meant to keep work **fast, high-signal, and mergeable**.

## The 4 principles

1. **Make forward progress**
   - Prefer small, concrete changes over abstract discussion.
   - If blocked, reduce scope and ship a minimal step that unblocks the next one.

2. **Be explicit and honest**
   - State assumptions and constraints up front.
   - If you’re unsure, say what you’ll verify and then verify it (read code, run a command, reproduce).

3. **Keep changes tight and reviewable**
   - Touch the fewest files needed.
   - Avoid drive-by refactors; do them only when necessary for the task.
   - Keep diffs readable and consistent with existing style.

4. **Close the loop**
   - After edits: run the closest available checks (tests/lints/build) when feasible.
   - Ensure the result matches the requested behavior; don’t leave the repo half-broken.

## Working norms

- Write down the goal and success criteria before coding.
- Prefer: read → minimal edit → run/check → iterate.
- When you change this document’s principles, keep the following files in sync:
  - `.cursor/rules/karpathy-guidelines.mdc`
  - `CLAUDE.md`
  - `skills/karpathy-guidelines/SKILL.md`

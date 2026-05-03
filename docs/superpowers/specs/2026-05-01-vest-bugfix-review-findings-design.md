# Vest Bugfix Review Findings Design

**Date:** 2026-05-01

## Goal

Fix the reviewed Vest defects as a focused stabilization pass, including the low-impact startup/logging issue in `VestLocalSettings`, while preserving existing addon behavior everywhere else.

## Scope

This design covers the bugs documented in `BUGS.md`:

1. Static initialization error in `VestLocalSettings`
2. `Vest.until(..., duration = 0)` returning immediate timeout
3. `Timeout` instances not consuming shared budget on timeout
4. CLI null-dereference path for invalid `--vest-file`
5. `VestDaemonRunner` early-return cleanup leak
6. Parameterized test discovery continuing after invalid providers
7. Plugin unload clearing persisted `vest/*` project settings
8. `VestLocalRunner.run_script()` shadowing `_result_buffer`

No unrelated refactors are in scope.

## Approach Options

### Option A: Single stabilization branch

Fix all reviewed bugs in one branch, add targeted regression tests for each issue, and verify with the existing suite plus a few direct repro commands.

Pros:
- Keeps cross-cutting runtime fixes together
- Lets tests cover interactions between CLI, runner, and discovery behavior
- Matches the repo’s recent bugfix workflow

Cons:
- Slightly larger review surface than per-bug branches

### Option B: Split by subsystem

Separate fixes into multiple branches for runtime/CLI, editor integration, and test discovery.

Pros:
- Smaller diffs per branch

Cons:
- Extra overhead for branch management and repeated verification
- Some bugs cross subsystem boundaries, especially CLI/runner behavior

### Recommendation

Use Option A. The changes are small and localized, and the main engineering value is in regression coverage rather than branch separation.

## Design

### 1. Runtime and CLI error handling

- Replace eager `VestCLI.Params.new()` static construction with lazy initialization in `VestLocalSettings`.
- Make CLI execution handle `null` test results explicitly, returning a controlled failure code instead of dereferencing `null`.
- Make TAP reporting robust to absent results only through the runner path that guards against `null`; avoid widening the reporter API unless needed.
- Ensure daemon runner cleanup always occurs after host startup, including timeout and early-failure paths.

### 2. Waiting and timeout behavior

- Update `Vest.until()` so `duration == 0.0` means “wait without deadline,” matching the documented API contract.
- Preserve current timed behavior for positive durations.
- Update `Timeout.until()` so elapsed time is deducted whether the condition succeeds or the wait times out, enforcing the documented shared-deadline semantics for reusable timeout objects.

### 3. Suite discovery and single-script streaming

- Stop parameterized test discovery after invalid provider configuration:
  - missing provider: warn and skip that parameterized test
  - wrong provider return type: warn and skip that parameterized test
- Remove the local variable shadowing in `VestLocalRunner.run_script()` so `on_partial_result` emits the real suite accumulator during single-script runs.

### 4. Editor plugin lifecycle

- Preserve project settings on plugin unload/disable instead of clearing `vest/*` values from `ProjectSettings`.
- Keep command registration and UI teardown behavior unchanged.

## Testing Strategy

Add focused regression tests for:

- lazy/local-settings initialization behavior where feasible without depending on editor-only startup mechanics
- `Vest.until(..., 0.0)` waiting until a condition changes
- reusable `Timeout` budget consumption across timeout and success cases
- invalid CLI file handling returning failure instead of script errors
- invalid parameterized providers being skipped without runtime errors
- `VestLocalRunner.run_script()` emitting non-null partial results
- plugin settings preservation behavior if it can be covered in the existing test environment; otherwise verify with focused code-path inspection and command-level checks

Also run:

- the existing Vest test suite
- direct CLI repro for invalid `--vest-file`

## Risks and Constraints

- Some plugin/editor lifecycle behavior is awkward to test headlessly, so verification may need to combine automated tests with targeted direct execution.
- The local settings startup bug appears low impact today because the code recovers later; the fix should avoid changing persisted config format or initialization order beyond removing the startup error.

## Success Criteria

- The documented bugs are fixed without widening scope.
- Existing tests continue to pass.
- New regression coverage exists for the behavior-heavy fixes.
- Direct invalid CLI input fails cleanly without null-dereference script errors.

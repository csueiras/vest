# Vest Bug Review

This review focuses on runtime and behavioral defects in the addon. Findings below are either reproduced locally with Godot `4.6.2` or are direct control-flow bugs in the current implementation.

## 1. `VestLocalSettings` throws a script error during class initialization

Location: `addons/vest/vest-local-settings.gd:7`

`run_params` is initialized with `VestCLI.Params.new()` as a static variable. In practice this raises `Invalid call. Nonexistent function 'new' in base 'GDScript'` during script initialization, which I reproduced while running both `sh/test.sh` and `godot --headless -s addons/vest/cli/vest-cli.gd ...`.

Impact: every CLI/editor startup that loads `VestLocalSettings` emits a script error before any tests run. This makes the addon look broken on startup and leaves `run_params` initialization dependent on later recovery paths in `flush()`.

## 2. `Vest.until(..., duration = 0)` immediately times out instead of waiting indefinitely

Location: `addons/vest/vest-singleton.gd:40-59`

The API docs explicitly say `duration == 0.` may wait infinitely. The implementation sets `deadline := time() + duration` and then loops while `time() < deadline`. With `duration == 0`, the loop never executes and the method returns `ERR_TIMEOUT` immediately.

Impact: code using the documented "wait forever" behavior fails instantly instead. Any caller relying on `duration == 0` for frame-based waiting gets the opposite behavior.

## 3. Reusable `Timeout` objects do not enforce a shared deadline after a timeout

Location: `addons/vest/timeout.gd:12-31`

`Timeout.until()` subtracts elapsed time from `_remaining` only on success. When the wait itself times out, `_remaining` is left unchanged even though the full timeout budget was spent.

Impact: a `Timeout` advertised as "reused for multiple wait operations" does not actually share a deadline once one step times out. A sequence of waits can exceed the intended total timeout by repeatedly consuming the same remaining budget.

## 4. Invalid `--vest-file` input crashes the CLI path instead of failing cleanly

Location: `addons/vest/cli/vest-cli-runner.gd:19-30`, `addons/vest/cli/vest-cli-runner.gd:50-59`, `addons/vest/tap-reporter.gd:11-22`

I reproduced this with:

```bash
godot --headless -s addons/vest/cli/vest-cli.gd --path "$(pwd)" --vest-file res://does-not-exist.test.gd
```

`run_script_at()` returns `null` for a missing or non-test script, but `VestCLIRunner.run()` still calls `_report(params, results)` and `results.get_aggregate_status()` unconditionally. `TAPReporter.report(results)` then dereferences `suite.plan_size()` on `null`, followed by another null dereference on `get_aggregate_status()`.

Impact: invalid CLI input produces internal script errors instead of a controlled failure. In my reproduction the process also exited with code `0`, which makes CI/reporting unreliable.

## 5. `VestDaemonRunner` leaks its listening server on early failure paths

Location: `addons/vest/runner/vest-daemon-runner.gd:35-55`

`_run_with_params()` calls `_start()` and then returns early on failures such as "agent didn't connect in time" without calling `_stop()`. `_stop()` is only reached after the receive loop.

Impact: failed runs can leave `_server` listening and `_port` allocated in memory until the runner is discarded. Repeated failed runs can accumulate stale state and make subsequent debugging of daemon runs harder.

## 6. Parameterized test discovery logs warnings but still executes invalid provider paths

Location: `addons/vest/test/mixins/gather-suite-mixin.gd:71-85`

When a parameter provider is missing, the code emits a warning but still executes `await call(param_provider_name)`. When a provider returns the wrong shape, the code emits another warning but still executes `for i in range(params.size())`.

Impact: malformed parameterized tests do not fail gracefully during suite discovery. Instead, Vest proceeds into invalid calls and can throw runtime errors while building the suite, which is much harder to diagnose than a clean validation failure.

## 7. Disabling/unloading the plugin clears the project's persisted Vest settings

Location: `addons/vest/plugin.gd:61-93`

`_exit_tree()` calls `remove_settings(SETTINGS)`, which eventually calls `ProjectSettings.clear(setting.name)` for every `vest/*` setting. That removes user-customized settings such as `vest/runner_timeout`, `vest/tests_root`, and `vest/test_name_patterns`.

Impact: plugin unload/disable can wipe project configuration instead of just unregistering editor UI. This is data loss from the user's perspective and makes plugin toggling unsafe.

## 8. Single-script runs emit `null` partial results because `_result_buffer` is shadowed

Location: `addons/vest/runner/vest-local-runner.gd:4-32`, especially `:8` and `:97`

`run_script()` declares a local `var _result_buffer = VestResult.Suite.new()`, which shadows the instance field. `_run_case()` later emits `on_partial_result.emit(_result_buffer)` using the instance field, not the local variable, so partial updates for single-script runs are emitted as `null`.

Impact: consumers of `on_partial_result` cannot stream progress correctly for `run_script()` executions. The glob path initializes the instance field correctly, so behavior is inconsistent between `run_script()` and `run_glob()`.

## Resolution Notes

- Addressed on branch `bugfix/review-findings`.
- The reviewed findings were fixed on this branch, including preserving `vest/*` project settings on plugin unload.

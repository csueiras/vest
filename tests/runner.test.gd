extends VestTest

var _runner_timeout := 8.0

func get_suite_name() -> String:
	return "Runner"

func before_suite(_suite_def: VestDefs.Suite):
	_runner_timeout = ProjectSettings.get_setting("vest/runner_timeout", 8.0)
	ProjectSettings.set_setting("vest/runner_timeout", 0.05)

func after_suite(_suite_def: VestDefs.Suite):
	ProjectSettings.set_setting("vest/runner_timeout", _runner_timeout)

func test_run_script_emits_non_null_partial_results():
	var runner := VestLocalRunner.new()
	var partials: Array = []
	runner.on_partial_result.connect(func(result): partials.append(result))

	var result := await runner.run_script(load("res://tests/autoload.test.gd"))

	expect_not_null(result)
	expect_not_empty(partials)
	for partial in partials:
		expect_not_null(partial)

func test_daemon_runner_cleans_up_after_connection_timeout():
	var runner := _make_noop_daemon_runner()
	var params := VestCLI.Params.new()
	params.run_file = "res://tests/autoload.test.gd"

	var result := await runner._run_with_params(params)

	expect_null(result)
	expect_null(runner._peer)
	expect_null(runner._server)

func test_daemon_stop_is_null_safe():
	var runner := VestDaemonRunner.new()

	runner._peer = null
	runner._server = null
	runner._port = 12345

	runner._stop()

	expect_null(runner._peer)
	expect_null(runner._server)
	expect_equal(runner._port, -1)

func _make_noop_daemon_runner() -> VestDaemonRunner:
	var script := GDScript.new()
	script.source_code = """
extends "res://addons/vest/runner/vest-daemon-runner.gd"

func _launch_child_process(_params):
	pass
"""
	script.reload()

	return script.new() as VestDaemonRunner

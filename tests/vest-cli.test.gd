extends VestTest

var _local_settings_snapshot: Dictionary = {}
var _local_settings_fixture_active := false

class NullResultRunner extends VestCLIRunner:
	func _init():
		_emit_diagnostics = false

	func _run_tests(_params: VestCLI.Params) -> VestResult.Suite:
		return null

class ReportFailureRunner extends VestCLIRunner:
	func _init():
		_emit_diagnostics = false

	func _run_tests(_params: VestCLI.Params) -> VestResult.Suite:
		var result := VestResult.Suite.new()
		result.suite = VestDefs.Suite.new()
		return result

	func _report(_params: VestCLI.Params, _results: VestResult.Suite) -> bool:
		return false

func get_suite_name() -> String:
	return "VestCLI"

func before_suite(suite_def: VestDefs.Suite):
	if suite_def.name != "Local Settings":
		return

	_local_settings_fixture_active = true
	_local_settings_snapshot = _capture_local_settings()

func after_case(_case_def: VestDefs.Case):
	if not _local_settings_fixture_active:
		return

	_restore_local_settings(_local_settings_snapshot)

func after_suite(suite_def: VestDefs.Suite):
	if suite_def.name != "Local Settings":
		return

	_local_settings_snapshot = {}
	_local_settings_fixture_active = false

func suite_params():
	define("CLI Params", func():
		test("should validate missing test target", func():
			var params := VestCLI.Params.new()
			params.run_file = ""
			params.run_glob = ""

			expect_contains(params.validate(), "No tests specified!")
		)

		test("should serialize to args", func():
			# Given
			var params := VestCLI.Params.new()
			params.run_file = "foo.gd"
			params.run_glob = "*.test.gd"
			params.report_format = "tap"
			params.report_file = "vest-report.log"
			params.host = "127.0.0.1"
			params.port = 37852

			var expected: Array[String] = [
				"--vest-file", "foo.gd",
				"--vest-glob", "*.test.gd",
				"--vest-report-format", "tap",
				"--vest-report-file", "vest-report.log",
				"--vest-host", "127.0.0.1",
				"--vest-port", "37852",
				"--no-only"
			]

			# When
			var actual := params.to_args()

			# Then
			expect_equal(actual, expected)
		)

		test("should parse", func():
			# Given
			var args: Array[String] = [
				"--vest-file", "foo.gd",
				"--vest-glob", "*.test.gd",
				"--vest-report-format", "tap",
				"--vest-report-file", "vest-report.log",
				"--vest-host", "127.0.0.1",
				"--vest-port", "37852",
				"--only"
			]

			var expected := VestCLI.Params.new()
			expected.run_file = "foo.gd"
			expected.run_glob = "*.test.gd"
			expected.report_format = "tap"
			expected.report_file = "vest-report.log"
			expected.host = "127.0.0.1"
			expected.port = 37852
			expected.only_mode = Vest.__.ONLY_ENABLED

			# When
			var actual := VestCLI.Params.parse(args)

			# Then
			expect_equal(actual.to_args(), expected.to_args())
		)
	)

	define("Local Settings", func():
		test("should load persisted test glob on startup", func():
			var settings := Vest.__.LocalSettings

			settings.test_glob = "res://persisted-startup.test.gd"
			settings.run_params = VestCLI.Params.new()
			settings.flush()

			settings.test_glob = ""
			settings.run_params = null
			settings._static_init()

			expect_equal(settings.test_glob, "res://persisted-startup.test.gd")
		)

		test("should load run params without changing test glob", func():
			var settings := Vest.__.LocalSettings

			settings.test_glob = "res://persisted-run-params.test.gd"
			settings.run_params = VestCLI.Params.new()
			settings.run_params.run_file = "res://saved-run-params.test.gd"
			settings.flush()

			settings.test_glob = "res://kept-test-glob.test.gd"
			settings.run_params = null

			var params := settings.get_run_params()

			expect_equal(settings.test_glob, "res://kept-test-glob.test.gd")
			expect_equal(params.run_file, "res://saved-run-params.test.gd")
		)

		test("should tolerate invalid local settings path", func():
			var settings := Vest.__.LocalSettings
			settings._path = "/definitely/missing/.vestrc"
			settings.run_params = VestCLI.Params.new()

			expect_false(settings.flush(false))

			expect_equal(settings._read_data(), {})
		)

		test("should preserve persisted test glob when saving debug params", func():
			var settings := Vest.__.LocalSettings
			var path := settings.get_config_path()
			var custom_glob := "res://custom/**/*.test.gd"

			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_string(var_to_str({
				"test_glob": custom_glob,
				"run_params": []
			}))
			file.close()

			settings.reload()

			var params := VestCLI.Params.new()
			params.run_file = "res://tests/autoload.test.gd"
			settings.run_params = params

			expect_true(settings.flush())

			var saved_file := FileAccess.open(path, FileAccess.READ)
			var data := str_to_var(saved_file.get_as_text()) as Dictionary
			saved_file.close()

			expect_equal(data["test_glob"], custom_glob)
		)
	)

	test("should return exit code 1 when run file is missing", func():
		var runner := NullResultRunner.new()
		var params := VestCLI.Params.new()

		var exit_code := await runner.run(params)

		expect_equal(exit_code, 1)
	)

	test("should return exit code 1 when report file cannot be written", func():
		var runner := ReportFailureRunner.new()
		var params := VestCLI.Params.new()
		params.run_file = "res://tests/autoload.test.gd"

		var exit_code := await runner.run(params)

		expect_equal(exit_code, 1)
	)

	test("should clear stale peer before a no-op connect", func():
		var runner := VestCLIRunner.new()
		runner._peer = StreamPeerTCP.new()

		var params := VestCLI.Params.new()
		params.run_file = "res://tests/autoload.test.gd"
		params.host = ""
		params.port = -1

		await runner._connect(params)

		expect_null(runner._peer)
	)

func _capture_local_settings() -> Dictionary:
	var path := Vest.__.LocalSettings.get_config_path()
	var snapshot := {
		"path": path,
		"local_settings_path": Vest.__.LocalSettings._path,
		"exists": FileAccess.file_exists(path),
		"data": "",
		"test_glob": Vest.__.LocalSettings.test_glob,
		"run_params": Vest.__.LocalSettings.run_params
	}

	if snapshot["exists"]:
		var file := FileAccess.open(path, FileAccess.READ)
		snapshot["data"] = file.get_as_text()
		file.close()

	return snapshot

func _restore_local_settings(snapshot: Dictionary) -> void:
	var path := snapshot["path"] as String
	if snapshot["exists"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(snapshot["data"])
		file.close()
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	Vest.__.LocalSettings._path = snapshot["local_settings_path"]
	Vest.__.LocalSettings.test_glob = snapshot["test_glob"]
	Vest.__.LocalSettings.run_params = snapshot["run_params"]

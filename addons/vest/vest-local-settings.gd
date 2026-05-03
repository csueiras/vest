@tool
extends Object

const VEST_CLI_SCRIPT := preload("res://addons/vest/cli/vest-cli.gd")

static var _path: String

static var test_glob := "res://*.test.gd"
static var run_params: VestCLI.Params = null

static func _static_init():
	if not FileAccess.file_exists(get_config_path()):
		flush()

	reload_test_glob()

static func get_config_path() -> String:
	if not _path:
		var path_candidates := [
			ProjectSettings.globalize_path("res://.godot/.vestrc"),
			ProjectSettings.globalize_path("res://.vestrc")
		] as Array[String]

		# Find suitable directory
		for path in path_candidates:
			var directory := path.get_base_dir()

			if DirAccess.dir_exists_absolute(directory):
				_path = path
				break
	return _path

static func flush(emit_error: bool = true) -> bool:
	var data := {
		"test_glob": test_glob if test_glob else "",
		"run_params": get_run_params().to_args()
	}

	var file := FileAccess.open(get_config_path(), FileAccess.WRITE)
	if file == null:
		if emit_error:
			push_error("Couldn't write local settings!")
		return false

	file.store_string(var_to_str(data))
	file.flush()
	file.close()
	return true

static func reload() -> void:
	var data := _read_data()
	test_glob = data.get("test_glob", test_glob)
	run_params = VEST_CLI_SCRIPT.Params.parse(data.get("run_params", []))

static func get_run_params() -> VestCLI.Params:
	if run_params == null:
		reload_run_params()
		if run_params == null:
			run_params = VEST_CLI_SCRIPT.Params.new()
	return run_params

static func reload_test_glob() -> void:
	var data := _read_data()
	test_glob = data.get("test_glob", test_glob)

static func reload_run_params() -> void:
	if not FileAccess.file_exists(get_config_path()):
		run_params = VEST_CLI_SCRIPT.Params.new()
		return

	var data := _read_data()
	run_params = VEST_CLI_SCRIPT.Params.parse(data.get("run_params", []))

static func _read_data() -> Dictionary:
	var file := FileAccess.open(get_config_path(), FileAccess.READ)
	if file == null:
		return {}

	var data := str_to_var(file.get_as_text()) as Dictionary
	file.close()
	return data

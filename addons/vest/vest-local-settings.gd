@tool
extends Object

const VEST_CLI_SCRIPT := preload("res://addons/vest/cli/vest-cli.gd")

static var _path: String

static var test_glob := "res://*.test.gd"
static var run_params: VestCLI.Params = null

static func _static_init():
	pass

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
				print("Found local settings path: %s" % [_path])
				break
	return _path

static func flush() -> void:
	var data := {
		"test_glob": test_glob if test_glob else "",
		"run_params": get_run_params().to_args()
	}

	var file := FileAccess.open(get_config_path(), FileAccess.WRITE)
	file.store_string(var_to_str(data))
	file.flush()
	file.close()

static func reload() -> void:
	var file := FileAccess.open(get_config_path(), FileAccess.READ)
	var data := str_to_var(file.get_as_text()) as Dictionary
	file.close()

	test_glob = data["test_glob"]
	run_params = VEST_CLI_SCRIPT.Params.parse(data["run_params"])

static func get_run_params() -> VestCLI.Params:
	if run_params == null:
		if FileAccess.file_exists(get_config_path()) and ClassDB.class_exists("VestCLI"):
			reload()
		run_params = VestCLI.Params.new()
	return run_params

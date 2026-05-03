extends RefCounted
class_name VestMockGenerator

## Generates mocks for existing scripts
##
## @tutorial(Mocks): https://foxssake.github.io/vest/latest/user-guide/mocks/

# TODO: Support getters and setters?

## Generate a mocked version of a script
func generate_mock_script(script: Script) -> Script:
	var dummy_script := preload("res://addons/vest/mocks/vest-mock-dummy.gd") as Script
	var mock_script := dummy_script.duplicate() as Script
	mock_script.source_code = generate_mock_source(script)
	mock_script.reload()

	return mock_script

## Generate the source code for mocking a script
func generate_mock_source(script: Script) -> String:
	var mock_source := PackedStringArray()

	mock_source.append("extends \"%s\"\n\n" % [script.resource_path])
	mock_source.append("var __vest_mock_handler: VestMockHandler\n\n")

	for method in _get_mock_methods(script):
		var method_name := method["name"] as String
		var args := method["args"] as Array[String]
		var arg_def_string := ", ".join(args)

		mock_source.append(
			("func %s(%s):\n" +
			"\treturn __vest_mock_handler._handle(self.%s, [%s])\n\n") %
			[method_name, arg_def_string, method_name, arg_def_string]
		)

	return "".join(mock_source)

func _get_mock_methods(script: Script) -> Array[Dictionary]:
	var methods := _normalize_reflected_methods(script.get_script_method_list())

	if script.is_abstract():
		methods.append_array(_parse_abstract_methods(script))

	return _dedupe_methods(methods)

func _normalize_reflected_methods(methods: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for method in methods:
		var method_name := method["name"] as String
		if method_name.begins_with("@"):
			continue

		var args: Array[String] = []
		for arg in method["args"]:
			args.append(arg["name"])

		result.append({
			"name": method_name,
			"args": args,
		})

	return result

func _dedupe_methods(methods: Array[Dictionary]) -> Array[Dictionary]:
	var seen := {}
	var result: Array[Dictionary] = []

	for method in methods:
		var method_name := method["name"] as String
		if seen.has(method_name):
			continue

		seen[method_name] = true
		result.append(method)

	return result

func _parse_abstract_methods(script: Script) -> Array[Dictionary]:
	var source := script.source_code
	if source.is_empty() and script.resource_path:
		var file := FileAccess.open(script.resource_path, FileAccess.READ)
		if file != null:
			source = file.get_as_text()
			file.close()

	var result: Array[Dictionary] = []
	var lines := source.split("\n")

	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		if not line.begins_with("@abstract"):
			continue

		var func_line := line
		var func_line_index := i
		if "@abstract func " not in func_line:
			var abstract_scan_result := _find_abstract_func_line(lines, i + 1, script.resource_path)
			if abstract_scan_result.is_empty():
				return []
			if not abstract_scan_result["found"]:
				continue
			func_line_index = abstract_scan_result["index"]
			func_line = abstract_scan_result["line"]

		if not func_line.begins_with("@abstract func ") and not func_line.begins_with("func "):
			continue

		var signature := func_line.trim_prefix("@abstract ").trim_prefix("func ")
		var open_paren := signature.find("(")
		if open_paren == -1:
			push_error("Unsupported abstract method signature in %s" % [script.resource_path])
			return []

		var signature_end := func_line_index
		while signature.find(")") == -1 and signature_end + 1 < lines.size():
			signature_end += 1
			signature += " " + lines[signature_end].strip_edges()

		var close_paren := signature.find(")")
		if close_paren == -1 or close_paren < open_paren:
			push_error("Unsupported abstract method signature in %s" % [script.resource_path])
			return []

		var method_name := signature.substr(0, open_paren).strip_edges()
		var raw_args := signature.substr(open_paren + 1, close_paren - open_paren - 1)
		var args: Array[String] = []

		if not raw_args.strip_edges().is_empty():
			for raw_arg in raw_args.split(","):
				var arg_name := raw_arg.strip_edges()
				if "=" in arg_name:
					arg_name = arg_name.split("=")[0].strip_edges()
				if ":" in arg_name:
					arg_name = arg_name.split(":")[0].strip_edges()
				args.append(arg_name)

		result.append({
			"name": method_name,
			"args": args,
		})

	return result

func _find_abstract_func_line(lines: PackedStringArray, start: int, resource_path: String) -> Dictionary:
	for i in range(start, lines.size()):
		var line := lines[i].strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("class_name ") or line.begins_with("extends "):
			return {
				"found": false,
			}
		if line.begins_with("@"):
			if line.begins_with("@abstract"):
				push_error("Unsupported abstract method declaration in %s" % [resource_path])
				return {}
			continue
		if line.begins_with("func "):
			return {
				"found": true,
				"index": i,
				"line": line,
			}

		push_error("Unsupported abstract method declaration in %s" % [resource_path])
		return {}

	return {
		"found": false,
	}

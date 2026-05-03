@tool
extends Object

# Serializes any data into Godot builtin types ( strings, dicts, arrays, etc. ),
# so they can be safely transmitted over the network when running tests from
# the editor.
#
# See examples/custom-data-types.test.gd

const MAX_DEPTH := 128

static func serialize(data: Variant, max_depth: int = MAX_DEPTH, emit_error: bool = true) -> Variant:
	if max_depth <= 0:
		if emit_error:
			push_error("Data structure too deep to serialize! Is there a circular reference?")
		return str(data)

	var depth := max_depth - 1

	if data == null:
		return null

	match typeof(data):
		# Numbers
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return data

		# Strings
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(data)

		# Linalg
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return [data.x, data.y]

		TYPE_VECTOR3, TYPE_VECTOR3I:
			return [data.x, data.y, data.z]

		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION:
			return [data.x, data.y, data.z, data.w]

		TYPE_RECT2, TYPE_RECT2I, TYPE_AABB:
			return [serialize(data.position, depth, emit_error), serialize(data.size, depth, emit_error)]

		TYPE_PLANE:
			var plane := data as Plane
			return [plane.x, plane.y, plane.z, plane.d, serialize(plane.normal, depth, emit_error)]

		TYPE_TRANSFORM2D:
			var xform := data as Transform2D
			return [
				serialize(xform.x, depth, emit_error),
				serialize(xform.y, depth, emit_error),
				serialize(xform.origin, depth, emit_error)
			]

		TYPE_TRANSFORM3D:
			var xform := data as Transform3D
			return [serialize(xform.basis, depth, emit_error)] + [serialize(xform.origin, depth, emit_error)]

		TYPE_BASIS:
			var basis := data as Basis
			return [
				serialize(basis.x, depth, emit_error),
				serialize(basis.y, depth, emit_error),
				serialize(basis.z, depth, emit_error)
			]

		TYPE_PROJECTION:
			var projection := data as Projection
			return [
				serialize(projection.x, depth, emit_error),
				serialize(projection.y, depth, emit_error),
				serialize(projection.z, depth, emit_error),
				serialize(projection.w, depth, emit_error)
			]

		# Other
		TYPE_COLOR:
			var color := data as Color
			return [color.r, color.g, color.b, color.a]

		TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL:
			return str(data)

		# Complex
		TYPE_OBJECT:
			var object := data as Object
			if object.has_method("_to_vest"):
				return serialize(object._to_vest(), depth, emit_error)

			return serialize(_object_to_map(object), depth, emit_error)

		# Arrays
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, \
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY:
			return serialize(Array(data), depth, emit_error)

		TYPE_ARRAY:
			var array := data as Array
			return array.map(func(it): return serialize(it, depth, emit_error))
		
		# Dictionary
		TYPE_DICTIONARY:
			var dict := data as Dictionary
			var result := {}

			for key in dict:
				var value = dict.get(key)
				result[serialize(key, max_depth - 1, emit_error)] = serialize(value, depth, emit_error)
			return result

		# Default
		_: return str(data)

static func _object_to_map(object: Object) -> Dictionary:
	var properties := object.get_property_list().map(func(prop): return prop["name"])
	var script := object.get_script() as Script

	if script != null:
		properties = script.get_script_property_list().map(func(prop): return prop["name"])

	var result := {}
	for property in properties:
		if property.contains(" "): continue # Skip invalid props
		result[property] = object.get(property)

	return result

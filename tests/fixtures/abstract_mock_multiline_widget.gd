@abstract
class_name AbstractMockMultilineWidget
extends RefCounted

@abstract func render_multiline(
	value: String,
	count: int
) -> String

func label() -> String:
	return "multiline"

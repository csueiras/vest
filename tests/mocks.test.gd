extends VestTest

const ABSTRACT_MOCK_WIDGET_SCRIPT := preload("res://tests/fixtures/abstract_mock_widget.gd")
const ABSTRACT_MOCK_TAG_SCRIPT := preload("res://tests/fixtures/abstract_mock_tag.gd")
const ABSTRACT_MOCK_MULTILINE_WIDGET_SCRIPT := preload("res://tests/fixtures/abstract_mock_multiline_widget.gd")
const ABSTRACT_MOCK_ANNOTATED_WIDGET_SCRIPT := preload("res://tests/fixtures/abstract_mock_annotated_widget.gd")

func get_suite_name() -> String:
	return "Mocks"

func _render_widget(widget: ABSTRACT_MOCK_WIDGET_SCRIPT) -> String:
	return widget.render()

func _read_tag_text(tag: ABSTRACT_MOCK_TAG_SCRIPT) -> String:
	return tag.text()

func _render_multiline_widget(widget: ABSTRACT_MOCK_MULTILINE_WIDGET_SCRIPT, value: String, count: int) -> String:
	return widget.render_multiline(value, count)

func _render_annotated_widget(widget: ABSTRACT_MOCK_ANNOTATED_WIDGET_SCRIPT, value: String, count: int) -> String:
	return widget.render_annotated(value, count)

func test_should_return_default():
	# Given
	var expected := 8.
	var math_mock := mock(SimpleMath) as SimpleMath

	when(math_mock.times).then_return(expected)

	# When
	var actual = math_mock.times(7, 1)

	# Then
	expect_equal(actual, expected)

func test_should_return_on_args():
	# Given
	var expected := 8.
	var math_mock := mock(SimpleMath) as SimpleMath

	when(math_mock.times).with_args([7, 1]).then_return(expected)

	# When
	var actual = math_mock.times(7, 1)

	# Then
	expect_equal(actual, expected)

func test_should_return_default_on_wrong_args():
	# Given
	var expected := 8.
	var math_mock := mock(SimpleMath) as SimpleMath

	when(math_mock.times).with_args([1, 2]).then_return(-1.)
	when(math_mock.times).then_return(expected)

	# When
	var actual = math_mock.times(7, 1)

	# Then
	expect_equal(actual, expected)

func test_should_answer_default():
	# Given
	var expected := 8.
	var math_mock := mock(SimpleMath) as SimpleMath

	when(math_mock.times).then_answer(func(__): return 8.)

	# When
	var actual = math_mock.times(7, 1)

	# Then
	expect_equal(actual, expected)

func test_should_answer_on_args():
	# Given
	var expected := 8.
	var math_mock := mock(SimpleMath) as SimpleMath

	when(math_mock.times).with_args([7, 1]).then_answer(func(__): return expected)

	# When
	var actual = math_mock.times(7, 1)

	# Then
	expect_equal(actual, expected)

func test_should_answer_default_on_wrong_args():
	# Given
	var expected := 8.
	var math_mock := mock(SimpleMath) as SimpleMath

	when(math_mock.times).with_args([1, 2]).then_answer(func(__): return -1.)
	when(math_mock.times).then_answer(func(__): return expected)

	# When
	var actual = math_mock.times(7, 1)

	# Then
	expect_equal(actual, expected)

func test_should_record_calls():
	# Given
	var math_mock := mock(SimpleMath) as SimpleMath
	when(math_mock.times).then_return(0.)

	# When
	math_mock.times(1, 2)
	math_mock.times(3, 4)
	math_mock.times(5, 6)

	# Then
	expect_contains(get_calls_of(math_mock.times), [1., 2.])
	expect_equal(get_calls_of(math_mock.times), [[1., 2.], [3., 4.], [5., 6.]])

func test_should_mock_abstract_method():
	# Given
	var widget_mock = mock(ABSTRACT_MOCK_WIDGET_SCRIPT)
	if widget_mock == null:
		fail("mock(AbstractMockWidget) should create a typed mock for abstract classes")
		return

	when(widget_mock.render).then_return("rendered")

	# When
	var actual = _render_widget(widget_mock)

	# Then
	expect_equal(actual, "rendered")

func test_should_mock_abstract_and_concrete_methods():
	# Given
	var widget_mock = mock(ABSTRACT_MOCK_WIDGET_SCRIPT)
	if widget_mock == null:
		fail("mock(AbstractMockWidget) should support mixed abstract and concrete API")
		return

	when(widget_mock.render).then_return("rendered")
	when(widget_mock.label).then_return("mocked label")

	# Then
	expect_equal(_render_widget(widget_mock), "rendered")
	expect_equal(widget_mock.label(), "mocked label")

func test_should_return_usable_instance_for_abstract_class_without_abstract_methods():
	# Given
	var tag_mock = mock(ABSTRACT_MOCK_TAG_SCRIPT)
	if tag_mock == null:
		fail("mock(AbstractMockTag) should create a usable typed instance")
		return

	# Then
	expect_not_null(tag_mock)

	when(tag_mock.text).then_return("mocked tag")
	expect_equal(_read_tag_text(tag_mock), "mocked tag")

func test_should_mock_multiline_abstract_method():
	# Given
	var widget_mock = mock(ABSTRACT_MOCK_MULTILINE_WIDGET_SCRIPT)
	if widget_mock == null:
		fail("mock(AbstractMockMultilineWidget) should create a typed mock for multiline abstract methods")
		return

	when(widget_mock.render_multiline).with_args(["chips", 3]).then_return("stacked")

	# When
	var actual = _render_multiline_widget(widget_mock, "chips", 3)

	# Then
	expect_equal(actual, "stacked")

func test_should_mock_annotated_abstract_method():
	# Given
	var widget_mock = mock(ABSTRACT_MOCK_ANNOTATED_WIDGET_SCRIPT)
	if widget_mock == null:
		fail("mock(AbstractMockAnnotatedWidget) should create a typed mock for annotated abstract methods")
		return

	when(widget_mock.render_annotated).with_args(["wafer", 2]).then_return("layered")

	# When
	var actual = _render_annotated_widget(widget_mock, "wafer", 2)

	# Then
	expect_equal(actual, "layered")

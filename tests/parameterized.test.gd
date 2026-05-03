extends VestTest

func get_suite_name() -> String:
	return "Parameterized"

func params_provider():
	return [
		[2, 5, 7],
		["foo", "bar", "foobar"],
		[[1, 2], [3, 0], [1, 2, 3, 0]]
	]

func test_addition(a, b, expected, _params="params_provider"):
	expect_equal(a + b, expected)

func broken_params_provider():
	return "not an array"

func test_missing_provider(_params="missing_provider"):
	fail("This test should not be registered when the provider is missing")

func test_broken_provider(_params="broken_params_provider"):
	fail("This test should not be registered when the provider is invalid")

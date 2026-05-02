extends VestTest

var _zero_duration_wait_flag := false
var _zero_duration_interval_flag := false

func get_suite_name() -> String:
	return "Coroutine"

func suite():
	# Async suite methods are supported
	await Vest.sleep()

	# And even async tests
	test("await from suite", func():
		expect_equal(await Vest.sleep(), OK)
	)

	# And async define()'s
	# NOTE: Make sure to use `await` if the define's callback is a coroutine!
	await define("await in define()", func():
		await Vest.sleep()

		# And even async tests
		test("await from suite", func():
			expect_equal(await Vest.sleep(0.05), OK)
		)
	)

	# And even async lifecycle methods
	on_begin.connect(func(): await Vest.sleep())
	on_finish.connect(func(): await Vest.sleep())

func before_all():
	await Vest.sleep(0.)

func after_all():
	await Vest.sleep(0.)

func test_await_from_method():
	expect_equal(await Vest.sleep(), OK)

func test_until_zero_duration_waits_until_condition_changes():
	_zero_duration_wait_flag = false
	Vest.get_tree().process_frame.connect(_set_zero_duration_wait_flag, CONNECT_ONE_SHOT)

	var result := await Vest.until(func():
		return _zero_duration_wait_flag
	, 0.0)

	expect_equal(result, OK)

func test_timeout_consumes_budget_after_timeout():
	var timeout := Vest.timeout(0.01, 0.0)

	var first := await timeout.until(func(): return false)
	var second := await timeout.until(func(): return true)

	expect_equal(first, ERR_TIMEOUT)
	expect_equal(second, ERR_TIMEOUT)

func test_until_zero_duration_with_interval_waits_for_interval():
	_zero_duration_interval_flag = false
	Vest.get_tree().create_timer(0.01).timeout.connect(_set_zero_duration_interval_flag, CONNECT_ONE_SHOT)

	var start := Vest.time()
	var result := await Vest.until(func():
		return _zero_duration_interval_flag
	, 0.0, 0.05)
	var elapsed := Vest.time() - start

	expect_equal(result, OK)
	expect(elapsed >= 0.04)

func _set_zero_duration_wait_flag():
	_zero_duration_wait_flag = true

func _set_zero_duration_interval_flag():
	_zero_duration_interval_flag = true

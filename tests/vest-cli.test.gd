extends VestTest

func get_suite_name() -> String:
	return "VestCLI"

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

	test("should fail cleanly when run file is missing", func():
		var runner := VestCLIRunner.new()
		var params := VestCLI.Params.new()
		params.run_file = "res://does-not-exist.test.gd"

		var exit_code := await runner.run(params)

		expect_equal(exit_code, 1)
	)

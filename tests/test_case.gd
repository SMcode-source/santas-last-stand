class_name TestCase
extends RefCounted
## Base for unit tests: collects failures instead of stopping at the first.

var failures: Array[String] = []


func check(condition: bool, message := "expected true") -> void:
	if not condition:
		failures.append(message)


func check_eq(actual: Variant, expected: Variant, message := "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s expected %s, got %s" % [message, var_to_str(expected), var_to_str(actual)])

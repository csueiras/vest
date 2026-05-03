# Abstract GDScript Mock Support

## Summary

Vest's current mock generator assumes the target script can always be instantiated by generating a subclass and calling `.new()` on it. That breaks for GDScript abstract classes introduced in Godot 4.5+, because abstract scripts cannot be instantiated directly and may declare abstract methods with no implementation.

This design adds support for mocking abstract GDScript classes while preserving the existing mocking API:

- `mock(AbstractType)` returns an instantiable object that is still a subtype of `AbstractType`
- abstract methods can be stubbed with `when(mock.some_method)...`
- existing concrete-class mocking behavior remains unchanged

The scope is limited to GDScript targets. C# abstract classes are explicitly out of scope.

## Goals

- Support `mock(script)` when `script` is an abstract GDScript class.
- Preserve subtype compatibility so callers can cast the mock to the abstract target type.
- Generate concrete implementations for abstract methods so the produced mock is instantiable.
- Keep existing concrete mock behavior stable.

## Non-Goals

- Supporting C# abstract classes.
- Building a full GDScript parser.
- Changing Vest's public mocking API.
- Adding interface-specific concepts beyond abstract-class support.

## Current Failure Mode

The generator currently emits mock source by extending the target script and generating forwarding methods based on `get_script_method_list()`. For abstract classes, this fails in two likely ways:

1. The generated subclass may still be abstract if abstract methods are not implemented.
2. Abstract methods may not appear in reflection in the same way as concrete methods, so the generator may not emit stubs for the full API.

The result is that `mock(AbstractType)` cannot reliably create a usable instance.

## Proposed Approach

Use a hybrid generation strategy:

1. Keep the current reflection-driven path for ordinary methods via `get_script_method_list()`.
2. Detect abstract targets with `script.is_abstract()`.
3. For abstract targets, parse the script source to discover abstract method declarations that need concrete generated bodies.
4. Generate concrete forwarding stubs for the union of:
   - reflected methods
   - parsed abstract method declarations

This keeps the current behavior for concrete types while adding the minimum extra machinery needed for abstract GDScript classes.

## Method Discovery

### Reflected Methods

Continue using `get_script_method_list()` as the primary source for concrete methods, since that matches current behavior and minimizes regression risk.

### Parsed Abstract Methods

When `script.is_abstract()` is true, inspect the script's source text and extract abstract method declarations from the target script.

The parser only needs to support the narrow syntax required for top-level abstract method declarations used in mocks:

- `@abstract func method_name():`
- `@abstract func method_name(arg1, arg2):`
- `@abstract func method_name()`
- `@abstract func method_name(arg1, arg2)`

The parser should ignore:

- nested functions
- non-abstract methods
- comments and unrelated annotations
- inner-class methods unless they are part of the target script surface already exposed by the script itself

The goal is not general correctness for all GDScript syntax. It is only to extract enough signature information to generate compatible mock stubs for declared abstract methods.

## Mock Source Generation

Generated mocks should remain concrete subclasses of the requested script:

- generated source still `extends` the target script
- generated source must not include `@abstract`
- each discovered method gets a generated body that delegates to `__vest_mock_handler._handle(...)`

For abstract methods, the generated stub body acts as the concrete implementation required for instantiation.

If a method is discovered from both reflection and parsing, emit it only once. Deduping should use the method name as the primary key, since Vest's current mock API is method-name-based and GDScript does not support overloads in this context.

## Compatibility

This design preserves current API expectations:

- `var mock_value := mock(MyType) as MyType` should continue to work
- `when(mock_value.some_method)...` should work for both concrete and abstract methods
- call recording via `get_calls_of(mock_value.some_method)` should keep working

No API changes are required for users.

## Error Handling

If source parsing fails to discover abstract method signatures for an abstract script, mock generation should fail explicitly rather than silently generating a broken mock. A hard failure is preferable to producing a mock that looks valid but still cannot be instantiated or cannot expose the full abstract API.

The parser should therefore be narrow and strict enough to surface unsupported syntax instead of guessing.

## Testing

Add regression coverage for:

1. Abstract class with one abstract method:
   - `mock(AbstractType)` returns an instance
   - the result can be cast to `AbstractType`
   - `when(mock.abstract_method)...` returns the configured value

2. Abstract class with mixed API:
   - one abstract method
   - one concrete method
   - both can be mocked through the existing API

3. Abstract class with no abstract methods:
   - still mockable
   - instantiation succeeds

4. Existing concrete mocks:
   - current `tests/mocks.test.gd` remains green

The tests should be written first and should fail before the generator changes are made.

## Implementation Outline

- Add abstract-target detection to `VestMockGenerator`.
- Add a helper that extracts abstract method signatures from GDScript source.
- Merge reflected and parsed methods into one normalized method-definition list.
- Generate concrete mock methods from that normalized list.
- Add regression tests covering abstract-class mocking behavior.

## Risks

- GDScript source parsing can become brittle if the implementation tries to handle too much syntax.
- Reflection and parsed results may differ in argument metadata shape; normalization needs to be explicit.
- Abstract methods declared in less common formatting styles may require either support or a clear failure mode.

## Recommendation

Implement the hybrid reflection-plus-source-parsing approach. It is the smallest change that preserves current behavior, supports the interface-style abstract-class use case, and avoids turning the mock generator into a full parser.

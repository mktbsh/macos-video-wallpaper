# Code Style & Conventions

## Swift Version
Swift 6.0 with strict concurrency checking.

## Naming
- Types: `UpperCamelCase`
- Methods/properties: `lowerCamelCase`
- Callbacks/closures: `onXxxChanged` pattern
- Test methods: `snake_case` describing behavior (e.g., `fill_rawValue_is_fill`)

## Concurrency
- `@MainActor` on all UI classes (class-level annotation)
- Async work wrapped in `Task { }`
- `nonisolated` used where needed (e.g., static `main()`)
- `MainActor.assumeIsolated { }` for bootstrap code

## Type Design
- `final class` for concrete types
- Protocol-oriented: define protocols (e.g., `WallpaperWindowControlling`) for testability
- `enum` for value types with fixed cases (DimLevel, PowerSavingMode, VideoGravity)
- `private` / `private(set)` for encapsulation

## Code Organization
- `// MARK: -` sections to organize code within files
- Minimal comments — only when WHY is non-obvious
- No docstrings/multi-line comment blocks

## No Extra Patterns
- No error handling for impossible cases
- No backwards-compat shims
- No abstractions beyond what the task requires

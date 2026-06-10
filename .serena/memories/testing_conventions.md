# Testing Conventions

## Framework
Swift Testing (`import Testing`, NOT XCTest)

## Key Macros
- `#expect(...)` - assertion (non-fatal)
- `#require(...)` - assertion (fatal, stops test on failure)
- `@Test` - marks a test function
- `@Suite` - marks a test suite struct

## Critical Rules
- **UserDefaults tests**: MUST use `@Suite(.serialized)` to prevent race conditions from parallel execution
- TDD workflow: write test → confirm failure → implement → confirm green
- Use `@testable import VideoWallpaper`
- Clean up UserDefaults with `defer { UserDefaults.standard.removeObject(forKey: "...") }`

## Test File Location
`Tests/VideoWallpaperTests/`

## Run Tests
```bash
xcodebuild test -scheme VideoWallpaper -destination 'platform=macOS'
```

## Example Pattern
```swift
@Suite(.serialized) struct MyTests {
    @Test func some_behavior_description() {
        #expect(someValue == expectedValue)
    }
}
```

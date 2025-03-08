# AgentWorld Development Guidelines

## Build & Test Commands
- Build: `Cmd+B` in Xcode
- Run app: `Cmd+R` in Xcode
- Run all tests: `Cmd+U` in Xcode
- Run single test: Select test method and click test diamond icon in gutter or use Product > Perform Action > Test

## Code Style
- **Imports**: Group by framework (SwiftUI, SpriteKit, etc.)
- **Naming**: PascalCase for types (structs, classes, enums), camelCase for properties/methods
- **Parameters**: Use named parameters for clarity
- **Tests**: Prefix test methods with "test", use @MainActor for UI tests
- **Formatting**: Follow standard Swift formatting conventions
- **Documentation**: Document public APIs with /// comments
- **Error Handling**: Use Swift's Result type or try/catch with descriptive error messages
- **Testing**: Use SwiftTesting for all tests, never use XCTest (refer to included SwiftTesting documentation, if needed)

## Project Structure
- Main app: `AgentWorld/`  
- Unit tests: `AgentWorldTests/`
- UI tests: `AgentWorldUITests/`
- Server specification: `agentworld_server_spec.md`
- SwiftTesting documentation: `swifttesting_documentation.md`
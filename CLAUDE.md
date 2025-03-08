# AgentWorld Development Guidelines

## Build & Test Commands
- Build: `Cmd+B` in Xcode
- Run app: `Cmd+R` in Xcode
- Run all tests: `Cmd+U` in Xcode
- Run single test: Select test method and click test diamond icon in gutter or use Product > Perform Action > Test

### Command Line Build & Test Commands
- Build from command line: `xcodebuild -project AgentWorld.xcodeproj -scheme AgentWorld -destination 'platform=macOS' build`
- Run tests from command line: `xcodebuild test -project AgentWorld.xcodeproj -scheme AgentWorld -destination 'platform=macOS'`
- Clean build folder: `xcodebuild clean -project AgentWorld.xcodeproj -scheme AgentWorld`
- Build specific target: `xcodebuild -project AgentWorld.xcodeproj -target AgentWorld -configuration Debug build`
- Build and archive: `xcodebuild -project AgentWorld.xcodeproj -scheme AgentWorld archive -archivePath ./build/AgentWorld.xcarchive`

## Code Style
- **Imports**: Group by framework (SwiftUI, SpriteKit, etc.)
- **Naming**: PascalCase for types (structs, classes, enums), camelCase for properties/methods
- **Parameters**: Use named parameters for clarity
- **Tests**: Use SwiftTesting with `@Suite` and `@Test` annotations
- **Formatting**: Follow standard Swift formatting conventions
- **Documentation**: Document public APIs with /// comments
- **Error Handling**: Use Swift's Result type or try/catch with descriptive error messages
- **Testing**: Use SwiftTesting for all tests (refer to included SwiftTesting documentation, if needed)

## Project Structure
- Main app: `AgentWorld/`
  - `AgentWorldApp.swift`: Main app entry point
  - `ContentView.swift`: Main view container
  - `WorldScene.swift`: SpriteKit scene coordinator 
  - `TileRenderer.swift`: Handles tile texture rendering
  - `WorldRenderer.swift`: Manages world rendering in the scene
  - `InputHandler.swift`: Processes user input
  - `TileType.swift`: Defines different terrain types
  - `World.swift`: Manages world generation and data
- Unit tests: `AgentWorldTests/`
  - `AgentWorldTests.swift`: Base model tests
  - `TileRendererTests.swift`: Tests for tile rendering
  - `WorldRendererTests.swift`: Tests for world rendering
  - `InputHandlerTests.swift`: Tests for input handling
  - `WorldSceneTests.swift`: Tests for the scene controller

Refer to these specs if you are confused about goals:
- Server specification: `agentworld_server_spec.md`
- CLI agent specification: `agentworld_agent_spec.md`

Refer to this documentation when adding tests:
- SwiftTesting documentation: `swifttesting_documentation.md`
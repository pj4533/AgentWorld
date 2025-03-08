# 🌎 AgentWorld 🤖

A simulation environment for autonomous agents to interact, learn, and evolve in procedurally generated worlds.

## 🚀 Features

- 🏞️ Procedurally generated terrain (mountains, forests, deserts, swamps, water)
- 🎮 Interactive SpriteKit-based visualization
- ⏱️ Time-based simulation with controls
- 🔌 Client-server architecture for agent connectivity
- 📊 Real-time agent state monitoring

## 🏗️ Project Structure

AgentWorld consists of two main components:

### 🖥️ Server Application

The macOS application acts as the simulation environment and server:

- Generates and renders the world
- Manages the simulation lifecycle
- Handles TCP connections from agents
- Renders agent activities in real-time

### 🤖 Agent CLI

The command-line interface for agents to connect to the simulation:

- Swift Package Manager-based CLI tool
- Network connectivity to the server
- Agent behavior implementation
- Cross-platform compatibility

## 🛠️ Getting Started

### Prerequisites

- macOS 15+ for the server application
- Swift 6.0+ for agent development
- Xcode 15+ for development

### Building the Server

1. Open `AgentWorld.xcodeproj` in Xcode
2. Build and run the project (⌘+R)

### Building the Agent CLI

```bash
cd agent
swift build
swift run
```

## 🧪 Testing

Run the test suite to verify functionality:

```bash
xcodebuild test -project AgentWorld.xcodeproj -scheme AgentWorld -destination 'platform=macOS'
```

## 📖 Documentation

See specification documents for detailed information:
- [Server Specification](agentworld_server_spec.md)
- [Agent Specification](agentworld_agent_spec.md)

## 🔮 Future Plans

- 🧠 Advanced AI agent capabilities

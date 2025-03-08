
# 4. Code Generation Prompts

Below are **all** of the incremental steps we described, each with a dedicated prompt to feed into a code-generation LLM. Use these in sequence, verifying code correctness and integration at each stage.

We’ll separate them into two sections: **Server** (`AgentWorld`) and **Agent** (`agent`). Each prompt is marked with triple backticks and a `text` code fence to emphasize that these are text prompts, not code that should be compiled.

---

## 4.1 Server: `AgentWorld` Prompts

### **Prompt 1: Project Setup**

```text
You are a code-generation AI. Please create a new macOS SwiftUI app project named "AgentWorld". In Xcode, I want:

1. A SwiftUI App entry point file called `AgentWorldApp.swift`.
2. A minimal `ContentView.swift` that just displays "Hello AgentWorld" for now.

Make sure the project will run on macOS using Swift 5 (no iOS or Combine). Provide the complete file contents for both files, plus any necessary configuration to compile and run. Exclude Info.plist or build settings. Only provide Swift source code.
```

### **Prompt 2: Add SpriteKit View**

```text
Please extend the "AgentWorld" macOS SwiftUI project by adding a SpriteKit scene. 

Steps:
1. Create a Swift file named "WorldScene.swift" that subclasses SKScene and simply displays a red background.
2. In `ContentView.swift`, embed this SKScene in a SwiftUI NSViewRepresentable called `SpriteKitContainer`.
3. Place the container in the ContentView's body. 

No Combine, no external dependencies. Provide the updated `ContentView.swift` and the new `WorldScene.swift`.
```

### **Prompt 3: World Data Structure and Generation**

```text
Now let's implement a `TileType` enum and a `World` struct for a 64x64 grid. We'll also add a function to generate tiles organically, respecting these percentages:

- Trees: 20%
- Mountains: 10%
- Water: 20%
- Grass: 30%
- Swamp: 10%
- Desert: 10%

1. Create `TileType` enum.
2. Create `World` struct with a 2D array of `TileType`.
3. Write a `func generateWorld()` that uses random seeding and expansion to cluster each tile type. 
4. In `WorldScene`, load a `World` instance in `didMove(to:)` and create SKSpriteNodes for each tile. 
5. Use different placeholder colors for each tile type. 

Provide the updated `WorldScene.swift`, plus any new files needed. Keep everything minimal but functional.
```

### **Prompt 4: Basic Simulation Controls**

```text
Add simulation timing and UI controls:

1. Introduce a @State var `currentTimeStep` in `ContentView` (or a ViewModel). 
2. Create a timer that fires every X seconds (default 60s) to increment `currentTimeStep`. 
3. Add a pause/play button that toggles whether we increment the time step. 
4. Show the current time step in a text label. 
5. Convert the time step to in-world time (5 minutes per step) and show "Day X, HH:MM".

Update the relevant SwiftUI files. Use async/await if needed, but no Combine. Provide the new or changed code.
```

### **Prompt 5: Networking (TCP Listener) and Agent Registry**

```text
Set up a TCP server in `AgentWorld`. Use the Network framework (NWListener) to accept connections on port 8000 by default. 

1. Create a `ServerConnectionManager` class or struct.
2. Start listening on app launch.
3. On new connection, store it in a dictionary keyed by some generated agent ID (e.g., "agent-xxx").
4. For now, just read incoming data, parse it as JSON, and print to console, using OSLog.
5. Maintain an `agentPositions` dictionary for agent IDs, which we’ll fill once we get the agent’s initial data.

Provide the new code or files (e.g., `ServerConnectionManager.swift`). Show how you integrate it in `AgentWorldApp.swift`.
```

### **Prompt 6: Movement & State Updates**

```text
Now let's handle real agent messages:

1. When an agent connects, assign them a random tile location that's not water/mountain.
2. Each time step, send each agent a JSON with:
   {
     "agent_id": "...",
     "currentLocation": {...},
     "surroundings": {
       "tiles": [...],
       "agents": [...]
     },
     "timeStep": ...
   }
3. If the agent sends an action like move, validate if it's passable and unoccupied. If valid, update their position. If invalid, send an error JSON.

We already have the world map, so implement a function `surroundings(for agentID: String) -> [TileInfo]` that returns the local tiles around that agent. Provide code changes in `ServerConnectionManager` and wherever else necessary.
```

### **Prompt 7: Polishing & Error Handling**

```text
Finish up the server side:

1. Implement explicit error JSON if agent attempts an invalid move.
2. Add a UI slider to control real-world seconds per timestep (range 1–120).
3. Show each agent in the SpriteKit view with a colored sprite. 
4. Optionally display a placeholder speech bubble.

Provide the final updated code for all relevant files, with a brief explanation of the changes. 
```


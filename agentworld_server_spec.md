# Specification: AI-Driven Agent Simulation


## Server Application Specification

### Overview
A macOS application built using SwiftUI and SpriteKit to visualize and manage a simulated pixel-art world with AI-driven agents.

### World and Visual Representation
- **Map Size:** `64x64` tiles
- **Tile Types & Percentages:**
  - Trees: `20%`, Mountains: `10%`, Water: `20%`, Grass: `30%`, Swamp: `10%`, Desert: `10%`
- **Movement Restrictions:** Mountains & water impassable; others no penalty
- **Resources:**
  - Trees: yield wood
  - Mountains: yield stone
  - No initial resource depletion/regeneration (future enhancement)

### Agent Representation
- Single icon, differentiated by randomly-assigned color
- Speech bubble with emoji for ongoing conversations
- Perception range: 3 tiles

### Movement Rules
- One tile per timestep
- Movement in any direction, including diagonals
- Server prevents multiple agents occupying a single tile
- Water & mountains impassable

### Simulation Timing
- **In-world:** `5 minutes` per timestep
- **Real-world:** default 60s per step, adjustable via UI
- Explicit time display ("Day X HH:MM (Total steps)")

### UI Controls
- SpriteKit viewport with constrained panning, zoom min = whole map, zoom max = 5x5 tiles
- Pause/Play simulation button
- Real-world timestep adjustment control

### Communication Protocol
- Single configurable TCP port for agent connections
- JSON-formatted communication

### Communication Protocol
- Agent initial connection handled identically to regular time-step updates

### JSON Example (Server → Agent)
```json
{
  "agent_id": "agent-123",
  "currentLocation": {"x": 10, "y": 20},
  "surroundings": {
    "tiles": [{"type": "tree", "coordinates": [19, 19]}],
    "agents": [{"id": "agent-2", "coordinates": [21, 21]}]
  },
  "timeStep": 0
}
```

### Error Handling
- Reject invalid agent actions explicitly with error JSON:
```json
{
  "action": "error",
  "reason": "Invalid move: target tile [x, y] is impassable.",
  "timeStep": 1234
}
```

### Constants (Configurable)
- World size, timestep intervals, perception range, and other simulation constants stored explicitly in code.

---

# End of Specification


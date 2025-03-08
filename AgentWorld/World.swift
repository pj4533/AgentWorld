//
//  World.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct World {
    static let size = 64
    var tiles: [[TileType]]
    
    init() {
        // Initialize with empty tiles
        tiles = Array(repeating: Array(repeating: .grass, count: World.size), count: World.size)
    }
    
    static func generateWorld() -> World {
        var world = World()
        
        // First fill the world with grass (base terrain)
        for y in 0..<size {
            for x in 0..<size {
                world.tiles[y][x] = .grass
            }
        }
        
        // Calculate target counts for each terrain type based on distribution
        let totalTiles = size * size
        var targetCounts: [TileType: Int] = [:]
        for (type, percentage) in TileType.distribution {
            targetCounts[type] = Int(Double(totalTiles) * percentage)
        }
        
        // Reserve grass tiles (no need to explicitly generate them)
        var remainingTiles = totalTiles
        remainingTiles -= targetCounts[.grass] ?? 0
        
        // Allocate tiles for each terrain feature
        // Water: One large ocean (60-70% of water) + small lakes
        let waterTarget = targetCounts[.water] ?? 0
        let oceanSize = Int(Double(waterTarget) * Double.random(in: 0.6...0.7))
        let lakesSize = waterTarget - oceanSize
        
        // Generate features with appropriate sizes
        generateOcean(size: oceanSize, in: &world)
        generateLakes(size: lakesSize, in: &world)
        generateMountainRanges(count: Int.random(in: 1...2), targetSize: targetCounts[.mountains] ?? 0, in: &world)
        generateForests(count: Int.random(in: 1...3), targetSize: targetCounts[.trees] ?? 0, in: &world)
        generateDeserts(count: Int.random(in: 1...2), targetSize: targetCounts[.desert] ?? 0, in: &world)
        generateSwamps(count: Int.random(in: 1...2), targetSize: targetCounts[.swamp] ?? 0, in: &world)
        
        return world
    }
    
    private static func generateOcean(size targetSize: Int, in world: inout World) {
        // Place ocean with irregular shape
        let oceanCenterX = Int.random(in: 5..<size-5)
        let oceanCenterY = Int.random(in: 5..<size-5)
        
        // Calculate base radius based on target size
        // Area of circle = π*r²
        let baseRadius = Int(sqrt(Double(targetSize) / Double.pi)) + 3 // Add some padding
        
        // Create initial ocean shape
        var oceanTiles: [(Int, Int)] = []
        for y in 0..<size {
            for x in 0..<size {
                let distance = sqrt(pow(Double(x - oceanCenterX), 2) + pow(Double(y - oceanCenterY), 2))
                // Use noise to create irregular coastline
                let noiseValue = Double.random(in: 0.7...1.3)
                if distance < Double(baseRadius) * noiseValue {
                    oceanTiles.append((x, y))
                }
            }
        }
        
        // Trim or expand to match target size
        if oceanTiles.count > targetSize {
            // Remove furthest tiles
            oceanTiles.sort { a, b in
                let distA = sqrt(pow(Double(a.0 - oceanCenterX), 2) + pow(Double(a.1 - oceanCenterY), 2))
                let distB = sqrt(pow(Double(b.0 - oceanCenterX), 2) + pow(Double(b.1 - oceanCenterY), 2))
                return distA < distB
            }
            oceanTiles = Array(oceanTiles.prefix(targetSize))
        }
        
        // Place ocean tiles
        for (x, y) in oceanTiles {
            world.tiles[y][x] = .water
        }
        
        // If needed, grow ocean to match target size
        var currentSize = oceanTiles.count
        var iterations = 0
        
        while currentSize < targetSize && iterations < 100 {
            var frontier: [(Int, Int)] = []
            
            // Find edge of water
            for y in 0..<size {
                for x in 0..<size {
                    if world.tiles[y][x] == .water {
                        let neighbors = getNeighbors(x: x, y: y, world: world)
                        for neighbor in neighbors {
                            if world.tiles[neighbor.y][neighbor.x] != .water {
                                frontier.append((neighbor.x, neighbor.y))
                            }
                        }
                    }
                }
            }
            
            // Shuffle frontier to grow in random directions
            frontier.shuffle()
            
            // Grow until we reach target size
            for (x, y) in frontier {
                if currentSize >= targetSize {
                    break
                }
                if world.tiles[y][x] != .water {
                    world.tiles[y][x] = .water
                    currentSize += 1
                }
            }
            
            iterations += 1
        }
    }
    
    private static func generateLakes(size targetSize: Int, in world: inout World) {
        // Create 2-4 smaller lakes
        let lakeCount = min(Int.random(in: 2...4), targetSize / 10 + 1) // Make sure we don't create too many small lakes
        let sizePerLake = targetSize / lakeCount
        
        for i in 0..<lakeCount {
            // Find location away from existing water
            var lakeCenterX = Int.random(in: 5..<size-5)
            var lakeCenterY = Int.random(in: 5..<size-5)
            var attempts = 0
            
            // Try to place lake away from ocean
            while attempts < 10 {
                let tooCloseToWater = isCloseToTerrainType(x: lakeCenterX, y: lakeCenterY, type: .water, radius: 10, world: world)
                if !tooCloseToWater {
                    break
                }
                lakeCenterX = Int.random(in: 5..<size-5)
                lakeCenterY = Int.random(in: 5..<size-5)
                attempts += 1
            }
            
            // Calculate lake radius based on target size
            let lakeSize = min(sizePerLake, targetSize - (i * sizePerLake))
            let baseRadius = Int(sqrt(Double(lakeSize) / Double.pi))
            
            // Create lake with irregular shape
            var lakeTiles: [(Int, Int)] = []
            for y in max(0, lakeCenterY - baseRadius*2)..<min(size, lakeCenterY + baseRadius*2) {
                for x in max(0, lakeCenterX - baseRadius*2)..<min(size, lakeCenterX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - lakeCenterX), 2) + pow(Double(y - lakeCenterY), 2))
                    let noiseValue = Double.random(in: 0.6...1.4) // More variation for lakes
                    if distance < Double(baseRadius) * noiseValue {
                        lakeTiles.append((x, y))
                    }
                }
            }
            
            // Trim if needed
            if lakeTiles.count > lakeSize {
                lakeTiles.sort { a, b in
                    let distA = sqrt(pow(Double(a.0 - lakeCenterX), 2) + pow(Double(a.1 - lakeCenterY), 2))
                    let distB = sqrt(pow(Double(b.0 - lakeCenterX), 2) + pow(Double(b.1 - lakeCenterY), 2))
                    return distA < distB
                }
                lakeTiles = Array(lakeTiles.prefix(lakeSize))
            }
            
            // Place lake tiles
            for (x, y) in lakeTiles {
                world.tiles[y][x] = .water
            }
        }
    }
    
    private static func isCloseToTerrainType(x: Int, y: Int, type: TileType, radius: Int, world: World) -> Bool {
        for checkY in max(0, y - radius)..<min(size, y + radius) {
            for checkX in max(0, x - radius)..<min(size, x + radius) {
                if world.tiles[checkY][checkX] == type {
                    return true
                }
            }
        }
        return false
    }
    
    private static func generateMountainRanges(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per range
        let sizePerRange = targetSize / count
        var totalMountainTiles = 0
        
        for _ in 0..<count {
            // Start point for the mountain range
            let startX = Int.random(in: 5..<size-5)
            let startY = Int.random(in: 5..<size-5)
            
            // Direction and length of the range (adjust based on target size)
            let angle = Double.random(in: 0..<2 * Double.pi)
            let length = Int(sqrt(Double(sizePerRange))) + Int.random(in: 2...5)
            
            // Track mountain tiles for this range
            var mountainTiles: [(Int, Int)] = []
            
            // Create the mountain range along a line
            for i in 0..<length {
                let x = startX + Int(Double(i) * cos(angle))
                let y = startY + Int(Double(i) * sin(angle))
                
                // Check bounds
                if x >= 0 && x < size && y >= 0 && y < size {
                    mountainTiles.append((x, y))
                    
                    // Add some width to the mountain range
                    let width = max(1, Int(sqrt(Double(sizePerRange) / Double(length))))
                    for w in 1...width {
                        let wx = x + Int(Double(w) * cos(angle + Double.pi/2))
                        let wy = y + Int(Double(w) * sin(angle + Double.pi/2))
                        
                        if wx >= 0 && wx < size && wy >= 0 && wy < size {
                            mountainTiles.append((wx, wy))
                        }
                        
                        let wx2 = x + Int(Double(w) * cos(angle - Double.pi/2))
                        let wy2 = y + Int(Double(w) * sin(angle - Double.pi/2))
                        
                        if wx2 >= 0 && wx2 < size && wy2 >= 0 && wy2 < size {
                            mountainTiles.append((wx2, wy2))
                        }
                    }
                }
            }
            
            // Remove duplicates by using a dictionary as a set (since tuples aren't Hashable)
            var uniqueTiles: [String: (Int, Int)] = [:]
            for tile in mountainTiles {
                let key = "\(tile.0),\(tile.1)"
                uniqueTiles[key] = tile
            }
            mountainTiles = Array(uniqueTiles.values)
            
            // Limit to target size
            let rangeTargetSize = min(sizePerRange, targetSize - totalMountainTiles)
            if mountainTiles.count > rangeTargetSize {
                mountainTiles.shuffle()
                mountainTiles = Array(mountainTiles.prefix(rangeTargetSize))
            }
            
            // Place mountain tiles
            for (x, y) in mountainTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .mountains
                    totalMountainTiles += 1
                }
            }
            
            // If we've reached the target size, stop adding ranges
            if totalMountainTiles >= targetSize {
                break
            }
        }
        
        // If we still need more mountains, grow existing ones
        if totalMountainTiles < targetSize {
            growTerrainType(.mountains, toSize: targetSize, in: &world)
        }
    }
    
    private static func generateForests(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per forest
        let sizePerForest = targetSize / count
        var totalForestTiles = 0
        
        for _ in 0..<count {
            // Create forest center
            let centerX = Int.random(in: 5..<size-5)
            let centerY = Int.random(in: 5..<size-5)
            
            // Calculate radius based on target size
            // Area of circle = π*r²
            let baseRadius = Int(sqrt(Double(sizePerForest) / Double.pi))
            
            // Track forest tiles
            var forestTiles: [(Int, Int)] = []
            
            // Create a forest with random edges
            for y in max(0, centerY - baseRadius*2)..<min(size, centerY + baseRadius*2) {
                for x in max(0, centerX - baseRadius*2)..<min(size, centerX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                    let randomFactor = Double.random(in: 0.7...1.3)
                    
                    if distance < Double(baseRadius) * randomFactor {
                        forestTiles.append((x, y))
                    }
                }
            }
            
            // Limit to target size
            let forestTargetSize = min(sizePerForest, targetSize - totalForestTiles)
            if forestTiles.count > forestTargetSize {
                forestTiles.shuffle()
                forestTiles = Array(forestTiles.prefix(forestTargetSize))
            }
            
            // Place forest tiles
            for (x, y) in forestTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .trees
                    totalForestTiles += 1
                    
                    if totalForestTiles >= targetSize {
                        break
                    }
                }
            }
            
            if totalForestTiles >= targetSize {
                break
            }
        }
        
        // If we still need more forest, grow existing ones
        if totalForestTiles < targetSize {
            growTerrainType(.trees, toSize: targetSize, in: &world)
        }
    }
    
    private static func generateDeserts(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per desert
        let sizePerDesert = targetSize / count
        var totalDesertTiles = 0
        
        for _ in 0..<count {
            // Create desert center
            let centerX = Int.random(in: 5..<size-5)
            let centerY = Int.random(in: 5..<size-5)
            
            // Calculate radius based on target size
            let baseRadius = Int(sqrt(Double(sizePerDesert) / Double.pi))
            
            // Track desert tiles
            var desertTiles: [(Int, Int)] = []
            
            // Create a desert with softer edges
            for y in max(0, centerY - baseRadius*2)..<min(size, centerY + baseRadius*2) {
                for x in max(0, centerX - baseRadius*2)..<min(size, centerX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                    let randomFactor = Double.random(in: 0.8...1.2)
                    
                    if distance < Double(baseRadius) * randomFactor {
                        desertTiles.append((x, y))
                    }
                }
            }
            
            // Limit to target size
            let desertTargetSize = min(sizePerDesert, targetSize - totalDesertTiles)
            if desertTiles.count > desertTargetSize {
                desertTiles.shuffle()
                desertTiles = Array(desertTiles.prefix(desertTargetSize))
            }
            
            // Place desert tiles
            for (x, y) in desertTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .desert
                    totalDesertTiles += 1
                    
                    if totalDesertTiles >= targetSize {
                        break
                    }
                }
            }
            
            if totalDesertTiles >= targetSize {
                break
            }
        }
        
        // If we still need more desert, grow existing ones
        if totalDesertTiles < targetSize {
            growTerrainType(.desert, toSize: targetSize, in: &world)
        }
    }
    
    private static func generateSwamps(count: Int, targetSize: Int, in world: inout World) {
        // Calculate size per swamp
        let sizePerSwamp = targetSize / count
        var totalSwampTiles = 0
        
        for _ in 0..<count {
            // Swamps tend to be near water
            // Find a water tile to start near
            var waterTiles: [(x: Int, y: Int)] = []
            
            for y in 0..<size {
                for x in 0..<size {
                    if world.tiles[y][x] == .water {
                        waterTiles.append((x: x, y: y))
                    }
                }
            }
            
            // Calculate swamp center - either near water or random if no water
            var centerX = Int.random(in: 5..<size-5)
            var centerY = Int.random(in: 5..<size-5)
            
            if let waterTile = waterTiles.randomElement() {
                centerX = min(max(5, waterTile.x + Int.random(in: -5...5)), size-5)
                centerY = min(max(5, waterTile.y + Int.random(in: -5...5)), size-5)
            }
            
            // Calculate radius based on target size
            let baseRadius = Int(sqrt(Double(sizePerSwamp) / Double.pi))
            
            // Track swamp tiles
            var swampTiles: [(Int, Int)] = []
            
            // Create swamp with irregular shape
            for y in max(0, centerY - baseRadius*2)..<min(size, centerY + baseRadius*2) {
                for x in max(0, centerX - baseRadius*2)..<min(size, centerX + baseRadius*2) {
                    let distance = sqrt(pow(Double(x - centerX), 2) + pow(Double(y - centerY), 2))
                    let randomFactor = Double.random(in: 0.6...1.4) // More irregular for swamps
                    
                    if distance < Double(baseRadius) * randomFactor {
                        swampTiles.append((x, y))
                    }
                }
            }
            
            // Limit to target size
            let swampTargetSize = min(sizePerSwamp, targetSize - totalSwampTiles)
            if swampTiles.count > swampTargetSize {
                swampTiles.shuffle()
                swampTiles = Array(swampTiles.prefix(swampTargetSize))
            }
            
            // Place swamp tiles
            for (x, y) in swampTiles {
                if world.tiles[y][x] == .grass { // Only replace grass
                    world.tiles[y][x] = .swamp
                    totalSwampTiles += 1
                    
                    if totalSwampTiles >= targetSize {
                        break
                    }
                }
            }
            
            if totalSwampTiles >= targetSize {
                break
            }
        }
        
        // If we still need more swamp, grow existing ones
        if totalSwampTiles < targetSize {
            growTerrainType(.swamp, toSize: targetSize, in: &world)
        }
    }
    
    private static func growTerrainType(_ type: TileType, toSize targetSize: Int, in world: inout World) {
        // Count current number of tiles
        var currentCount = 0
        for y in 0..<size {
            for x in 0..<size {
                if world.tiles[y][x] == type {
                    currentCount += 1
                }
            }
        }
        
        if currentCount >= targetSize {
            return // Already at or above target size
        }
        
        var iterations = 0
        while currentCount < targetSize && iterations < 100 {
            var frontier: [(Int, Int)] = []
            
            // Find edge of terrain type
            for y in 0..<size {
                for x in 0..<size {
                    if world.tiles[y][x] == type {
                        let neighbors = getNeighbors(x: x, y: y, world: world)
                        for neighbor in neighbors {
                            if world.tiles[neighbor.y][neighbor.x] == .grass {
                                frontier.append((neighbor.x, neighbor.y))
                            }
                        }
                    }
                }
            }
            
            // Shuffle frontier to grow in random directions
            frontier.shuffle()
            
            // Grow until we reach target size
            for (x, y) in frontier {
                if currentCount >= targetSize {
                    break
                }
                if world.tiles[y][x] == .grass {
                    world.tiles[y][x] = type
                    currentCount += 1
                }
            }
            
            iterations += 1
        }
    }
    
    // Remove unnecessary adjustment methods since we're now generating with target sizes from the beginning
    
    private static func getNeighbors(x: Int, y: Int, world: World) -> [(x: Int, y: Int)] {
        let directions = [
            (-1, 0), (1, 0), (0, -1), (0, 1)  // Left, Right, Up, Down
        ]
        
        var neighbors: [(x: Int, y: Int)] = []
        
        for (dx, dy) in directions {
            let newX = x + dx
            let newY = y + dy
            
            // Check bounds
            if newX >= 0 && newX < size && newY >= 0 && newY < size {
                neighbors.append((x: newX, y: newY))
            }
        }
        
        return neighbors
    }
}
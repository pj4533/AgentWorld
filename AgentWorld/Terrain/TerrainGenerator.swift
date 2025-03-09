//
//  TerrainGenerator.swift
//  AgentWorld
//
//  Created by Claude on 3/8/25.
//

import Foundation

struct TerrainGenerator {
    // MARK: - Ocean Generation
    static func generateOcean(size targetSize: Int, in world: inout World) {
        WaterTerrainGenerator.generateOcean(size: targetSize, in: &world)
    }
    
    // MARK: - Lake Generation
    static func generateLakes(size targetSize: Int, in world: inout World) {
        WaterTerrainGenerator.generateLakes(size: targetSize, in: &world)
    }
    
    // MARK: - Mountain Generation
    static func generateMountainRanges(count: Int, targetSize: Int, in world: inout World) {
        MountainTerrainGenerator.generateMountainRanges(count: count, targetSize: targetSize, in: &world)
    }
    
    // MARK: - Forest Generation
    static func generateForests(count: Int, targetSize: Int, in world: inout World) {
        ForestTerrainGenerator.generateForests(count: count, targetSize: targetSize, in: &world)
    }
    
    // MARK: - Desert Generation
    static func generateDeserts(count: Int, targetSize: Int, in world: inout World) {
        DesertTerrainGenerator.generateDeserts(count: count, targetSize: targetSize, in: &world)
    }
    
    // MARK: - Swamp Generation
    static func generateSwamps(count: Int, targetSize: Int, in world: inout World) {
        SwampTerrainGenerator.generateSwamps(count: count, targetSize: targetSize, in: &world)
    }
    
    // MARK: - Utility Methods
    static func isCloseToTerrainType(x: Int, y: Int, type: TileType, radius: Int, world: World) -> Bool {
        return TerrainUtils.isCloseToTerrainType(x: x, y: y, type: type, radius: radius, world: world)
    }
    
    static func growTerrainType(_ type: TileType, toSize targetSize: Int, in world: inout World) {
        TerrainUtils.growTerrainType(type, toSize: targetSize, in: &world)
    }
    
    static func getNeighbors(x: Int, y: Int) -> [(x: Int, y: Int)] {
        return TerrainUtils.getNeighbors(x: x, y: y)
    }
}
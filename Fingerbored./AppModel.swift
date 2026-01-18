//
//  AppModel.swift
//  Fingerbored
//
//  Created by Austin Ha on 3/15/25.
//

import Foundation
import SwiftUI
import RealityKit
import RealityKitContent

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    
    var rootEntity = Entity()
    var currentBoard: Entity?
    var skateboardEntity: Entity?
    var snowboardEntity: Entity?
    
    struct BundleAssets {
        static let
            scene = "BoardScene.usda",
            skateboardEntity = "skateboardRoot",
            snowboardEntity = "snowboardRoot"
    }
    
    var immersiveSpaceState = ImmersiveSpaceState.open
    
    var leftHanded : Bool = false
    var isSkateboard : Bool = true
    
    init() {
        Task {
            guard let skateboard = await loadFromRealityComposerPro(
                named: BundleAssets.skateboardEntity,
                fromSceneNamed: BundleAssets.scene
            ) else {
                fatalError("Unable to load asset from Reality Composer Pro project.")
            }
            
            guard let snowboard = await loadFromRealityComposerPro(
                named: BundleAssets.snowboardEntity,
                fromSceneNamed: BundleAssets.scene
            ) else {
                fatalError("Unable to load beam from Reality Composer Pro project.")
            }
            
            skateboardEntity = skateboard
            snowboardEntity = snowboard
            
            rootEntity.addChild(skateboardEntity!)
            rootEntity.addChild(snowboardEntity!)
            snowboardEntity?.isEnabled = false
            
            currentBoard = skateboardEntity
        }
    }
    
    func loadFromRealityComposerPro(named entityName: String, fromSceneNamed sceneName: String) async -> Entity? {
        var entity: Entity? = nil
        do {
            let scene = try await Entity(named: sceneName, in: realityKitContentBundle)
            entity = scene.findEntity(named: entityName)
        } catch {
            print("Error loading \(entityName) from scene \(sceneName): \(error.localizedDescription)")
        }
        return entity
    }

    func toggleBoard() {
        isSkateboard = !isSkateboard
        skateboardEntity?.isEnabled = isSkateboard
        snowboardEntity?.isEnabled = !isSkateboard
        
        currentBoard = isSkateboard ? skateboardEntity : snowboardEntity
    }
    
    func toggleHandedness() {
        leftHanded = !leftHanded
    }
}

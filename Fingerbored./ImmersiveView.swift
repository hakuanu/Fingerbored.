import ARKit
import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel
    
    @State var attachmentsProvider = AttachmentsProvider()
    
    @ObservedObject var visionPro: VisionPro
    
    var leftArmEntity = Entity()
    var rightArmEntity = Entity()

    var body: some View {
        RealityView { content, attachments in
            content.add(appModel.rootEntity)
            content.add(leftArmEntity)
            content.add(rightArmEntity)
            
            createSettingsView(for: leftArmEntity)
            createSettingsView(for: rightArmEntity)
        }
        update: { content, attachments in
            leftArmEntity.transform.matrix = visionPro.getWorldTransformOfForearm(chirality: HandAnchor.Chirality.left) ?? simd_float4x4.init()
            rightArmEntity.transform.matrix = visionPro.getWorldTransformOfForearm(chirality: HandAnchor.Chirality.right) ?? simd_float4x4.init()
            
            // left settings
            guard let leftComponent = leftArmEntity.components[SettingsViewRuntimeComponent.self] else { return }
            guard let leftAttachmentEntity = attachments.entity(for: leftComponent.attachmentTag) else { return }
            if leftAttachmentEntity.parent == nil {
                leftArmEntity.addChild(leftAttachmentEntity)
            }
            leftAttachmentEntity.setPosition([-0.2, -0.1, -0.03], relativeTo: leftArmEntity)
            leftAttachmentEntity.transform.rotation = simd_quatf(angle: 3.141592, axis: [0, 1, 0])
            leftAttachmentEntity.transform.rotation *= simd_quatf(angle: 3.141592, axis: [1, 0, 0])
            
            // right settings
            guard let rightComponent = rightArmEntity.components[SettingsViewRuntimeComponent.self] else { return }
            guard let rightAttachmentEntity = attachments.entity(for: rightComponent.attachmentTag) else { return }
            if rightAttachmentEntity.parent == nil {
                rightArmEntity.addChild(rightAttachmentEntity)
            }
            rightAttachmentEntity.setPosition([0.2, 0.1, 0.03], relativeTo: rightArmEntity)
            rightAttachmentEntity.transform.rotation = simd_quatf(angle: 3.141592, axis: [0, 1, 0])
            
            // update visibility
            if appModel.leftHanded {
                leftAttachmentEntity.isEnabled = false
                rightAttachmentEntity.isEnabled = true
                
                appModel.currentBoard?.transform.matrix = visionPro.getWorldTransformOfFingers(chirality: HandAnchor.Chirality.left) ?? simd_float4x4.init()
            } else {
                rightAttachmentEntity.isEnabled = false
                leftAttachmentEntity.isEnabled = true
                
                appModel.currentBoard?.transform.matrix = visionPro.getWorldTransformOfFingers() ?? simd_float4x4.init()
            }
        }
        attachments: {
            ForEach(attachmentsProvider.sortedTagViewPairs, id: \.tag) { pair in
                Attachment(id: pair.tag) {
                    pair.view
                }
            }
        }
        .task {
            await visionPro.start()
        }
        .task {
            await visionPro.publishHandTrackingUpdates()
        }
        .task {
            await visionPro.monitorSessionEvents()
        }
    }
    
    func createSettingsView(for entity: Entity) {
        let tag: ObjectIdentifier = entity.id
        
        let view = SettingsView().tag(tag)
        
        entity.components[SettingsViewRuntimeComponent.self] = SettingsViewRuntimeComponent(attachmentTag: tag)
        
        attachmentsProvider.attachments[tag] = AnyView(view)
    }
}

@MainActor class VisionPro: ObservableObject, @unchecked Sendable {
    let session = ARKitSession()
    let handTracking = HandTrackingProvider()
    @Published var latestHandTracking: HandsUpdates = .init(left: nil, right: nil)
    
    struct HandsUpdates {
        var left: HandAnchor?
        var right: HandAnchor?
    }
    
    func start() async {
        do {
            if HandTrackingProvider.isSupported {
                print("ARKitSession starting.")
                try await session.run([handTracking])
            }
        } catch {
            print("ARKitSession error:", error)
        }
    }
    
    func monitorSessionEvents() async {
        for await event in session.events {
            switch event {
            case .authorizationChanged(let type, let status):
                if type == .handTracking && status != .allowed {
                    // Stop the game, ask the user to grant hand tracking authorization again in Settings.
                }
            default:
                print("Session event \(event)")
            }
        }
    }
    
    func publishHandTrackingUpdates() async {
        for await update in handTracking.anchorUpdates {
            switch update.event {
            case .updated:
                let anchor = update.anchor
                
                guard anchor.isTracked else { continue }
                
                if anchor.chirality == .left {
                    latestHandTracking.left = anchor
                }
                else {
                    latestHandTracking.right = anchor
                }
            default:
                break
            }
        }
    }
    
    func getWorldTransformOfForearm(chirality: HandAnchor.Chirality = .right) -> simd_float4x4? {
        guard let handAnchor = chirality == .left ? latestHandTracking.left : latestHandTracking.right else {
            return nil
        }
        
        guard let forearm = handAnchor.handSkeleton?.joint(.forearmArm) else {
            return nil
        }
        
        return matrix_multiply(handAnchor.originFromAnchorTransform, forearm.anchorFromJointTransform)
    }
    
    func getWorldTransformOfFingers(chirality: HandAnchor.Chirality = .right) -> simd_float4x4? {
        guard let handAnchor = chirality == .left ? latestHandTracking.left : latestHandTracking.right else {
            return nil
        }
        
        // get the joints we need
        guard let pointerTip = handAnchor.handSkeleton?.joint(.indexFingerTip) else {
            return nil
        }
        guard let middleTip = handAnchor.handSkeleton?.joint(.middleFingerTip) else {
            return nil
        }
        guard let pointerKnuckle = handAnchor.handSkeleton?.joint(.indexFingerKnuckle) else {
            return nil
        }
        guard let middleKnuckle = handAnchor.handSkeleton?.joint(.middleFingerKnuckle) else {
            return nil
        }
        
        // convert to world position
        let worldPointerTip = matrix_multiply(handAnchor.originFromAnchorTransform, pointerTip.anchorFromJointTransform).columns.3.xyz
        let worldMiddleTip = matrix_multiply(handAnchor.originFromAnchorTransform, middleTip.anchorFromJointTransform).columns.3.xyz
        let worldPointerKnuckle = matrix_multiply(handAnchor.originFromAnchorTransform, pointerKnuckle.anchorFromJointTransform).columns.3.xyz
        let worldMiddleKnuckle = matrix_multiply(handAnchor.originFromAnchorTransform, middleKnuckle.anchorFromJointTransform).columns.3.xyz
        
        // find halfway points
        let halfway = (worldPointerTip - worldMiddleTip) / 2
        let halfwayPoint = worldPointerTip - halfway
        
        let halfwayKnuckle = (worldPointerKnuckle - worldMiddleKnuckle) / 2
        let halfwayPointKnuckles = worldPointerKnuckle - halfwayKnuckle
        
        // compute y axis
        let yAxis = normalize(halfwayPointKnuckles - halfwayPoint)
        
        // compute the z axis
        let zAxis = normalize(worldPointerTip - worldMiddleTip)
        
        // compute the x axis
        let xAxis = cross(yAxis, zAxis)
        
        // create the final transform for the gesture
        let transform = simd_matrix(
            SIMD4(xAxis.x, xAxis.y, xAxis.z, 0),
            SIMD4(yAxis.x, yAxis.y, yAxis.z, 0),
            SIMD4(zAxis.x, zAxis.y, zAxis.z, 0),
            SIMD4(halfwayPoint.x, halfwayPoint.y, halfwayPoint.z, 1)
        )
        return transform
    }
}

extension SIMD4 {
    var xyz: SIMD3<Scalar> {
        self[SIMD3(0, 1, 2)]
    }
}

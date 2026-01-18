//
//  FingerboredApp.swift
//  Fingerbored
//
//  Created by Austin Ha on 3/15/25.
//

import SwiftUI

@main
struct FingerboredApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView(visionPro: VisionProContainer.visionPro)
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}

@MainActor enum VisionProContainer {
    private(set) static var visionPro = VisionPro()
}

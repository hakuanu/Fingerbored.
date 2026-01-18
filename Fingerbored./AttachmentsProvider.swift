import SwiftUI
import Observation
import RealityKit

@Observable
final class AttachmentsProvider {
    var attachments: [ObjectIdentifier : AnyView] = [ : ]
    var sortedTagViewPairs: [(tag: ObjectIdentifier, view: AnyView)] {
        attachments.map { key, value in
            (tag: key, view: value)
        }.sorted { $0.tag < $1.tag }
    }
}

public struct WatchTargetRuntimeComponent : TransientComponent {
    public let attachmentTag: ObjectIdentifier
    public init(attachmentTag: ObjectIdentifier) {
        self.attachmentTag = attachmentTag
    }
}

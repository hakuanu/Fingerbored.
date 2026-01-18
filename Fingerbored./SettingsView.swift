import SwiftUI
import RealityKit
import RealityKitContent

struct SettingsViewRuntimeComponent: Component {
    let attachmentTag: ObjectIdentifier
}

struct SettingsView: View {
    @Environment(AppModel.self) var appModel
    
    enum Board: String, Equatable, CaseIterable {
        case skateboard = "skateboard"
        case snowboard = "snowboard"
    }
    
    @State var fingerboard : Board = .skateboard


    var body: some View {
        VStack {
            Text("Fingerbored")
            
            Spacer()
            
            Button("Switch hands") {
                appModel.toggleHandedness()
            }
            
            Button("Switch board") {
                appModel.toggleBoard()
            }
        }
        .frame(width: 150, height: 150, alignment: .top)
        .pickerStyle(WheelPickerStyle())
        .padding(20)
        .glassBackgroundEffect()
        

    }
}

#Preview(immersionStyle: .mixed) {
    SettingsView()
        .environment(AppModel())
}

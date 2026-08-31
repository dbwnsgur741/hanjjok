import SwiftUI
import Domain
import Data

struct PanelRootView: View {
    let model: TimelineModel

    var body: some View {
        TimelineView(model: model)
    }
}

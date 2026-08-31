import SwiftUI

struct PanelRootView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("한지").font(.largeTitle)
            Text("Task 11에서 타임라인으로 교체").font(.caption)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.98, green: 0.96, blue: 0.93))
    }
}

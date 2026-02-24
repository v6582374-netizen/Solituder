import SwiftUI

@main
struct SolituderApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = AgentAppViewModel()

    var body: some Scene {
        WindowGroup {
            RootView(viewModel: viewModel)
                .task {
                    await viewModel.bootstrap()
                }
                .onChange(of: scenePhase) { _, newValue in
                    viewModel.handleScenePhase(newValue)
                }
        }
    }
}

import SwiftUI

struct RootView: View {
    @ObservedObject var viewModel: AgentAppViewModel

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.voicePermissionsGranted == false {
                    PermissionsOnboardingView(viewModel: viewModel)
                } else if viewModel.hasRequiredKeys == false {
                    KeyManagementView(viewModel: viewModel)
                } else {
                    StandbyView(viewModel: viewModel)
                }
            }
            .navigationTitle("Solituder")
        }
        .alert("Action Failed", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isVisible in
                if isVisible == false {
                    viewModel.clearError()
                }
            }
        )) {
            Button("Key Management") {
                viewModel.clearError()
                viewModel.openKeyManagement()
            }
            Button("OK", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .sheet(isPresented: $viewModel.isKeyManagementPresented) {
            NavigationStack {
                KeyManagementView(viewModel: viewModel)
                    .navigationTitle("Key Management")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                viewModel.closeKeyManagement()
                            }
                        }
                    }
            }
        }
    }
}

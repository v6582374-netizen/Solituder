import SwiftUI

struct KeyManagementView: View {
    @ObservedObject var viewModel: AgentAppViewModel

    var body: some View {
        Form {
            Section("Provider Keys") {
                SecureField("OpenAI API Key (sk-...)", text: $viewModel.openAIKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }

            Section("Security") {
                Button("Reveal Saved Keys (Face ID / Touch ID)") {
                    Task { await viewModel.revealStoredKeys() }
                }
                Button("Save Keys to Keychain") {
                    Task { await viewModel.saveKeys() }
                }
            }

            Section("Voice Output") {
                Text("Current MVP uses on-device voice output for stability.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Current Status") {
                Label(viewModel.hasStoredOpenAIKey ? "OpenAI key saved" : "OpenAI key missing", systemImage: viewModel.hasStoredOpenAIKey ? "checkmark.shield" : "xmark.shield")
                Text(viewModel.statusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

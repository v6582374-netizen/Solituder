import SwiftUI

struct StandbyView: View {
    @ObservedObject var viewModel: AgentAppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                statusSection
                wakeWordSection
                voiceConversationSection
            }
            .padding()
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Foreground Standby")
                .font(.title3.bold())

            Text("State: \(viewModel.lifecycleStateText)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(viewModel.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("Voice output: On-device")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack {
                Button(viewModel.isArmed ? "Disarm" : "Arm") {
                    Task { await viewModel.toggleArmState() }
                }
                .buttonStyle(.borderedProminent)

                Button(viewModel.isConversing ? "End Conversation" : "Start Conversation") {
                    Task {
                        if viewModel.isConversing {
                            await viewModel.endConversation()
                        } else {
                            await viewModel.beginConversation()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isArmed == false && viewModel.isConversing == false)

                Button("Key Management") {
                    viewModel.openKeyManagement()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var wakeWordSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wake Word Model")
                .font(.headline)

            Picker("Wake Model", selection: $viewModel.selectedWakeModel) {
                ForEach(viewModel.wakeModelChoices, id: \.id) { model in
                    Text(model.title).tag(model.id)
                }
            }
            .pickerStyle(.menu)

            Text("Foreground only: app will suspend listening shortly after entering background.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var voiceConversationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Voice Conversation")
                .font(.headline)

            Text("Say your wake phrase, then speak naturally. The assistant will auto-reply by voice.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.liveTranscript.isEmpty == false {
                Text("Live Transcript")
                    .font(.subheadline.bold())
                Text(viewModel.liveTranscript)
                    .font(.body)
            }

            if viewModel.lastUserUtterance.isEmpty == false {
                Text("Last Request")
                    .font(.subheadline.bold())
                Text(viewModel.lastUserUtterance)
                    .font(.body)
            }

            if viewModel.assistantReply.isEmpty == false {
                Text("Assistant Reply")
                    .font(.subheadline.bold())
                Text(viewModel.assistantReply)
                    .font(.body)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

import SwiftUI

struct PermissionsOnboardingView: View {
    @ObservedObject var viewModel: AgentAppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Enable Core Permissions")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("For voice interactions, microphone and speech recognition are required. Notifications are optional.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(PermissionKind.allCases) { kind in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title)
                            .font(.headline)
                        Text(kind.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(viewModel.state(for: kind).title)
                            .font(.caption.bold())
                            .foregroundStyle(statusColor(viewModel.state(for: kind)))
                        Button("Request") {
                            Task { await viewModel.request(kind) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(viewModel.isRequestingPermissions)
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            HStack {
                Button("Request All") {
                    Task { await viewModel.requestAllPermissions() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isRequestingPermissions)

                Button("Open Settings") {
                    viewModel.openSystemSettings()
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding()
    }

    private func statusColor(_ state: PermissionState) -> Color {
        switch state {
        case .granted:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .notDetermined:
            return .gray
        }
    }
}

import SwiftUI

struct EmergencyHomeView: View {
    @EnvironmentObject private var model: AEDAppModel

    var body: some View {
        Group {
            switch model.mode {
            case .home:
                home
            case .withPatient:
                WithPatientView()
            case .runner:
                RunnerModeView()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VoiceControlBar()
                .environmentObject(model)
        }
        .background(Color(.systemBackground))
    }

    private var home: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PrimaryInstructionBanner(text: EmergencyCopy.primaryInstruction(settings: model.settings))

                VStack(spacing: 14) {
                    Button {
                        model.requestEmergencyCall()
                    } label: {
                        Label(model.settings.callButtonTitle, systemImage: "phone.fill")
                            .font(model.largerText ? .largeTitle.bold() : .title.bold())
                            .frame(maxWidth: .infinity, minHeight: 88)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.red)
                    .accessibilityLabel(model.settings.callButtonTitle)
                    .accessibilityInputLabels([model.settings.callButtonTitle])

                    Button {
                        model.open(.runner)
                    } label: {
                        Label("Find nearest AED", systemImage: "bolt.heart.fill")
                            .font(model.largerText ? .largeTitle.bold() : .title.bold())
                            .frame(maxWidth: .infinity, minHeight: 88)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel("Find nearest AED")
                    .accessibilityInputLabels(["Find nearest AED"])

                    Button {
                        model.open(.withPatient)
                    } label: {
                        Label("I am with the person", systemImage: "person.fill")
                            .font(model.largerText ? .largeTitle.bold() : .title.bold())
                            .frame(maxWidth: .infinity, minHeight: 104)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel("I am with the person")
                    .accessibilityInputLabels(["I am with the person"])

                    Button {
                        model.open(.runner)
                    } label: {
                        Label("I am the AED runner", systemImage: "figure.run")
                            .font(model.largerText ? .largeTitle.bold() : .title.bold())
                            .frame(maxWidth: .infinity, minHeight: 104)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityLabel("I am the AED runner")
                    .accessibilityInputLabels(["I am the AED runner"])
                }

                SafetyWarningView(text: EmergencyCopy.dataWarning, systemImage: "exclamationmark.triangle.fill")

                ForEach(model.dataSourceWarnings, id: \.self) { dataSourceWarning in
                    SafetyWarningView(text: dataSourceWarning, systemImage: "externaldrive.badge.exclamationmark")
                }

                StatusLine(text: model.statusMessage)
            }
            .padding()
            .padding(.bottom, 88)
        }
    }
}

struct PrimaryInstructionBanner: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(.systemRed).opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemRed), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(text)
    }
}

struct SafetyWarningView: View {
    var text: String
    var systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(text)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemYellow).opacity(0.18))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemOrange), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct StatusLine: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(text)
    }
}

struct VoiceControlBar: View {
    @EnvironmentObject private var model: AEDAppModel

    var body: some View {
        VStack(spacing: 8) {
            if let voiceConfirmation = model.voiceConfirmation {
                Text(voiceConfirmation)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button {
                    model.startVoiceCommands()
                } label: {
                    Label("Listen", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Listen")
                .accessibilityInputLabels(["Listen"])

                Button {
                    model.stopVoiceCommands()
                } label: {
                    Label("Stop listening", systemImage: "mic.slash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Stop listening")
                .accessibilityInputLabels(["Stop listening"])
            }

            Text(model.voiceCommandManager.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.regularMaterial)
    }
}

#Preview {
    EmergencyHomeView()
        .environmentObject(AEDAppModel(repository: StaticAEDRepository(records: [], sourceMetadata: AEDSourceMetadata(sourceName: "Preview", attributionText: nil, importedAt: nil, newestSourceUpdatedAt: nil, recordCount: 0, reliability: "unknown"))))
}

import SwiftUI

struct WithPatientView: View {
    @EnvironmentObject private var model: AEDAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PrimaryInstructionBanner(text: EmergencyCopy.primaryInstruction(settings: model.settings))

                HStack {
                    Button {
                        model.open(.home)
                    } label: {
                        Label("Home", systemImage: "house.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityInputLabels(["Home"])

                    Spacer()
                }

                Text(EmergencyCopy.withPatientInstruction)
                    .font(.largeTitle.bold())
                    .fixedSize(horizontal: false, vertical: true)

                SafetyWarningView(text: EmergencyCopy.aloneWarning, systemImage: "hand.raised.fill")

                VStack(spacing: 12) {
                    Button {
                        model.requestEmergencyCall()
                    } label: {
                        Label(model.settings.callButtonTitle, systemImage: "phone.fill")
                            .frame(maxWidth: .infinity, minHeight: 64)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel(model.settings.callButtonTitle)
                    .accessibilityInputLabels([model.settings.callButtonTitle])

                    Button {
                        model.readCPRSteps()
                    } label: {
                        Label("Read CPR/AED steps", systemImage: "speaker.wave.2.fill")
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Read CPR/AED steps")
                    .accessibilityInputLabels(["Read CPR/AED steps"])

                    Button {
                        model.open(.runner)
                    } label: {
                        Label("Show nearest AED for helper", systemImage: "figure.run")
                            .frame(maxWidth: .infinity, minHeight: 56)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Show nearest AED for helper")
                    .accessibilityInputLabels(["Show nearest AED for helper"])
                }

                if let result = model.selectedResult {
                    Text("Nearest AED for helper")
                        .font(.title.bold())
                    AEDCardView(result: result)
                }

                SafetyWarningView(text: EmergencyCopy.dataWarning, systemImage: "exclamationmark.triangle.fill")
                ForEach(model.dataSourceWarnings, id: \.self) { dataSourceWarning in
                    SafetyWarningView(text: dataSourceWarning, systemImage: "externaldrive.badge.exclamationmark")
                }
                StatusLine(text: model.dataLastUpdatedText)
                StatusLine(text: model.statusMessage)
            }
            .padding()
            .padding(.bottom, 88)
        }
    }
}

#Preview {
    WithPatientView()
        .environmentObject(AEDAppModel(repository: StaticAEDRepository(records: [], sourceMetadata: AEDSourceMetadata(sourceName: "Preview", attributionText: nil, importedAt: nil, newestSourceUpdatedAt: nil, recordCount: 0, reliability: "unknown"))))
}

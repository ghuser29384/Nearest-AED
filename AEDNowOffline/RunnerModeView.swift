import SwiftUI

struct RunnerModeView: View {
    @EnvironmentObject private var model: AEDAppModel
    @ScaledMetric(relativeTo: .largeTitle) private var distanceFontSize: CGFloat = 64
    @ScaledMetric(relativeTo: .largeTitle) private var arrowSize: CGFloat = 96
    @State private var searchText = ""

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

                    Button {
                        model.requestEmergencyCall()
                    } label: {
                        Label(model.settings.callButtonTitle, systemImage: "phone.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .accessibilityLabel(model.settings.callButtonTitle)
                    .accessibilityInputLabels([model.settings.callButtonTitle])
                }

                ForEach(model.dataSourceWarnings, id: \.self) { dataSourceWarning in
                    SafetyWarningView(text: dataSourceWarning, systemImage: "externaldrive.badge.exclamationmark")
                }

                StatusLine(text: model.dataLastUpdatedText)

                if let result = model.selectedResult {
                    runnerDisplay(for: result)
                    AEDCardView(result: result)
                    runnerControls
                } else {
                    fallbackList
                }

                StatusLine(text: model.statusMessage)
            }
            .padding()
            .padding(.bottom, 88)
        }
    }

    private func runnerDisplay(for result: AEDSearchResult) -> some View {
        VStack(spacing: 12) {
            Text(DistanceBearing.formattedDistance(result.distanceMeters))
                .font(.system(size: model.largerText ? distanceFontSize * 1.18 : distanceFontSize, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            if model.headingManager.headingDegrees != nil {
                Image(systemName: "location.north.fill")
                    .font(.system(size: arrowSize, weight: .bold))
                    .rotationEffect(.degrees(result.bearingDegrees))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text("Direction: follow arrow, \(result.directionText)")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
            } else {
                Text("Direction: \(result.directionText)")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(DistanceBearing.formattedDistance(result.distanceMeters)), \(result.directionText)")
    }

    private var runnerControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    model.previousAED()
                } label: {
                    Label("Previous AED", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedIndex == 0)
                .accessibilityLabel("Previous AED")
                .accessibilityInputLabels(["Previous AED"])

                Button {
                    model.nextAED()
                } label: {
                    Label("Next AED", systemImage: "chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(model.selectedIndex >= model.results.count - 1)
                .accessibilityLabel("Next AED")
                .accessibilityInputLabels(["Next AED"])
            }

            Button {
                model.readSelectedAED()
            } label: {
                Label("Read aloud", systemImage: "speaker.wave.2.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Read aloud")
            .accessibilityInputLabels(["Read aloud"])

            Toggle(
                "Show all AEDs",
                isOn: Binding(
                    get: { model.showAllAEDs },
                    set: { model.setShowAllAEDs($0) }
                )
            )
            .font(.headline)
            .accessibilityLabel("Show all AEDs")
            .accessibilityInputLabels(["Show all AEDs"])
        }
    }

    private var fallbackList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Location unavailable")
                .font(.largeTitle.bold())
            Text("Showing bundled AED list fallback.")
                .font(.headline)

            TextField("Search AED list", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityInputLabels(["Search AED list"])

            ForEach(filteredFallbackRecords) { record in
                AEDCardView(record: record)
            }
        }
    }

    private var filteredFallbackRecords: [AEDRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.fallbackRecords }
        return model.fallbackRecords.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query)
                || $0.displaySubtitle.localizedCaseInsensitiveContains(query)
        }
    }
}

#Preview {
    RunnerModeView()
        .environmentObject(AEDAppModel(repository: StaticAEDRepository(records: [], sourceMetadata: AEDSourceMetadata(sourceName: "Preview", attributionText: nil, importedAt: nil, newestSourceUpdatedAt: nil, recordCount: 0, reliability: "unknown"))))
}

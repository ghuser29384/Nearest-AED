import SwiftUI

struct AEDCardView: View {
    private let record: AEDRecord
    private let distanceText: String?
    private let directionText: String?

    init(result: AEDSearchResult) {
        record = result.record
        distanceText = DistanceBearing.formattedDistance(result.distanceMeters)
        directionText = result.directionText
    }

    init(record: AEDRecord) {
        self.record = record
        distanceText = nil
        directionText = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.displayTitle)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if let distanceText {
                    Text(distanceText)
                        .font(.title2.monospacedDigit().bold())
                        .minimumScaleFactor(0.6)
                }
            }

            if let directionText {
                Label(directionText, systemImage: "location.north.line")
                    .font(.headline)
            }

            if !record.displaySubtitle.isEmpty {
                Text(record.displaySubtitle)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(record.accessType.displayName, systemImage: accessSystemImage)
                .font(.headline)
                .foregroundStyle(.primary)

            if let accessInstructions = record.accessInstructions {
                Label(accessInstructions, systemImage: "info.circle")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let cabinetCodeInstruction = record.cabinetCodeInstruction {
                Label(cabinetCodeInstruction, systemImage: "lock.fill")
                    .font(.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let openingHoursRaw = record.openingHoursRaw {
                Label(openingHoursRaw, systemImage: "clock")
                    .font(.subheadline)
            }

            HStack {
                Text("Confidence: \(record.confidence.rawValue.capitalized)")
                if let lastVerifiedAt = record.lastVerifiedAt {
                    Text("Verified: \(lastVerifiedAt.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            if let attributionText = record.attributionText {
                Text(attributionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Source: \(record.source). Licence: \(record.licence?.nilIfBlank ?? "Unknown").")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private var accessSystemImage: String {
        switch record.accessType {
        case .public24h:
            return "checkmark.seal.fill"
        case .publicLimitedHours:
            return "clock.badge.exclamationmark"
        case .restricted:
            return "person.crop.circle.badge.exclamationmark"
        case .lockedCabinet:
            return "lock.fill"
        case .unknown:
            return "questionmark.circle"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    AEDCardView(record: AEDRecord(
        id: "preview",
        source: "Preview",
        sourceRecordID: "preview",
        sourceUpdatedAt: Date(),
        importedAt: Date(),
        latitude: 51.5,
        longitude: -0.12,
        name: "Preview AED",
        address: "High Street",
        locationDescription: "Inside main entrance, left wall",
        indoorLocation: "Ground floor",
        accessType: .public24h,
        openingHoursRaw: "24/7",
        isCurrentlyLikelyAccessible: true,
        accessInstructions: "Ask staff if the cabinet is closed.",
        cabinetCodeInstruction: "Call emergency services for code",
        phone: nil,
        lastVerifiedAt: Date(),
        confidence: .medium,
        notes: nil,
        attributionText: "Synthetic preview data"
    ))
}

import CodeCore
import SwiftUI

// MARK: Settings Icon Squircle Badge

/// An Apple Settings-style 28x28 squircle icon badge with vibrant gradient fill and crisp symbol.
public struct SettingsIconBadge: View {
    public let systemName: String
    public let gradient: LinearGradient

    public init(systemName: String, color: Color) {
        self.systemName = systemName
        self.gradient = LinearGradient(
            colors: [color.opacity(0.85), color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public init(systemName: String, gradient: LinearGradient) {
        self.systemName = systemName
        self.gradient = gradient
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Metric.settingsIconRadius, style: .continuous)
                .fill(gradient)
                .overlay(
                    RoundedRectangle(cornerRadius: Metric.settingsIconRadius, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 1, x: 0, y: 1)

            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: Metric.settingsIconSize, height: Metric.settingsIconSize)
    }
}

// MARK: - Clinical Taxonomy Visual Style

public extension CodeSystem {
    var iconName: String {
        switch self {
        case .icd10cm: "cross.case.fill"
        case .cpt: "list.clipboard.fill"
        case .loinc: "testtube.2"
        case .snomed: "network"
        }
    }

    var themeColor: Color {
        switch self {
        case .icd10cm: .teal
        case .cpt: .blue
        case .loinc: .cyan
        case .snomed: .purple
        }
    }

    var categorySubtitle: String {
        switch self {
        case .icd10cm: "Clinical Diagnoses"
        case .cpt: "Procedures & Clinical Services"
        case .loinc: "Laboratory & Clinical Observations"
        case .snomed: "Comprehensive Health Terminology"
        }
    }
}

// MARK: - Apple Keyboard Keycap Badge

/// A tactile macOS keycap capsule for keyboard shortcuts.
public struct KeycapBadge: View {
    public let key: String

    public init(_ key: String) {
        self.key = key
    }

    public var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: Metric.keycapRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metric.keycapRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 0.5, x: 0, y: 0.5)
    }
}

/// A group of adjacent keycaps representing a complete keyboard shortcut (e.g. ⌥⌘C).
public struct KeycapGroup: View {
    public let keys: [String]

    public init(keys: [String]) {
        self.keys = keys
    }

    public init(symbols: String) {
        self.keys = symbols.map { String($0) }
    }

    public var body: some View {
        HStack(spacing: 3) {
            ForEach(keys.indices, id: \.self) { idx in
                KeycapBadge(keys[idx])
            }
        }
    }
}

// MARK: - Status Pill

/// A compact status or metadata capsule chip.
public struct StatusPill: View {
    public let text: String
    public let systemImage: String?
    public let color: Color

    public init(text: String, systemImage: String? = nil, color: Color = .secondary) {
        self.text = text
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
    }
}

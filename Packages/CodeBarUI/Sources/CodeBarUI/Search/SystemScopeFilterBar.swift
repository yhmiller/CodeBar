import AppKit
import CodeCore
import SwiftUI

/// An interactive filter bar for scoping search queries to specific clinical coding systems.
public struct SystemScopeFilterBar: View {
    public let availableSystems: [CodeSystem]
    public let activeScope: CodeSystem?
    public let onSelectScope: (CodeSystem?) -> Void

    @State private var hoveredScope: String? = nil

    public init(
        availableSystems: [CodeSystem],
        activeScope: CodeSystem?,
        onSelectScope: @escaping (CodeSystem?) -> Void
    ) {
        self.availableSystems = availableSystems
        self.activeScope = activeScope
        self.onSelectScope = onSelectScope
    }

    public var body: some View {
        if availableSystems.count > 1 {
            HStack(spacing: Metric.xs + 1) {
                scopeChip(
                    title: "All",
                    icon: "square.grid.2x2",
                    isActive: activeScope == nil,
                    color: .primary
                ) {
                    onSelectScope(nil)
                }

                ForEach(availableSystems, id: \.self) { system in
                    scopeChip(
                        title: system.shortLabel,
                        icon: system.iconName,
                        isActive: activeScope == system,
                        color: system.themeColor,
                        tagHint: QueryScoper.defaultTag(for: system)
                    ) {
                        if activeScope == system {
                            onSelectScope(nil)
                        } else {
                            onSelectScope(system)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Metric.l)
            .padding(.bottom, Metric.s)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: activeScope)
        }
    }

    private func scopeChip(
        title: String,
        icon: String,
        isActive: Bool,
        color: Color,
        tagHint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .default)
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? (color == .primary ? Color.primary : color) : .secondary)

                Text(title)
                    .font(.system(size: 11, weight: isActive ? .semibold : .medium))
                    .foregroundStyle(isActive ? (color == .primary ? Color.primary : color) : .secondary)

                if isActive && title != "All" {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(color.opacity(0.8))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(
                RoundedRectangle(cornerRadius: Metric.chipRadius + 2, style: .continuous)
                    .fill(
                        isActive
                            ? (color == .primary ? Color.primary.opacity(0.14) : color.opacity(0.18))
                            : (hoveredScope == title ? Color.primary.opacity(0.07) : Color.primary.opacity(0.03))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metric.chipRadius + 2, style: .continuous)
                    .strokeBorder(
                        isActive
                            ? (color == .primary ? Color.primary.opacity(0.28) : color.opacity(0.55))
                            : (hoveredScope == title ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06)),
                        lineWidth: 1
                    )
            )
            .shadow(color: isActive ? color.opacity(color == .primary ? 0 : 0.22) : .clear, radius: 4, y: 1)
            .scaleEffect(hoveredScope == title && !isActive ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            withAnimation(.easeOut(duration: 0.12)) {
                hoveredScope = isHovered ? title : nil
            }
        }
        .help(tagHint != nil ? "Filter by \(title) (or type \(tagHint!))" : "Show all code sets")
        .accessibilityLabel(tagHint != nil ? "\(title) scope filter" : "All code sets")
    }
}

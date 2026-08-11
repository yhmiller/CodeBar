import SwiftUI

/// Reports how tall a list's rows actually are.
///
/// A `ScrollView` expands to whatever space it is offered rather than reporting
/// the height of its contents, so a window sizing itself to its content gets no
/// useful signal from one. Measuring the rows and clamping the scroll view to
/// `min(measured, cap)` is what lets the panel grow downwards row by row and
/// then start scrolling, instead of opening at a fixed height with dead space
/// underneath.
struct ContentHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Publishes this view's laid-out height through `ContentHeightPreferenceKey`.
    func measuringHeight() -> some View {
        background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ContentHeightPreferenceKey.self,
                    value: geometry.size.height
                )
            }
        )
    }
}

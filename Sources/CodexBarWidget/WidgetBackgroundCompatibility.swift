import SwiftUI
import WidgetKit

extension View {
    @ViewBuilder
    func codexWidgetBackground() -> some View {
        if #available(macOS 14.0, *) {
            self.containerBackground(.fill.tertiary, for: .widget)
        } else {
            self.background(Color.black.opacity(0.02))
        }
    }

    @ViewBuilder
    func codexWidgetBackground(@ViewBuilder _ background: () -> some View) -> some View {
        if #available(macOS 14.0, *) {
            self.containerBackground(for: .widget) {
                background()
            }
        } else {
            self.background(background())
        }
    }
}

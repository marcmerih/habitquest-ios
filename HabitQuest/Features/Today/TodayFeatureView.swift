import SwiftUI

struct TodayFeatureView: View {
    let onOpenHabits: () -> Void

    init(onOpenHabits: @escaping () -> Void = {}) {
        self.onOpenHabits = onOpenHabits
    }

    var body: some View {
        TodayDeckView(onOpenHabits: onOpenHabits)
    }
}

import SwiftUI

extension Binding where Value == Bool {
    /// True while `item` holds a value. Dismissing the presentation clears the item.
    init<Item: Sendable>(presenting item: Binding<Item?>) {
        self.init(
            get: { item.wrappedValue != nil },
            set: { isPresented in
                if !isPresented {
                    item.wrappedValue = nil
                }
            }
        )
    }
}

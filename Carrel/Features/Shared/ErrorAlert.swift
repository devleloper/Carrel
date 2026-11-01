import SwiftUI

extension View {
    /// Shows `message` in an alert while it is set; dismissing the alert clears it.
    func errorAlert(_ message: Binding<String?>) -> some View {
        alert("Something Went Wrong", isPresented: Binding(presenting: message)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

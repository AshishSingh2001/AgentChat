import SwiftUI

struct ErrorAlert: ViewModifier {
    @Binding var errorMessage: String?
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil; onDismiss?() } }
            )) {
                Button("OK") {
                    errorMessage = nil
                    onDismiss?()
                }
            } message: {
                if let message = errorMessage {
                    Text(message)
                }
            }
    }
}

extension View {
    func errorAlert(errorMessage: Binding<String?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlert(errorMessage: errorMessage, onDismiss: onDismiss))
    }
}

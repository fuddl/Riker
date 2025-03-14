import SwiftUI

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var isShowing = false
    @Published var message = ""
    
    func show(_ message: String) {
        self.message = message
        withAnimation {
            self.isShowing = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                self.isShowing = false
            }
        }
    }
}

struct ToastView: View {
    @ObservedObject private var toastManager = ToastManager.shared
    
    var body: some View {
        if toastManager.isShowing {
            VStack {
                Text(toastManager.message)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)
                    .padding(.bottom, 90) // Above the player bar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
} 
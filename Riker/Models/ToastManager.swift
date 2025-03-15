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
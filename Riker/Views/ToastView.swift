import SwiftUI

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
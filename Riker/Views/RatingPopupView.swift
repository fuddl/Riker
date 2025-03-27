import SwiftUI

struct RatingPopupView: View {
    @Binding var isPresented: Bool
    let releaseGroupId: String
    let onRatingSubmitted: () -> Void
    @State private var selectedRating: Int = 0
    @State private var showingLoginView = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rate this album")
                .font(.headline)
            
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { rating in
                    Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .font(.title)
                        .onTapGesture {
                            selectedRating = rating
                        }
                }
            }
            
            HStack(spacing: 20) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Submit") {
                    print("RatingPopupView: Submit button tapped")
                    submitRating()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedRating == 0)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(15)
        .shadow(radius: 10)
        .sheet(isPresented: $showingLoginView) {
            MusicBrainzLoginView(isPresented: $showingLoginView) { session in
                print("RatingPopupView: Login successful, got session")
                submitRating()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private func submitRating() {
        print("RatingPopupView: Submitting rating with session")
        Task {
            do {
                if let session = MusicBrainzClient.shared.getSession() {
                    print("RatingPopupView: Calling submitRating API")
                    try await MusicBrainzClient.shared.submitRating(releaseGroupId: releaseGroupId, rating: selectedRating, session: session)
                    print("RatingPopupView: Rating submitted successfully")
                    onRatingSubmitted() // Call the callback after successful submission
                    isPresented = false
                } else {
                    print("RatingPopupView: No session found, showing login view")
                    showingLoginView = true
                }
            } catch MusicBrainzError.badResponse(401, _) {
                print("RatingPopupView: Session expired (401), clearing session and showing login")
                MusicBrainzClient.shared.clearSession()
                showingLoginView = true
            } catch {
                print("RatingPopupView: Error submitting rating: \(error)")
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
} 

import SwiftUI

struct RatingPopupView: View {
    @Binding var isPresented: Bool
    let releaseGroupId: String
    let releaseGroupName: String
    let onRatingSubmitted: () -> Void
    @State private var selectedRating: Int = 0
    @State private var showingLoginView = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(releaseGroupName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text("Tap a star to rate this album on MusicBrainz.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 24)
            
            Divider()
                .padding(0)
            
            HStack() {
                ForEach(1...5, id: \.self) { rating in
                    Image(systemName: rating <= selectedRating ? "star.fill" : "star")
                        .foregroundColor(rating <= selectedRating ? .accentColor : .gray.opacity(0.3))
                        .font(.system(size: 25))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                selectedRating = rating
                            }
                        }
                }
            }
            .padding(.vertical, 16)
            
            Divider()
                .padding(0)
            
            HStack(spacing: 0) {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                
                Divider()
                    .frame(height: 50)
                
                Button("Submit") {
                    print("RatingPopupView: Submit button tapped")
                    submitRating()
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedRating > 0 ? .accentColor : .secondary)
                .disabled(selectedRating == 0)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
        }
        .background(Color(UIColor.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
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

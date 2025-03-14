# Riker

Riker is a simple iOS music player that plays your local music library and can submit listens to ListenBrainz.

## Features

### Music Playback
- Access to your iOS device's music library
- Unified view of albums and playlists in a single list
- playback controls (play/pause, next track)

### ListenBrainz Integration
- Automatic scrobbling of played tracks to ListenBrainz
- tracks are scrobbled after playing 2/3 of their duration

### User Interface
- SwiftUI interface
- Dark mode support

## Requirements
- iOS 17.0 or later
- Xcode 15.0 or later
- Apple Developer account (for running on physical devices)
- Access to Apple Music or local music library
- ListenBrainz account (optional, for scrobbling)

## Building the Project

1. Clone the repository:
```bash
git clone https://github.com/yourusername/Riker.git
cd Riker
```

2. Open the project in Xcode:
```bash
open Riker.xcodeproj
```

3. Configure signing:
   - In Xcode, select the project in the navigator
   - Select the "Riker" target
   - Under "Signing & Capabilities":
     - Choose your development team
     - Update the bundle identifier if needed

4. Configure ListenBrainz (optional):
   - Get your ListenBrainz API token from https://listenbrainz.org/profile/
   - Add your token in iOS Settings after installing the app

5. Build and run:
   - Select your target device or simulator
   - Press Cmd+R or click the "Run" button

## Permissions

The app requires the following permissions:
- Music Library Access: For reading your music library
- Media Player: For controlling playback

These permissions will be requested when you first launch the app.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[Your chosen license]

## Acknowledgments

- ListenBrainz for providing the scrobbling API
- Apple for SwiftUI and MediaPlayer frameworks 
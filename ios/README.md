# iOS

Native iOS 18+ workspace generated from `project.yml` with XcodeGen. It contains the Persona 2 system-entry foundation: a WidgetKit Control, a shared `OpenIntent`, and the voice-capture route.

## Generate and run

```bash
brew install xcodegen # once
cd ios
xcodegen generate
xcodebuild -project FinanceAgent.xcodeproj -scheme FinanceAgent -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

Open `FinanceAgent.xcodeproj` in Xcode to run the app on an iOS 18+ simulator or a signed device. The Control Center surface and microphone/speech permissions should be tested on a real iPhone before the demo.

The app uses Swift, SwiftUI, WidgetKit, App Intents, and Apple's Speech framework. iOS may use Supabase Auth for sign-in/session management, but all application data access must go through the backend over HTTPS.

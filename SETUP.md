# Setup

## Open the app project

1. Install XcodeGen once: `brew install xcodegen`.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set your Apple team ID (Xcode → Settings → Accounts). This file is not in git.
3. Run `xcodegen generate` in the repository root. Run it again after each change to `project.yml`.
4. Open `MedReport.xcodeproj`. The scheme `MedReport` builds the app and runs `MedReportTests`.

## Run the Domain kit tests

The Domain logic is a Swift package. Its tests do not need an Xcode project or a simulator.

- **Xcode:** open `Packages/MedReportKit/Package.swift`. Select **My Mac** as the run destination. Press **⌘U**.
- **Terminal:**

  ```bash
  swift test --package-path Packages/MedReportKit
  ```

## Manual notification test on an iPhone (Plan 2)

Use a Debug build on a real iPhone. The debug screen shows the pending notifications.

1. Run the app on the iPhone. Tap **Request permission** and allow notifications.
2. Turn on **Fast mode** (1 day = 1 minute). Tap **Add sample report**. The list shows 64 pending notifications.
3. Lock the phone. In about 1 minute a notification comes with the buttons **Renewed / Yeniledim** and **In 3 hours / 3 saat sonra** (the language follows the phone).
4. Press **Renewed / Yeniledim** on the lock screen. Do not open the app. Then open the app and tap **Refresh**: the list shows only `renewal-…` and `backup`.
5. Close the app completely (swipe it up). Wait for the next notification and press a button. Open the app: the change is saved.

Turn off fast mode after the test. Fast mode does not exist in Release builds.

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

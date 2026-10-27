# Setup

## Run the Domain kit tests

The Domain logic is a Swift package. Its tests do not need an Xcode project or a simulator.

- **Xcode:** open `Packages/IlacRaporKit/Package.swift`. Select **My Mac** as the run destination. Press **⌘U**.
- **Terminal:**

  ```bash
  swift test --package-path Packages/IlacRaporKit
  ```

## Add the draft models to an app project (until Plan 2 makes the project)

1. Xcode → **New Project → iOS App**
   - Product Name: `IlacRapor` (if you use a different name, change `@testable import IlacRapor` in the tests)
   - Interface: SwiftUI · Storage: **None** (the project adds its own models) · Testing System: **Swift Testing**
   - Deployment target: iOS 17.0
2. Drag the `IlacRapor/Models` folder into the app target ("Copy items if needed" and the app target selected).
3. Xcode → File → Add Package Dependencies → Add Local… → `Packages/IlacRaporKit`. Add `IlacRaporKit` to the app target.
4. Drag `IlacRaporTests/ModelTests.swift` into the test target. You can delete the empty test file that Xcode made.
5. Press **⌘U**. All tests must pass.

Plan 2 connects the model container to the app (`.modelContainer(for: [Report.self, Medication.self])`).

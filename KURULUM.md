# Milestone 1 — Xcode'a ekleme

1. Xcode → **New Project → iOS App**
   - Product Name: `IlacRapor` (farklı bir ad seçersen testlerdeki `@testable import IlacRapor` satırını değiştir)
   - Interface: SwiftUI · Storage: **None** (modeli kendimiz ekliyoruz) · Testing System: **Swift Testing**
   - Deployment target: iOS 17.0
2. Bu klasördeki `IlacRapor/Models` klasörünü app target'ına sürükle ("Copy items if needed" + app target işaretli).
   Xcode → File → Add Package Dependencies → Add Local… → `Packages/IlacRaporKit`. Add `IlacRaporKit` to the app target.
3. `IlacRaporTests/` içindeki `ModelTests.swift` dosyasını test target'ına sürükle (Xcode'un oluşturduğu boş test dosyasını silebilirsin).
4. `⌘U` ile testleri çalıştır. Hepsi yeşil olmalı.

Container'ı app'e bağlamak Milestone 2'de (`.modelContainer(for: [Report.self, Medication.self])`).

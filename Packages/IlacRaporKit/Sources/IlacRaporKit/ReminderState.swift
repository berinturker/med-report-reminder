import Foundation

/// Bir rapor ya da ilacın hatırlatma durumu. Saklanmaz, her seferinde hesaplanır.
public enum ReminderState: Equatable, CaseIterable, Sendable {
    /// Kalan gün > leadDays
    case normal
    /// 0 ≤ kalan gün ≤ leadDays
    case reminding
    /// Kalan gün < 0
    case overdue
    /// Kullanıcı "Yeniledim" dedi, yeni bitiş tarihi bekleniyor
    case handled

    /// "Dikkat gerekenler" ve ana liste sıralaması için: küçük olan önce gelir.
    public var sortPriority: Int {
        switch self {
        case .overdue: 0
        case .reminding: 1
        case .handled: 2
        case .normal: 3
        }
    }

    /// Ana ekrandaki "Dikkat gerekenler" bölümünde gösterilir mi?
    public var needsAttention: Bool {
        self != .normal
    }
}

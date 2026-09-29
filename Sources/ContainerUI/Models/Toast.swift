import Foundation

/// A transient message shown at the bottom of the window — mainly so a
/// failed action is visible instead of silently ignored.
struct Toast: Identifiable, Equatable {
    enum Style { case error, success }

    let id = UUID()
    let title: String
    var message: String = ""
    var style: Style = .success
}

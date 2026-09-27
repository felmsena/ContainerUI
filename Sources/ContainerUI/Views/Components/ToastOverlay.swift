import SwiftUI

/// Stack of `ContainerService.toasts`, bottom-trailing in the window.
struct ToastOverlay: View {
    @Environment(ContainerService.self) private var service

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(service.toasts) { toast in
                ToastView(toast: toast) { service.dismissToast(toast.id) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .animation(.easeOut(duration: 0.2), value: service.toasts)
    }
}

private struct ToastView: View {
    let toast: Toast
    let onDismiss: () -> Void

    private var tint: Color { toast.style == .error ? Theme.danger : Theme.accent }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: toast.style == .error ? "exclamationmark.octagon.fill" : "checkmark.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                if !toast.message.isEmpty {
                    Text(toast.message)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.text2)
                        .lineLimit(4)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 8)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.text3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(tint.opacity(0.35), lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 12, y: 4)
        .accessibilityElement(children: .combine)
    }
}

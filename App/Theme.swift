import SwiftUI

enum Theme {
    static let accent = Color(red: 0.36, green: 0.85, blue: 0.45)
    static let card = Color.white.opacity(0.07)
    static let stroke = Color.white.opacity(0.08)
}

struct Backdrop: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.05, green: 0.10, blue: 0.08), .black],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct Card<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title { Text(title).font(.headline) }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.stroke))
    }
}

struct StatusRow: View {
    let label: String
    let ok: Bool
    var detail: String = ""
    var body: some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? Theme.accent : .red)
            Text(label)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct Badge: View {
    let text: String
    var color: Color = .gray
    var body: some View {
        Text(text).font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color.opacity(0.22), in: Capsule())
            .foregroundStyle(color)
    }
}

extension VersionKind {
    var color: Color {
        switch self {
        case .release: return Theme.accent
        case .snapshot: return .orange
        case .old_beta: return .cyan
        case .old_alpha: return .pink
        }
    }
}

struct Avatar: View {
    let account: Account?
    var size: CGFloat = 48
    var body: some View {
        let key = account.map { $0.kind == .microsoft ? $0.uuid : $0.displayName } ?? "MHF_Steve"
        AsyncImage(url: URL(string: "https://mc-heads.net/avatar/\(key)/128")) { img in
            img.resizable().interpolation(.none)
        } placeholder: {
            Color.white.opacity(0.1)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18))
    }
}

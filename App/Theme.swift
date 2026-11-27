import SwiftUI

enum Theme {
    static let accent = Color(red: 0.36, green: 0.85, blue: 0.45)
    static let card = Color.white.opacity(0.07)
}

struct Card<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
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

import SwiftUI

struct VersionsView: View {
    var picker = false
    @EnvironmentObject var store: VersionStore
    @Environment(\.dismiss) private var dismiss
    @State private var kinds: Set<VersionKind> = [.release]
    @State private var query = ""

    private var rows: [VersionEntry] {
        (store.manifest?.versions ?? []).filter { kinds.contains($0.kind) && (query.isEmpty || $0.id.localizedCaseInsensitiveContains(query)) }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(VersionKind.allCases) { k in
                        Button {
                            if kinds.contains(k) { if kinds.count > 1 { kinds.remove(k) } } else { kinds.insert(k) }
                        } label: {
                            Text(k.title).font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(kinds.contains(k) ? k.color.opacity(0.28) : Theme.card, in: Capsule())
                                .foregroundStyle(kinds.contains(k) ? k.color : .secondary)
                        }.buttonStyle(.plain)
                    }
                }.padding(.horizontal)
            }.padding(.vertical, 8)

            List {
                if store.manifest == nil {
                    HStack { ProgressView(); Text(store.error ?? "Loading versions…").foregroundStyle(.secondary) }
                        .listRowBackground(Theme.card)
                }
                ForEach(rows) { v in
                    Button {
                        store.selected = v.id
                        if picker { dismiss() }
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(v.id).font(.headline)
                                Text(v.date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Badge(text: v.kind.short, color: v.kind.color)
                            if store.installed.contains(v.id) { Image(systemName: "internaldrive.fill").foregroundStyle(Theme.accent) }
                            if store.selected == v.id { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                        }
                    }
                    .listRowBackground(Theme.card)
                    .swipeActions {
                        if store.installed.contains(v.id) {
                            Button(role: .destructive) { store.delete(v.id) } label: { Label("Delete", systemImage: "trash") }
                        } else {
                            Button { Task { await store.install(v) } } label: { Label("Install", systemImage: "arrow.down") }.tint(Theme.accent)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .refreshable { await store.refresh() }
        }
        .background(Backdrop())
        .searchable(text: $query, prompt: "Search versions")
        .navigationTitle("Versions")
        .navigationBarTitleDisplayMode(picker ? .inline : .large)
    }

    var body: some View {
        if picker {
            list.toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        } else {
            NavigationStack { list }
        }
    }
}

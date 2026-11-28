import SwiftUI
import UIKit

struct AccountsView: View {
    var picker = false
    @EnvironmentObject var accounts: AccountStore
    @Environment(\.dismiss) private var dismiss
    @State private var addOffline = false
    @State private var addMicrosoft = false
    @State private var newName = ""

    private var content: some View {
        List {
            if accounts.accounts.isEmpty {
                Text("No accounts yet. Add an offline name to try things out, or sign in with Microsoft to play online.")
                    .font(.callout).foregroundStyle(.secondary).listRowBackground(Theme.card)
            }
            ForEach(accounts.accounts) { a in
                Button {
                    accounts.activeID = a.id
                    if picker { dismiss() }
                } label: {
                    HStack(spacing: 12) {
                        Avatar(account: a, size: 42)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(a.displayName).font(.headline)
                            HStack(spacing: 6) {
                                Badge(text: a.kind == .microsoft ? "Microsoft" : "Offline",
                                      color: a.kind == .microsoft ? .blue : .gray)
                                if a.isDemo { Badge(text: "Demo", color: .orange) }
                            }
                        }
                        Spacer()
                        if accounts.active?.id == a.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                    }
                }
                .listRowBackground(Theme.card)
                .contextMenu {
                    if a.kind == .microsoft {
                        Button { accounts.setDemo(a, !a.isDemo) } label: {
                            Label(a.isDemo ? "Switch to full game" : "Switch to demo", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    Button(role: .destructive) { accounts.remove(a) } label: { Label("Remove", systemImage: "trash") }
                }
                .swipeActions { Button(role: .destructive) { accounts.remove(a) } label: { Label("Remove", systemImage: "trash") } }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Backdrop())
        .navigationTitle("Accounts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { addMicrosoft = true } label: { Label("Microsoft account", systemImage: "person.badge.key") }
                    Button { newName = ""; addOffline = true } label: { Label("Offline name", systemImage: "person") }
                } label: { Image(systemName: "plus") }
            }
            if picker { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .alert("Offline account", isPresented: $addOffline) {
            TextField("Username", text: $newName).textInputAutocapitalization(.never).autocorrectionDisabled()
            Button("Add") { accounts.addOffline(newName) }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Offline accounts can play single-player and offline servers only.") }
        .sheet(isPresented: $addMicrosoft) { MicrosoftSignIn() }
    }

    var body: some View {
        if picker { content } else { NavigationStack { content } }
    }
}

struct MicrosoftSignIn: View {
    @EnvironmentObject var accounts: AccountStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("msClientID") private var override = ""
    @State private var code: MSAuth.Code?
    @State private var error: String?
    @State private var working = false
    @State private var pending: Account?
    @State private var askDemo = false

    private var clientID: String {
        let o = override.trimmingCharacters(in: .whitespaces)
        return o.isEmpty ? BuildConfig.msClientID : o
    }
    private var missingID: Bool { clientID.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let c = code {
                        Card(title: "Enter this code") {
                            Text(c.userCode).font(.system(size: 36, weight: .bold, design: .monospaced))
                            Text("Open \(c.uri) and type the code, then sign in. This screen continues by itself.")
                                .font(.callout).foregroundStyle(.secondary)
                            HStack {
                                Button("Copy code") { UIPasteboard.general.string = c.userCode }
                                Spacer()
                                if let u = URL(string: c.uri) { Link("Open page", destination: u) }
                            }
                            ProgressView()
                        }
                    } else {
                        Button { Task { await signIn(browser: true) } } label: {
                            Label("Sign in with Microsoft", systemImage: "person.badge.key.fill")
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(working || missingID)
                        Button("Use a code instead") { Task { await signIn(browser: false) } }
                            .font(.callout).disabled(working || missingID)
                    }
                    if let e = error { Text(e).font(.callout).foregroundStyle(.red) }

                    Card {
                        DisclosureGroup(missingID ? "Setup needed: no app ID yet" : "Advanced") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Sign-in runs through one registered Azure app. A release build has its ID built in. Until then, paste one here.")
                                    .font(.callout).foregroundStyle(.secondary)
                                TextField("Application (client) ID", text: $override)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .padding(12).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                                Text("1. Azure portal, App registrations, New registration.\n2. Account type: Personal Microsoft accounts only.\n3. Authentication, Add a platform, Mobile and desktop, redirect URI javaloader://auth. Allow public client flows: Yes.\n4. Copy the Application (client) ID.\n5. Send it through Mojang's approval form so Minecraft accepts it.")
                                    .font(.callout).foregroundStyle(.secondary)
                                HStack {
                                    Link("Azure portal", destination: URL(string: "https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")!)
                                    Spacer()
                                    Link("Approval form", destination: URL(string: "https://aka.ms/mce-reviewappid")!)
                                }
                            }.padding(.top, 6)
                        }.tint(Theme.accent)
                    }
                }.padding()
            }
            .background(Backdrop())
            .navigationTitle("Microsoft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .alert("Play on demo?", isPresented: $askDemo) {
                Button("Demo") { finish(demo: true) }
                Button("No") { finish(demo: false) }
            } message: {
                Text("Demo is a limited free trial. Choose No to use the full game on an account that owns Minecraft: Java Edition.")
            }
        }
    }

    private func finish(demo: Bool) {
        guard var a = pending else { return }
        a.name = demo ? "demo." + a.displayName : a.displayName
        accounts.add(a)
        LogStore.shared.add("Saved \(a.fileName)")
        pending = nil
        dismiss()
    }

    private func signIn(browser: Bool) async {
        working = true; error = nil
        defer { working = false }
        let id = clientID
        do {
            let account: Account
            if browser {
                account = try await MSAuth.browserLogin(clientID: id)
            } else {
                let c = try await MSAuth.start(clientID: id)
                code = c
                account = try await MSAuth.finish(c, clientID: id)
            }
            code = nil
            pending = account
            askDemo = true
            LogStore.shared.add("Signed in as \(account.name)")
        } catch {
            code = nil
            self.error = error.localizedDescription
            LogStore.shared.add("Microsoft sign-in failed: \(error.localizedDescription)")
        }
    }
}

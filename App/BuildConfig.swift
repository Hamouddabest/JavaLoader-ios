/// Application (client) ID of the Azure app that powers "Sign in with Microsoft".
/// It is public by design (it is sent in every sign-in URL), so it is safe to commit.
/// Once it is set here, nobody who installs the app is asked for an ID.
enum BuildConfig {
    static let msClientID = ""
}

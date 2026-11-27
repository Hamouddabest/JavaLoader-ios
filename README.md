# JavaLoader

Run Java on iOS, with the goal of playing Minecraft: Java Edition on an iPhone without a computer.

Everything here is written from scratch. No code is taken from other Minecraft launchers.

## Status

| Part | State |
|---|---|
| App shell (Play, Java, JIT, Log, Settings) | Done |
| JIT status detection | Done |
| Self-pairing to turn on JIT without a PC | Next (reuses the approach from [PairKit](https://github.com/Hamouddabest/pairkit)) |
| Own OpenJDK build for iOS, built in GitHub Actions | Planned |
| OpenGL to Metal layer and the LWJGL pieces | Planned |
| Minecraft launcher (Microsoft login, version download, launch) | Planned |

## Install

1. Download `JavaLoader.ipa` from the [latest release](https://github.com/Hamouddabest/JavaLoader-ios/releases/latest).
2. Sideload it with SideStore, AltStore, or `./pairkit install` from PairKit.

The IPA is unsigned, so your sideloading tool signs it with your Apple ID.

## How it will work

- **JIT.** Java is far too slow without JIT. On iOS 26 and later, JIT needs a debugger attached to the app. The plan is for the app to pair with the phone itself and attach its own debugger.
- **Runtime.** An OpenJDK build for iOS, compiled in CI and downloaded by the app.
- **Graphics.** Minecraft draws with OpenGL, which iOS does not have, so it is translated to Metal.
- **Launcher.** Sign in with a Microsoft account, download the game files from Mojang, and start the game.

## Build

CI does it on every push to `main` (see `.github/workflows/ios.yml`). Locally, on a Mac:

```
brew install xcodegen
xcodegen generate
open JavaLoader.xcodeproj
```

## Requirements

iOS 16 or later. JIT on iOS 26 or later needs the pairing step above.

You need your own copy of Minecraft: Java Edition. This project is not affiliated with Mojang or Microsoft.

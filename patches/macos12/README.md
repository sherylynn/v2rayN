# macOS 12.4 compatibility patch

This fork keeps normal/upstream v2rayN behavior unchanged and adds a narrow Apple Silicon compatibility build for macOS Monterey 12.4.

## Compatibility architecture

The Monterey package is **not** an old v2rayN source fork. It builds the current fork source and applies a reproducible compatibility layer only inside CI:

1. `LegacyMacOS=true` switches the desktop app from the normal `net10.0` target to `net8.0`.
2. The self-contained runtime is pinned to .NET `8.0.8`, from the period when macOS 12 was still supported.
3. The .NET 10 SDK remains the compiler provider because current v2rayN/ReactiveUI source uses C# 14 language features even though the emitted application targets net8.
4. `prepare_legacy_source.py` applies only the small source/API compatibility rewrites required by net8 and disables unvalidated application/native-core updates in the Monterey build.
5. `package-osx.sh` retains its normal behavior by default, but exposes an optional post-core hook and optional ad-hoc signing for the Monterey workflow.
6. `prepare_runtime.sh` replaces native components that are no longer Monterey-compatible before the app bundle is created.

## Native runtime policy

`runtime-versions.env` is the single reproducible version manifest for Monterey-only native components.

- **SQLite 3.53.4** is rebuilt from the official SQLite amalgamation with an Apple Silicon deployment target of macOS 12.0. The source archive is checked against SQLite's published SHA3-256 before compiling.
- **Xray v26.3.27** is rebuilt from source with Go 1.26 and `CGO_ENABLED=0`.
- **sing-box v1.14.0** is rebuilt from source with Go 1.26 and upstream `DEFAULT_BUILD_TAGS_OTHERS`, avoiding the cgo-only Naive outbound that is tied to newer Apple native dependencies.
- **mihomo** currently comes from the upstream v2rayN core bundle because its bundled Mach-O already targets macOS 11.0. It is still subject to the same CI compatibility gate.

Go 1.26 is deliberately pinned because it is the last Go release line that supports macOS 12. `GOTOOLCHAIN=local` prevents Go from silently upgrading the compiler and raising the deployment floor.

## Update safety

A Monterey-compatible installation must not later replace its working native binaries with an upstream build that requires macOS 13+.

For that reason, the compatibility source patch disables:

- v2rayN binary self-update;
- Xray native-core update;
- sing-box native-core update;
- mihomo native-core update.

This does **not** disable subscriptions, profile editing, routing/geo data refresh, proxy start/stop, system proxy control, tray UI, or normal local configuration storage. Future native/application updates should be delivered through this fork's validated Monterey Release pipeline.

## Release gates

The workflow refuses to publish unless all of the following pass:

1. `Info.plist` declares exactly macOS `12.4` as `LSMinimumSystemVersion`.
2. The app bundle passes ad-hoc `codesign --verify --deep --strict` after native files are replaced.
3. Every bundled Mach-O contains an `arm64` slice.
4. Every Mach-O deployment target reported by `otool` is `<= 12.4`.
5. No Mach-O links to Homebrew, `/usr/local`, or other non-system `/Library/Frameworks` dependencies.
6. The rebuilt SQLite dylib loads through `ctypes`, reports the expected version, creates/writes an in-memory database, and successfully creates an FTS5 virtual table.
7. Xray, sing-box, and mihomo execute their version command successfully, and the rebuilt cores report the exact pinned versions.
8. Only after those checks pass are the DMG/ZIP checksums generated and a GitHub Release created.

These gates are intentionally stricter than changing only `LSMinimumSystemVersion`; changing the plist alone can create an application that appears installable but crashes when a newer native executable or dylib is loaded.

## Releasing after an upstream sync

1. Sync upstream source as usual.
2. Run or inspect the Monterey workflow. `prepare_legacy_source.py` deliberately fails if an expected upstream source pattern has changed, forcing the compatibility patch to be reviewed rather than silently applying to the wrong code.
3. If a native component should be upgraded, change only its entry in `runtime-versions.env` and let CI prove it still targets Monterey.
4. Bump `patches/macos12/VERSION` to create the next compatibility Release.

If future v2rayN source can no longer be compiled against net8 even with small compatibility rewrites, the fallback is to freeze the last working Monterey source baseline and selectively backport security/configuration fixes. Raising the OS requirement is not considered a successful compatibility build.

## Remaining hardware validation

CI validates executable format, deployment targets, database loading, native core startup/version commands, packaging, and signatures on Apple Silicon. Final confidence still requires launching the release on a real M2 Mac running macOS 12.4 and checking GUI startup, profile/subscription loading, system proxy switching, and at least one real Xray/sing-box connection.

# macOS 12.4 compatibility patch

This fork keeps upstream v2rayN behavior for normal builds and adds a narrow compatibility path for an Apple Silicon Mac running macOS Monterey 12.4.

## Why this exists

Upstream v2rayN 7.22+ moved the desktop app to .NET 10 and the normal macOS package declares macOS 13.6 as its minimum version. The last upstream line before the .NET 10 move was 7.21.x on .NET 8.

The compatibility build therefore keeps the current v2rayN source, but sets `LegacyMacOS=true` so only this package targets `net8.0`. It also pins the self-contained runtime to .NET 8.0.8, which was released while macOS 12 was still in Microsoft's supported OS window.

## Patch invariants

1. Normal upstream builds remain `net10.0`.
2. `LegacyMacOS=true` targets `net8.0` and pins `RuntimeFrameworkVersion=8.0.8`.
3. `package-osx.sh` accepts an optional fourth argument for `LSMinimumSystemVersion`; normal builds still default to 13.6, while this patch passes 12.4.
4. The compatibility workflow inspects every Mach-O file in the finished app with `otool` and refuses to publish if any bundled executable or dylib declares a minimum macOS version newer than 12.4.

## Releasing another patch

After syncing future upstream changes, keep the compatibility edits above and bump `patches/macos12/VERSION` (for example from `7.25.0-macos12.1` to `7.25.0-macos12.2`). A push that changes this VERSION file triggers the compatibility build and Release workflow.

If current source eventually stops compiling for `net8.0`, use upstream 7.21.x as the compatibility baseline and selectively backport only proxy/core/configuration fixes needed for basic use rather than widening the fork.

## Scope

The target is basic v2rayN desktop use on Apple Silicon: subscription/profile management, starting/stopping supported proxy cores, system proxy control, routing/configuration, tray UI, and normal local configuration storage. Features that later become dependent on .NET 10-only APIs may be disabled or backported instead of raising the OS requirement.

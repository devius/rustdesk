# Serveradmin RustDesk fork

Our own build of [RustDesk](https://github.com/rustdesk/rustdesk), shared with friends.
It is upstream **stable** RustDesk plus a few changes, signed by **Serveradmin**.

- Repo: https://github.com/devius/rustdesk, branch `server-profiles`
- Current base: upstream tag `1.5.0`
- Downloads: the `1.5.0-profiles` release on this repo

## What differs from upstream

| Change | Where |
|---|---|
| **Server profiles**: save/delete named ID/Relay/API/Key sets in Settings → Network → ID/Relay Server | `flutter/lib/mobile/widgets/dialog.dart`, `flutter/lib/common.dart` |
| **Front-page server switcher** (desktop): *RustDesk (Public)*, saved profiles, *Manage…*. Uses the same unlock (PIN / admin) as Settings → Network when installed; hidden with `hide-server-settings` | `flutter/lib/desktop/pages/desktop_home_page.dart`, `checkSettingsUnlock` in `desktop_setting_page.dart` |
| **Official update check disabled**, so official releases never replace this build | `do_check_software_update` in `src/common.rs` |
| **Windows + macOS CI** with Serveradmin signing | `.github/workflows/server-profiles-build.yml`, `.github/scripts/sign-windows.ps1`, `flutter/macos/Runner/SelfSigned.entitlements` |

Profiles are stored in the local config under the key `server-profiles`.

## Updating to a new upstream release

Only follow upstream **stable tags**, never `master`.

```sh
git fetch upstream --tags
git rebase --onto <new-tag> 1.5.0 server-profiles   # e.g. 1.5.1
git push --force-with-lease origin server-profiles
```

Then update `VERSION` and the default `upload-tag` in `server-profiles-build.yml`,
and the "Current base" line above.

If upstream changed `flutter-build.yml`, regenerate our workflow from it. It is a
cut of that file that keeps only `generate-bridge`, `build-RustDeskTempTopMostWindow`,
`build-for-windows-flutter` and `build-for-macOS`, then re-applies our signing steps.

## Building

### CI (normal way)

Actions → *Server profiles build (Windows + macOS)* → Run workflow, or:

```sh
gh workflow run server-profiles-build.yml -R devius/rustdesk --ref server-profiles
```

It builds Windows x64/arm64 and macOS Intel/Apple Silicon (~1–1.5 h) and publishes
`.exe`, `.msi`, `.dmg` and `serveradmin.cer` to the release tag.

The bridge job sometimes fails fetching `libwebm` from `chromium.googlesource.com`
(rate limiting). Just re-run it.

### Local macOS build (for testing)

Toolchain (one-time): Flutter 3.24.5 in `~/flutter-3.24.5` (with
`.github/patches/flutter_3.24.4_dropdown_menu_enableFilter.diff` applied), vcpkg in
`~/vcpkg` at the `VCPKG_COMMIT_ID` from the workflow, Rust 1.81 via rustup,
`flutter_rust_bridge_codegen` 1.80.1 and `cargo-expand` 1.0.95, Rosetta (Flutter
3.24.5's `gen_snapshot` is x86_64).

Xcode 27 needs local-only tweaks (deployment target 12.3 in `build.py`, `Podfile`,
`Cargo.toml`, the Xcode project, plus a Podfile `post_install` override). They are
kept in `git stash` ("local macOS build tweaks") and are **never committed**.

```sh
export PATH=$HOME/flutter-3.24.5/bin:/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH
export RUSTUP_TOOLCHAIN=1.81 VCPKG_ROOT=$HOME/vcpkg MACOSX_DEPLOYMENT_TARGET=12.3
flutter_rust_bridge_codegen --rust-input ./src/flutter_ffi.rs \
  --dart-output ./flutter/lib/generated_bridge.dart \
  --c-output ./flutter/macos/Runner/bridge_generated.h \
  --llvm-path /opt/homebrew/opt/llvm@21
cp flutter/macos/Runner/bridge_generated.h flutter/ios/Runner/bridge_generated.h
python3 ./build.py --flutter --hwcodec --unix-file-copy-paste --screencapturekit
# add --skip-cargo when only Dart changed
```

A local build is ad-hoc signed with the hardened runtime and will not launch until
re-signed:

```sh
codesign --force --deep --sign - \
  --entitlements flutter/macos/Runner/Release.entitlements \
  flutter/build/macos/Build/Products/Release/RustDesk.app
```

## Code signing

Builds are signed with a **self-signed** certificate:

| | |
|---|---|
| Subject | `CN=Serveradmin, O=Serveradmin, C=GE` |
| Usage | Code signing only (cannot vouch for websites) |
| Valid until | 2031-10-16 |
| SHA-1 | `D1:4A:62:5D:09:26:F5:78:9E:15:3E:01:7A:72:04:85:02:CC:49:05` |
| Public cert | `res/serveradmin/serveradmin.cer` (also attached to each release) |

Self-signed because Serveradmin is not a registered company, and public CAs only
issue organization certificates to registered entities. Windows and macOS do not
trust it by default. Each friend decides whether to trust it.

- **Windows**: `signtool` signs every unsigned `.exe`/`.dll` before packaging, then
  the installer `.exe` and `.msi`. Files already signed by others (Microsoft
  runtimes) are left alone. Timestamped via DigiCert, so signatures outlive the cert.
- **macOS**: the app is signed with the hardened runtime and
  `SelfSigned.entitlements`. That adds `disable-library-validation`, because a
  self-signed identity has no Team ID and the runtime would otherwise refuse to load
  Flutter. It is **not notarized** (that needs an Apple Developer ID). The
  designated requirement is pinned to this certificate, so Screen Recording and
  Accessibility permissions survive updates.

### Where the keys are

**On the maintainer's Mac**, in `~/.serveradmin-codesign/` (mode `700`, outside the repo):

| File | Content | Secret |
|---|---|---|
| `serveradmin.key` | Private key, unencrypted | **yes** |
| `serveradmin.p12` | Private key + cert, password-protected | **yes** |
| `p12-password.txt` | Password for the `.p12` | **yes** |
| `serveradmin.crt` / `.cer` | Public certificate (PEM / DER) | no |
| `cert.cnf` | OpenSSL config used to create the cert | no |

**Back up `serveradmin.p12` + its password offline** (password manager or
encrypted USB). Losing it means a new identity: Mac permissions reset and friends
must trust a new certificate.

**In GitHub** (repo → Settings → Secrets → Actions). These are encrypted, write-only,
and used only by the workflow:

| Secret | Value |
|---|---|
| `MACOS_P12_BASE64` | `base64 serveradmin.p12` |
| `MACOS_P12_PASSWORD` | contents of `p12-password.txt` |
| `MACOS_CODESIGN_IDENTITY` | `Serveradmin` |
| `WINDOWS_PFX_BASE64` | `base64 serveradmin.p12` (same file) |
| `WINDOWS_PFX_PASSWORD` | contents of `p12-password.txt` |
| `MACOS_NOTARIZE_JSON` | *not set*. Only with an Apple Developer ID; enables notarization |

Workflow-level env only carries `HAS_*` flags. Key material is passed only to the
steps that sign.

### Replacing or renewing the certificate

```sh
cd ~/.serveradmin-codesign
openssl req -x509 -newkey rsa:3072 -sha256 -days 1826 -nodes \
  -keyout serveradmin.key -out serveradmin.crt -config cert.cnf
openssl rand -base64 24 | tr -d '/+=' > p12-password.txt
openssl pkcs12 -export -inkey serveradmin.key -in serveradmin.crt \
  -name Serveradmin -out serveradmin.p12 -passout file:p12-password.txt
openssl x509 -in serveradmin.crt -outform der -out serveradmin.cer
```

Use `/usr/bin/openssl` (LibreSSL). OpenSSL 3 needs `-legacy` on the pkcs12 export
for macOS to import it. Then update the GitHub secrets, replace
`res/serveradmin/serveradmin.cer`, update the table above, and tell friends to
trust the new certificate.

With a real certificate later (Apple Developer ID, or a CA-issued Windows cert),
only the secrets change. Setting `MACOS_NOTARIZE_JSON` switches macOS back to
`Release.entitlements` and notarization automatically.

## Installing (for friends)

**Windows**
1. Optional: trust Serveradmin. Double-click `serveradmin.cer` → *Install
   Certificate* → *Local Machine* → *Place all certificates in the following store*
   → **Trusted Root Certification Authorities**. Repeat with **Trusted
   Publishers**. Check that the thumbprint matches the SHA-1 above.
2. Run the `.exe` or `.msi`. SmartScreen may still say "Windows protected your PC"
   for downloaded files. Choose *More info → Run anyway*.

To undo the trust step: `certmgr.msc`, then delete *Serveradmin* from both stores.

**macOS**
1. Open the `.dmg` and drag RustDesk to Applications (replacing official RustDesk;
   settings and peers are kept).
2. First launch: right-click → *Open*, or System Settings → Privacy & Security →
   *Open Anyway* (the app is not notarized).
3. Grant Screen Recording and Accessibility when asked. With our signature this is
   needed once, not after every update.

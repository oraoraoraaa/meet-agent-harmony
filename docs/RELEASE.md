# Preparing an AppGallery release

This project produces a native HarmonyOS `.app` distribution bundle. Building and
exporting it does not upload it to AppGallery or guarantee store acceptance.

## Identity and tools

- Bundle: `com.rinalic.meetAgentHarmony`
- AGC APP ID: `6917616810342569054` (also carried in the release Profile)
- Version: `AppScope/app.json5`; increase `versionCode` for subsequent releases and
  update the visible `versionName` and `buildVersion` as appropriate for AGC.
- Current minimum/target SDK: HarmonyOS `6.1.1(24)`. Do not lower the minimum without
  checking all APIs and testing compatible physical devices.
- DevEco Studio: `/Applications/DevEco-Studio.app`; Python 3 and OpenSSL on PATH.
- Icon source: `AppScope/resources/base/media/app_icon.png`, with a matching copy in
  `entry/src/main/resources/base/media/app_icon.png`. The supplied PNG is used unchanged as the application, ability and launch icon.
  A direct image avoids mismatched layer sizing in the launcher.

## Configure signing once on each machine

Keep your signing files outside the repository. Current local folder:
`/Users/rinalic/Downloads/meet-agent-harmony`.

In DevEco Studio, open **File → Project Structure → Project → Signing Configs → default**.
Disable automatic signature generation and, if displayed, automatic application
association. Configure HarmonyOS signing:

| Field | File or value |
| --- | --- |
| Store file | `meet-agent-harmony.p12` |
| Store password | Enter locally |
| Key alias | `meet-agent-harmony` |
| Key password | Enter locally |
| Sign algorithm | `SHA256withECDSA` |
| Profile | `meet-agent-harmonyRelease.p7b` |
| Certificate path | `meet-agent-harmony.cer` |

Click Apply and OK. The default product must reference the `default` signing config.
The Profile must be type `release`, distribution `app_gallery`, and match both AGC
identity and certificate. Preserve the original keystore and its password for updates.

**Do not commit the local `build-profile.json5` signing configuration.** DevEco writes
password material into this tracked file; encrypted password strings and the supporting
`material/` directory are also private. Stage source changes explicitly rather than
using `git add .`. The repository keeps an unsigned baseline configuration; reconfigure
signing locally after a fresh clone. The export script never copies signing files.

## Build, verify and export

From the repository root:

```bash
python3 scripts/prepare_release.py
```

Or specify a new, non-existing output folder:

```bash
python3 scripts/prepare_release.py "$HOME/Downloads/meet-agent-harmony/releases/my-release"
```

The script:

1. Checks that signing fields/files exist.
2. Runs the SDK `assembleApp` task in release mode.
3. Verifies the APP and matching standalone HAP signatures using Huawei's tool.
   APP distribution embeds unsigned module payloads; the script compares their
   code/resources with the signed HAP from the same build.
4. Checks the signed HAP Profile identity, release distribution type and validity.
5. Exports the signed APP, symbol archive when present, icon, supplied screenshots,
   these instructions, reviewer notes, build information and SHA-256 checksums.

Default output: `~/Downloads/meet-agent-harmony/releases/<version>-<timestamp>/`.
Local build/verification logs: `build/release-checks/`. Logs are not exported.
A signing/build/verification error stops the export. No upload is performed.

The underlying SDK command is:

```bash
PATH="/Applications/DevEco-Studio.app/Contents/tools/node/bin:$PATH" \
JAVA_HOME=/Applications/DevEco-Studio.app/Contents/jbr \
DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk \
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw \
  --mode project -p product=default -p buildMode=release assembleApp --no-daemon
```

Upload `meet-agent-harmony-default-signed.app`, **not** the unsigned APP, debug HAP,
private keystore, certificate request, signing configuration or entire export folder.
The symbol ZIP is for the relevant AGC symbol upload workflow, not the application slot.

## Before submitting in AGC

- Validate the signed release through AGC testing on a supported physical phone.
  Emulator UI checks of the same source do not validate store installation/signing.
- Confirm icon/screenshot cropping and the listing preview in AGC. Supplied promotional
  screenshots are copied as-is; confirm they describe the current version accurately.
- The app still requires a user-provided AMap Web Service key. No private API key is
  embedded in the package. Supply reviewer configuration through AGC's private review
  instructions if necessary. Consumer-ready app-managed map access is separate work.
- LLM use is optional; the built-in planner remains available without an LLM key.
- Complete AGC qualification/filing fields and privacy declarations. Confirm your hosted
  privacy declaration accurately covers map requests, location and optional LLM sharing.
- In-app Settings → 隐私声明 first obtains the hosted link through
  `privacyManager.getAppPrivacyMgmtInfo()`. For direct installs without AGC metadata,
  it falls back to the provided URL with agreement ID `2042833072528880704`.
  Verify the hosted page and any AGC-managed consent prompt on the distribution build.
  Adding a privacy link alone does not certify compliance or add a separate consent gate.
- Keep the public release description within the real functionality: single-device,
  trip-start meeting planning; no live two-party tracking or ride-hailing dispatch.

References: [Huawei release workflow](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-publish-app),
[Huawei review policies](https://developer.huawei.com/consumer/cn/doc/App/50000).

## Verification for the initial export (2026-09-19)

The SDK release build, APP/HAP signature checks and embedded payload checks passed.
The icon and privacy entry were exercised using an unsigned release HAP in the emulator.
The privacy entry launched the browser, but the hosted page remained blank there;
confirm the declaration is published and readable before submitting. A signed AGC
installation on a physical phone has not been verified in this workspace.

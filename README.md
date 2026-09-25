# molt-chromium

Chromium for [Molt Code](https://github.com/moltcode/moltcode)'s HTML previews.

Molt Code renders HTML artifacts and mockups in Chromium, drawn inside the app
(off-screen rendering, no native window). The desktop app ships on JetBrains
Runtime with the `jcef` module but without Chromium itself; this plugin supplies
it. Chromium runs out of process in JCEF's `cef_server`, so a Chromium crash
never takes the app down, and it is shut down when no HTML preview is on screen.

## How Molt uses it

Molt installs this plugin on the first HTML preview, verifying the tarball's
SHA-256 from its built-in catalog, into `~/.moltcode/plugins/molt-chromium/`.
It contributes only `resources`, files the desktop app uses; nothing is run,
put on PATH or registered:

| resource | macOS | Linux |
| --- | --- | --- |
| `cef_server` | `chromium/Frameworks/cef_server.app/Contents/MacOS/cef_server` | `chromium/cef_server` |
| `jcef_helper` | – (inside `cef_server.app`) | `chromium/jcef_helper` |

## Versions

The version is the JetBrains Runtime build it is cut from plus an optional
packaging revision, e.g. `21.0.11-b1163.116-1`. The JBR build must equal the one
the Molt Code app ships on, since Chromium has to match the app's `jcef` module;
the app refuses any other.

## macOS signing

On macOS the bundles are re-signed with Molt's Developer ID (Utpun Tech Labs,
`ZW445NH299`), keeping JetBrains' entitlements, then notarized and stapled.
Chromium writes into its own bundle at startup, and macOS App Management only
lets an app modify bundles from its own developer: signed by JetBrains, that
write is denied under Molt Code and macOS reports "Molt Code was prevented from
modifying apps on your Mac". Linux files are JetBrains' unmodified.

`make dist` needs the Developer ID in the keychain and notarization credentials
(`APPLE_ID`, `APPLE_PASSWORD`, `APPLE_TEAM_ID`) in `$NOTARIZE_ENV` (default
`../acp/.notarize.env`).

## Building

```sh
make dist      # out/molt-chromium-<version>-<platform>.tgz + out/artifacts.json
make release   # publishes out/ as GitHub release v<version>
```

`make dist` downloads `jbr_jcef-<jbr>-<platform>-<build>.tar.gz` from JetBrains'
CDN for darwin-arm64, darwin-x64, linux-x64 and linux-arm64 and repacks only the
Chromium files (re-signing and notarizing the macOS ones). Copy `out/artifacts.json` into the `molt-chromium` entry of the
Molt plugin catalog (`Moltcode.Agent.Plugins`).

See [NOTICE.md](NOTICE.md) for licenses.

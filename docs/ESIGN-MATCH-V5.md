# UTM ESign Match — research and safe repack (2026-10-08)

## Confirmed evidence from EKA2L1

EKA2L1 tested on iPhone with identical ESign certificate on 2026-09-26:

- `com.eka2l1.emulator`: Files picker presented, but selecting firmware returned no useful URL.
- `app.lavender1865.valley8348`: device test PASS selecting ROM.
- Signed app had provisioning `application-identifier` equal to team prefix plus `app.lavender1865.valley8348`.
- Source: [EKA2L1 docs commit 4125ea2](https://github.com/phai-nguyen/-EKA2L1-iOS-fixed/commit/4125ea293244f00a5e96537644eacd71021f179a).
- Source: [commit e6df4cb](https://github.com/phai-nguyen/-EKA2L1-iOS-fixed/commit/e6df4cb4db7b49b9fd4292b6ebc026b2f018aa05) removed an unnecessary UIKit file-picker workaround after resolving identity.

This suggests our UTM Lite ISO-picker problem is probably **code-signing identity and provisioning**, not `allowedContentTypes`; it is still a **hypothesis** until UTM's *signed* entitlements are checked on device.

## UTM-side current state

- Base Lite v2: `CFBundleIdentifier=com.phai.nokias60.UTM-SE`; UI launch device-PASS; ISO picker device-FAIL.
- Lite v3: changing `allowedContentTypes=[.data]` to `[.item]` did **not** fix ISO selection; PR #5 closed.
- Lite v4: local Documents selector, build PASS, awaits device test; PR #6 kept draft.
- The original UTM iOS Info.plist already has `UIFileSharingEnabled=true` and `LSSupportsOpeningDocumentsInPlace=true`. A missing simple Info.plist sharing flag is not the likely main problem.
- Upstream UTM bug reports [#4993](https://github.com/utmapp/UTM/issues/4993) and [#6989](https://github.com/utmapp/UTM/issues/6989) reproduce file choosing failure when installed with ESign.

## Important collision prevention

**Never assign UTM the already-used EKA2L1 Bundle ID** `app.lavender1865.valley8348`. iOS identifies apps by Bundle ID. Reusing it would cause an install conflict or replace the EKA2L1 installation / its data.

For simultaneous EKA2L1 and UTM installations, UTM needs its **own distinct App ID** permitted by the user's ESign provisioning setup. Do not invent an App ID, guess a wildcard, or assume that a provisioning profile can sign every Bundle ID. A separate App ID / provisioning profile may be necessary.

## New v5 workflow

[UTM-ESIGN-IDENTITY-V5](../.github/workflows/08-utm-esign-identity-v5.yml):

1. Run workflow **manually** and input UTM's own exact provisioning App ID *suffix* (without Apple Team ID prefix). Do not enter a bundle ID until it is known and authorized.
2. Uses known-good unsigned [Lite v2 IPA](https://github.com/phai-nguyen/phai-nguyen-UTM-Nokia-S60-iOS/actions/runs/37743881078).
3. Script `scripts/repack_esign_identity.py` updates only `CFBundleIdentifier` in IPA `Info.plist`, preserves all files, validates all seven QEMU dylibs, iOS 15 and the resulting ZIP.
4. Explicitly rejects the EKA2L1 Bundle ID. Produces **unsigned** IPA and identity report, never includes signing keys/profiles.
5. In ESign, sign IPA with **matching** provisioning App ID and verify `application-identifier` entitlement after signing is `TEAMID.<UTM Bundle ID>`. Team ID is not part of Bundle ID.
6. If signing lacks support for app groups, inspect `AppGroupIdentifier` and associated entitlements; don't change app group blindly.

**Build success cannot prove iOS Files selection works.** Only iPhone device test can confirm.

## Next needed information

Find the provisioned **UTM-specific App ID** in ESign, distinct from EKA2L1's existing ID. A screenshot of this field (with unrelated sensitive certificate details hidden) is sufficient. If profile only has an exact EKA2L1 App ID, do not create UTM ESign-match IPA against it; use a separately provisioned App ID or continue testing v4 Documents workaround.

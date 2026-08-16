# Android build — actions needed from you

The Android platform work has since been merged to master, and the build now
runs automatically on every push to master. What remains below is the parts
that need a device or an AWS/GitHub console.

## 1. IAM trust policy — no change needed (superseded)

~~Widen the trust policy to `refs/heads/*`.~~ **Do not do this.**

The Android build now runs automatically on every push to master, called by
`deploy.yml` after the tests pass. Nothing needs to assume the deploy role from
a non-master branch, so the live role should keep trusting `refs/heads/master`
only:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:kajstrom/lizardnotes-app-frontend:ref:refs/heads/master"
  }
}
```

`.github/iam-deploy-role.json` documents this, but that file is not applied by
anything — the IAM console is the source of truth.

Manual dispatch from a non-master branch is rejected by a guard step in
`android-build.yml` rather than failing with an opaque OIDC error.

No permission-policy changes needed; `ssm:GetParameter` already covers the
parameters the Android build reads.

## 2. Run the workflow

Every push to master builds an APK automatically — open the **Deploy** run.
To trigger one by hand: GitHub → Actions → **Android Build** → *Run workflow*
→ select `master`.

Watch for:
- The "Fetch build config" step resolving non-empty SSM values.
- First run will be slow — Gradle downloads the NDK (28.2.13676358) and CMake for
  the native plugin deps. Later runs hit the Gradle cache.

## 3. Install and smoke-test on your phone

Download the `lizardnotes-debug-apk-<run>` artifact, unzip, sideload `app-debug.apk`.

Worth exercising specifically, since these are the paths where web and mobile
diverge and have never run on Android:

- Cognito SRP login + MFA OTP.
- Create and edit a note (flutter_quill on a real touch keyboard).
- Attach a file — this hits the conditional-import boundary in
  `lib/features/attachments/providers/attachment_provider.dart`; the web blob
  path is compiled out and the stub is used instead.
- If the app throws `StateError` about a missing dart-define on launch, the SSM
  values didn't reach the build.

## 4. Optional, later

- **Release signing.** The APK is signed with Flutter's shared debug key. Fine for
  sideloading, but it can't go to Play, and a future release-signed build won't
  upgrade it in place — you'd have to uninstall first. Adding an upload keystore
  means a GitHub secret and a `key.properties` step in `build.gradle.kts`.
- **minSdk.** Left at the Flutter template default. Nothing complained during the
  local build.

## Note on this machine

The Android SDK is now at `~/Android/Sdk` and Flutter points at it. But the system
Java 21 is JRE-only (no `javac`), so local Gradle builds fail with
"does not provide the required capabilities: [JAVA_COMPILER]". I used a Temurin 17
unpacked at `/tmp/jdk17`, which won't survive a reboot. For repeat local builds,
install a real JDK 17 (e.g. `asdf plugin add java` + `temurin-17`, matching CI) and
export `JAVA_HOME`.

CI is unaffected — it uses `actions/setup-java`.

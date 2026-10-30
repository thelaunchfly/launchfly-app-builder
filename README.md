# The LaunchFly – App Builder

Builds Android apps (APK + Play Store AAB) that wrap a website in a WebView.
Builds run on GitHub Actions and are started from The LaunchFly dashboard.

- `lib/main.dart` – the app (WebView, progress bar, offline screen, back button, external links, file uploads)
- `.github/workflows/build.yml` – fetches the app's config from The LaunchFly, builds, publishes a release, reports back
- `tool/patch_android.py` – sets package id, name, permissions and signing

Required repository secret: `BUILD_SECRET` (same value as shown on The LaunchFly Admin page).

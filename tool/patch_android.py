"""Patch the generated Android project: package id, app name, permissions, AdMob ID, release signing.

Usage: python3 tool/patch_android.py <package_id> <app_name> [admob_app_id]
"""
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

TEST_ADMOB = "ca-app-pub-3940256099942544~3347511713"
pkg, name = sys.argv[1], sys.argv[2]
admob = sys.argv[3] if len(sys.argv) > 3 else TEST_ADMOB
if not re.fullmatch(r"ca-app-pub-\d+~\d+", admob):
    admob = TEST_ADMOB
if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", pkg):
    sys.exit(f"Invalid package id: {pkg}")

gradle = Path("android/app/build.gradle")
g = gradle.read_text()
g = re.sub(r'applicationId\s*=?\s*"[^"]+"', f'applicationId = "{pkg}"', g)
# Plugins (OneSignal, AdMob) need a modern minSdk
g = re.sub(r"minSdk\s*=?\s*flutter\.minSdkVersion", "minSdk = 23", g)
signing = """
    signingConfigs {
        release {
            def props = new Properties()
            props.load(new FileInputStream(rootProject.file("key.properties")))
            storeFile file(props["storeFile"])
            storePassword props["storePassword"]
            keyAlias props["keyAlias"]
            keyPassword props["keyPassword"]
        }
    }

    buildTypes {"""
g = g.replace("\n    buildTypes {", signing, 1)
g = g.replace("signingConfig = signingConfigs.debug", "signingConfig = signingConfigs.release")
gradle.write_text(g)

manifest = Path("android/app/src/main/AndroidManifest.xml")
m = manifest.read_text()
m = re.sub(r'android:label="[^"]*"', f'android:label="{escape(name, {chr(34): "&quot;"})}"', m, count=1)
perms = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.MODIFY_AUDIO_SETTINGS",
    "android.permission.POST_NOTIFICATIONS",
]
for perm in perms:
    if perm not in m:
        m = m.replace("<application", f'<uses-permission android:name="{perm}"/>\n    <application', 1)
if "com.google.android.gms.ads.APPLICATION_ID" not in m:
    meta = f'        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="{admob}"/>\n    </application>'
    m = m.replace("</application>", meta, 1)
manifest.write_text(m)
print(f"Patched Android project for {pkg} (AdMob {admob})")

"""Patch the generated Android project: package id, app name, permissions, release signing.

Usage: python3 tool/patch_android.py <package_id> <app_name>
"""
import re
import sys
from pathlib import Path
from xml.sax.saxutils import escape

pkg, name = sys.argv[1], sys.argv[2]
if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", pkg):
    sys.exit(f"Invalid package id: {pkg}")

gradle = Path("android/app/build.gradle")
g = gradle.read_text()
g = re.sub(r'applicationId\s*=?\s*"[^"]+"', f'applicationId = "{pkg}"', g)
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
if "android.permission.INTERNET" not in m:
    m = m.replace("<application", '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
manifest.write_text(m)
print(f"Patched Android project for {pkg}")

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if [ -d android ]; then
  echo "Android ja preparado. Nada sera sobrescrito."
  exit 0
fi
command -v flutter >/dev/null || { echo "Instale o Flutter SDK primeiro."; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
flutter create --empty --platforms=android --project-name=coduva --org=dev.coduva "$TMP/coduva"
cp -R "$TMP/coduva/android" "$ROOT/android"
python3 - "$ROOT/android" <<'PY'
from pathlib import Path
import sys
android = Path(sys.argv[1])
manifest = android / 'app/src/main/AndroidManifest.xml'
raw = manifest.read_text()
raw = raw.replace('<application', '<application android:networkSecurityConfig="@xml/coduva_network_security"')
if 'android.permission.INTERNET' not in raw:
    raw = raw.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application')
manifest.write_text(raw)
xml = android / 'app/src/main/res/xml/coduva_network_security.xml'
xml.parent.mkdir(parents=True, exist_ok=True)
xml.write_text('''<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="false" />
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="false">127.0.0.1</domain>
        <domain includeSubdomains="false">localhost</domain>
    </domain-config>
</network-security-config>
''')
PY
flutter pub get
echo "Android preparado. Execute: flutter run"

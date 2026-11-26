#!/usr/bin/env bash
# Gera as pastas android/ e ios/ e ajusta as permissões de rede.
# Uso (dentro da pasta mobile/):  bash tool/setup.sh
set -euo pipefail

cd "$(dirname "$0")/.."

flutter create --platforms=android,ios --org br.gov.ubsfacil --project-name ubs_facil .
rm -f test/widget_test.dart   # exemplo gerado pelo flutter create (não se aplica a este app)
flutter pub get

MANIFEST=android/app/src/main/AndroidManifest.xml
if ! grep -q "android.permission.INTERNET" "$MANIFEST"; then
  # Permissão de internet (necessária no build de produção)
  sed -i.bak 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
fi
if ! grep -q "usesCleartextTraffic" "$MANIFEST"; then
  # Permite http:// para testar com a API local. Em produção, use HTTPS e remova esta linha.
  sed -i.bak 's#<application#<application android:usesCleartextTraffic="true"#' "$MANIFEST"
fi
rm -f "$MANIFEST.bak"

echo
echo "Pronto. Rode a API (pasta backend) e depois:"
echo "  flutter run                                        # emulador Android (usa http://10.0.2.2:8000)"
echo "  flutter run --dart-define=API_URL=http://SEU_IP:8000   # celular físico na mesma rede"

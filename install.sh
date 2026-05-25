#!/usr/bin/env bash
#
# Build TahoeGlassCalendar en Release y lo instala en /Applications.
# Uso personal en tu propia Mac (ad-hoc signing, no App Store, no notarizado).
#
# Uso:
#   ./install.sh            -> compila e instala
#   ./install.sh --launch   -> compila, instala y lanza
#   ./install.sh --uninstall-> elimina la app y sus permisos TCC
#
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$PROJECT_DIR/TahoeGlassCalendar.xcodeproj"
SCHEME="TahoeGlassCalendar"
APP_NAME="TahoeGlassCalendar.app"
BUILD_DIR="$PROJECT_DIR/build"
INSTALL_DIR="/Applications"
BUNDLE_ID="com.manuel.tahoeglasscalendar"

if [[ "${1:-}" == "--uninstall" ]]; then
  echo "🗑  Cerrando app..."
  pkill -x TahoeGlassCalendar 2>/dev/null || true
  echo "🗑  Eliminando /Applications/$APP_NAME"
  rm -rf "$INSTALL_DIR/$APP_NAME"
  echo "🗑  Reseteando permisos de calendario para $BUNDLE_ID"
  tccutil reset Calendar "$BUNDLE_ID" 2>/dev/null || true
  echo "✅ Desinstalado."
  exit 0
fi

echo "🔨 Compilando en Release..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  ONLY_ACTIVE_ARCH=YES \
  build | tail -20

BUILT_APP="$BUILD_DIR/Build/Products/Release/$APP_NAME"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "❌ Build falló: no se encontró $BUILT_APP"
  exit 1
fi

echo "📦 Cerrando instancia previa (si existe)..."
pkill -x TahoeGlassCalendar 2>/dev/null || true
sleep 0.5

echo "📦 Instalando en $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$BUILT_APP" "$INSTALL_DIR/"

echo "🔐 Firmando ad-hoc con entitlements..."
codesign --force --deep --sign - \
  --entitlements "$PROJECT_DIR/TahoeGlassCalendar/TahoeGlassCalendar.entitlements" \
  --options runtime \
  "$INSTALL_DIR/$APP_NAME"

xattr -dr com.apple.quarantine "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

echo "✅ Instalado en $INSTALL_DIR/$APP_NAME"

if [[ "${1:-}" == "--launch" ]]; then
  echo "🚀 Lanzando..."
  open "$INSTALL_DIR/$APP_NAME"
fi

echo ""
echo "Para que arranque al iniciar sesión:"
echo "  System Settings → General → Login Items → +  →  $INSTALL_DIR/$APP_NAME"

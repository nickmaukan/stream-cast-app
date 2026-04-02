#!/bin/bash
# Build Maukan Cast usando JDK de Android Studio
cd "$(dirname "$0")"

export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

echo "=========================================="
echo "Maukan Cast - Build con Android Studio JDK"
echo "JAVA_HOME: $JAVA_HOME"
echo "=========================================="
echo ""

# Limpiar si se pide
if [ "$1" = "clean" ]; then
  echo "Limpiando..."
  rm -rf build android/.gradle
  ~/flutter/bin/flutter clean
fi

echo "Obteniendo dependencias..."
~/flutter/bin/flutter pub get

echo ""
echo "Iniciando build..."
~/flutter/bin/flutter build apk --release

echo ""
echo "=========================================="
echo "Build completado!"
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
echo "=========================================="

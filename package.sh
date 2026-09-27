#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "🔨 Компиляция Release-бинарника..."
swift build -c release

echo "📦 Обновление .app бандла..."
mkdir -p build/VibeNotch.app/Contents/MacOS
mkdir -p build/VibeNotch.app/Contents/Resources
cp .build/release/VibeNotch build/VibeNotch.app/Contents/MacOS/VibeNotch

if [ -f "Resources/Info.plist" ]; then
    cp Resources/Info.plist build/VibeNotch.app/Contents/Info.plist
fi

if [ -f "Resources/AppIcon.icns" ]; then
    cp Resources/AppIcon.icns build/VibeNotch.app/Contents/Resources/AppIcon.icns
fi

echo "🔏 Подпись приложения..."
DEV_ID=$(security find-identity -v -p codesigning | grep "Apple Development" | head -n 1 | sed -E 's/.*"([^"]+)".*/\1/')
if [ -n "$DEV_ID" ]; then
    echo "Используется сертификат: $DEV_ID"
    codesign --force --deep --sign "$DEV_ID" build/VibeNotch.app
else
    echo "Сертификат не найден, используется ad-hoc подпись..."
    codesign --force --deep -s - build/VibeNotch.app
fi

echo "✅ Готово! Приложение находится в: $DIR/build/VibeNotch.app"
echo "Чтобы скопировать в Программы: cp -R build/VibeNotch.app /Applications/"

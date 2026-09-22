#!/bin/bash
# Rebuild Boghi toolchain: Godot 4.7.2 + export templates + Android SDK parts + keystore
set -e
BASE=/home/z/my-project
TOOLS=$BASE/tools
SDK=/home/z/android-sdk
TP=~/.local/share/godot/export_templates
mkdir -p "$TOOLS" "$SDK/build-tools" "$SDK/platforms" "$TP" ~/.android

echo "== 1/5 Godot editor =="
if [ ! -x "$TOOLS/Godot_v4.7.2-stable_linux.x86_64" ]; then
  curl -sL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
  unzip -oq /tmp/godot.zip -d "$TOOLS" && chmod +x "$TOOLS/Godot_v4.7.2-stable_linux.x86_64"
fi
echo "editor: $(ls "$TOOLS")"

echo "== 2/5 Export templates =="
if [ ! -f "$TP/4.7.2-stable/linux_release.x86_64" ]; then
  curl -sL -o /tmp/tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
  rm -rf /tmp/tpl && mkdir -p /tmp/tpl
  unzip -oq /tmp/tpz -d /tmp/tpl
  rm -rf "$TP/4.7.2-stable" && mv /tmp/tpl/templates "$TP/4.7.2-stable"
fi
echo "templates: $(ls "$TP/4.7.2-stable" | grep -E "linux|android" | head -8)"

echo "== 3/5 Android build-tools r34 =="
if [ ! -d "$SDK/build-tools/34.0.0" ]; then
  curl -sL -o /tmp/bt.zip https://dl.google.com/android/repository/build-tools_r34-linux.zip
  unzip -oq /tmp/bt.zip -d /tmp/bt
  rm -rf "$SDK/build-tools/34.0.0" && mv /tmp/bt/android-14 "$SDK/build-tools/34.0.0" 2>/dev/null || mv /tmp/bt/* "$SDK/build-tools/34.0.0"
fi
echo "build-tools: $(ls "$SDK/build-tools/34.0.0" | head -5)"

echo "== 4/5 Android platform 34 =="
if [ ! -d "$SDK/platforms/android-34" ]; then
  curl -sL -o /tmp/pf.zip https://dl.google.com/android/repository/platform-34-ext7_r03.zip
  unzip -oq /tmp/pf.zip -d /tmp/pf
  rm -rf "$SDK/platforms/android-34" && mv /tmp/pf/android-34 "$SDK/platforms/android-34"
fi
echo "platform: $(ls "$SDK/platforms/android-34" | head -5)"

echo "== 5/5 Debug keystore =="
if [ ! -f ~/.android/debug.keystore ]; then
  keytool -genkeypair -keystore ~/.android/debug.keystore -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
    -keyalg RSA -keysize 2048 -validity 10000 2>/dev/null
fi
ls -la ~/.android/debug.keystore
echo "TOOLCHAIN READY"

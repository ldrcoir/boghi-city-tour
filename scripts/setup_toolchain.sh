#!/bin/bash
# Rebuild Boghi toolchain: Godot 4.7.2 + export templates + JDK 21 + Android SDK parts + keystore
# درس‌های ۴ بار ریست: تمپلیت‌دیر «4.7.2.stable» با نقطه — javac لازم است — gradle پلتفرم ۳۶ را خودش می‌کشد
set -e
BASE=/home/z/my-project
TOOLS=$BASE/tools
SDK=/home/z/android-sdk
TP=~/.local/share/godot/export_templates
mkdir -p "$TOOLS" "$SDK/build-tools" "$SDK/platforms" "$TP" ~/.android "$SDK/licenses"

echo "== 1/6 Godot editor =="
if [ ! -x "$TOOLS/Godot_v4.7.2-stable_linux.x86_64" ]; then
  curl -sL -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
  unzip -oq /tmp/godot.zip -d "$TOOLS" && chmod +x "$TOOLS/Godot_v4.7.2-stable_linux.x86_64"
fi
echo "editor ok"

echo "== 2/6 Export templates =="
if [ ! -f "$TP/4.7.2.stable/linux_release.x86_64" ]; then
  # درس: دانلود ۱.۲GB نیمه‌تمام با curl -C - قابل ادامه است — از صفر شروع نکن
  curl -sL -C - -o /tmp/tpz https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz
  rm -rf /tmp/tpl && mkdir -p /tmp/tpl
  unzip -oq /tmp/tpz -d /tmp/tpl
  rm -rf "$TP/4.7.2.stable" && mv /tmp/tpl/templates "$TP/4.7.2.stable"
fi
# هر دو نام (نقطه و خط‌تیره) — گودو هر کدام را خواست در دسترس باشد
[ -e "$TP/4.7.2-stable" ] || ln -sfn "$TP/4.7.2.stable" "$TP/4.7.2-stable"
echo "templates ok: $(ls "$TP/4.7.2.stable" | grep -E "linux_release|android" | head -4)"

echo "== 3/6 JDK 21 (javac لازم است) =="
if [ ! -x /home/z/jdk/bin/javac ]; then
  curl -sL -o /tmp/jdk.tar.gz "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.5%2B11/OpenJDK21U-jdk_x64_linux_hotspot_21.0.5_11.tar.gz"
  rm -rf /home/z/jdk && mkdir -p /home/z/jdk
  tar -xzf /tmp/jdk.tar.gz -C /home/z/jdk --strip-components=1
fi
/home/z/jdk/bin/javac -version
echo "jdk ok"

echo "== 4/6 Android build-tools r34 + platform 34 =="
if [ ! -d "$SDK/build-tools/34.0.0" ]; then
  curl -sL -o /tmp/bt.zip https://dl.google.com/android/repository/build-tools_r34-linux.zip
  unzip -oq /tmp/bt.zip -d /tmp/bt
  rm -rf "$SDK/build-tools/34.0.0" && mv /tmp/bt/android-14 "$SDK/build-tools/34.0.0" 2>/dev/null || mv /tmp/bt/* "$SDK/build-tools/34.0.0"
fi
if [ ! -d "$SDK/platforms/android-34" ]; then
  curl -sL -o /tmp/pf.zip https://dl.google.com/android/repository/platform-34-ext7_r03.zip
  unzip -oq /tmp/pf.zip -d /tmp/pf
  rm -rf "$SDK/platforms/android-34" && mv /tmp/pf/android-34 "$SDK/platforms/android-34"
fi
# platform-tools (aapt2/apksigner از build-tools؛ adb برای تست)
if [ ! -d "$SDK/platform-tools" ]; then
  curl -sL -o /tmp/pt.zip https://dl.google.com/android/repository/platform-tools-latest-linux.zip
  unzip -oq /tmp/pt.zip -d "$SDK"
fi
echo "sdk parts ok"

echo "== 5/6 licenses + keystore =="
# gradle تمپلیت خودش platform-36 + build-tools 36.1.0 را می‌کشد — لایسنس‌ها باید از قبل باشند
echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "$SDK/licenses/android-sdk-license"
if [ ! -f ~/.android/debug.keystore ]; then
  keytool -genkeypair -keystore ~/.android/debug.keystore -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" \
    -keyalg RSA -keysize 2048 -validity 10000 2>/dev/null
fi
echo "licenses+keystore ok"

echo "== 6/6 قالب gradle اندروید داخل پروژه =="
cd "$BASE/game"
if [ ! -f android/build/gradlew ]; then
  rm -rf android && mkdir -p android/build
  # ⛔ محتوای android_source.zip عیناً «android/build/» است نه «android/»
  unzip -oq "$TP/4.7.2.stable/android_source.zip" -d android/build
fi
echo "sdk.dir=$SDK" > android/build/local.properties
echo "gradle template ok: $(ls android/build | head -6)"

echo "TOOLCHAIN READY"

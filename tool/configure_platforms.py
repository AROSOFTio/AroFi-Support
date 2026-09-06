from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
ASSETS.mkdir(exist_ok=True)
ICON = ASSETS / 'arofi_app_icon.png'
if not ICON.exists():
    urllib.request.urlretrieve('https://arofi.net/brand-assets/arofi-app-icon.png', ICON)

android_gradle = ROOT / 'android/app/build.gradle.kts'
if android_gradle.exists():
    s = android_gradle.read_text()
    s = s.replace('namespace = "com.arosoftlabs.arofi_support"', 'namespace = "com.arosoftlabs.arofi.support"')
    s = s.replace('applicationId = "com.arosoftlabs.arofi_support"', 'applicationId = "com.arosoftlabs.arofi.support"')
    s = s.replace('minSdk = flutter.minSdkVersion', 'minSdk = maxOf(flutter.minSdkVersion, 23)')
    android_gradle.write_text(s)

manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    s = manifest.read_text()
    if 'android.permission.INTERNET' not in s:
        s = s.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">', '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    <uses-permission android:name="android.permission.INTERNET" />\n    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />')
    s = s.replace('android:label="arofi_support"', 'android:label="AroFi Support"')
    manifest.write_text(s)

ios_project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
if ios_project.exists():
    ios_project.write_text(ios_project.read_text().replace('com.arosoftlabs.arofiSupport', 'com.arosoftlabs.arofi.support'))

ios_info = ROOT / 'ios/Runner/Info.plist'
if ios_info.exists():
    s = ios_info.read_text().replace('<string>Arofi Support</string>', '<string>AroFi Support</string>')
    if 'NSMicrophoneUsageDescription' not in s:
        s = s.replace('\t<key>LSRequiresIPhoneOS</key>', '\t<key>NSMicrophoneUsageDescription</key>\n\t<string>AroFi Support uses the microphone only when you record a voice message for a support conversation.</string>\n\t<key>LSRequiresIPhoneOS</key>')
    ios_info.write_text(s)

mac_info = ROOT / 'macos/Runner/Configs/AppInfo.xcconfig'
if mac_info.exists():
    s = mac_info.read_text().replace('PRODUCT_NAME = arofi_support', 'PRODUCT_NAME = AroFi Support').replace('com.arosoftlabs.arofiSupport', 'com.arosoftlabs.arofi.support')
    mac_info.write_text(s)

web_manifest = ROOT / 'web/manifest.json'
if web_manifest.exists():
    s = web_manifest.read_text().replace('"name": "arofi_support"', '"name": "AroFi Support"').replace('"short_name": "arofi_support"', '"short_name": "AroFi Support"').replace('"#0175C2"', '"#22A53A"').replace('"description": "A new Flutter project."', '"description": "AroFi realtime support agent inbox."')
    web_manifest.write_text(s)

web_index = ROOT / 'web/index.html'
if web_index.exists():
    s = web_index.read_text().replace('content="arofi_support"', 'content="AroFi Support"').replace('<title>arofi_support</title>', '<title>AroFi Support</title>')
    web_index.write_text(s)

from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
ASSETS.mkdir(exist_ok=True)
ICON = ASSETS / 'arofi_app_icon.png'
if not ICON.exists():
    urllib.request.urlretrieve('https://arofi.net/brand-assets/arofi-app-icon.png', ICON)

ANDROID_ID = 'com.arofi.support'
IOS_ID = 'com.arofi.support'

android_gradle = ROOT / 'android/app/build.gradle.kts'
if android_gradle.exists():
    s = android_gradle.read_text()
    for old in ('com.arofi.arofi_support', 'com.arosoftlabs.arofi_support', 'com.arosoftlabs.arofi.support'):
        s = s.replace(f'namespace = "{old}"', f'namespace = "{ANDROID_ID}"')
        s = s.replace(f'applicationId = "{old}"', f'applicationId = "{ANDROID_ID}"')
    s = s.replace('minSdk = flutter.minSdkVersion', 'minSdk = maxOf(flutter.minSdkVersion, 23)')
    android_gradle.write_text(s)

manifest = ROOT / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    s = manifest.read_text()
    if 'android.permission.INTERNET' not in s:
        s = s.replace(
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
            '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <uses-permission android:name="android.permission.INTERNET" />\n'
            '    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n'
            '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />',
        )
    s = s.replace('android:label="arofi_support"', 'android:label="AroFi Support"')
    manifest.write_text(s)

ios_project = ROOT / 'ios/Runner.xcodeproj/project.pbxproj'
if ios_project.exists():
    s = ios_project.read_text()
    for old in ('com.arofi.arofiSupport', 'com.arosoftlabs.arofiSupport', 'com.arosoftlabs.arofi.support'):
        s = s.replace(old, IOS_ID)
    # Keep the test bundle distinct.
    s = s.replace(f'{IOS_ID}.RunnerTests', f'{IOS_ID}.RunnerTests')
    ios_project.write_text(s)

ios_info = ROOT / 'ios/Runner/Info.plist'
if ios_info.exists():
    s = ios_info.read_text().replace('<string>Arofi Support</string>', '<string>AroFi Support</string>')
    if 'NSMicrophoneUsageDescription' not in s:
        s = s.replace(
            '\t<key>LSRequiresIPhoneOS</key>',
            '\t<key>NSMicrophoneUsageDescription</key>\n'
            '\t<string>AroFi Support uses the microphone only when you record a voice message for a support conversation.</string>\n'
            '\t<key>LSRequiresIPhoneOS</key>',
        )
    ios_info.write_text(s)

mac_info = ROOT / 'macos/Runner/Configs/AppInfo.xcconfig'
if mac_info.exists():
    s = mac_info.read_text().replace('PRODUCT_NAME = arofi_support', 'PRODUCT_NAME = AroFi Support')
    s = s.replace('com.arosoftlabs.arofiSupport', IOS_ID).replace('com.arofi.arofiSupport', IOS_ID)
    mac_info.write_text(s)

web_manifest = ROOT / 'web/manifest.json'
if web_manifest.exists():
    s = web_manifest.read_text()
    s = s.replace('"name": "arofi_support"', '"name": "AroFi Support"')
    s = s.replace('"short_name": "arofi_support"', '"short_name": "AroFi Support"')
    s = s.replace('"#0175C2"', '"#22A53A"')
    s = s.replace('"description": "A new Flutter project."', '"description": "AroFi realtime support agent inbox."')
    web_manifest.write_text(s)

web_index = ROOT / 'web/index.html'
if web_index.exists():
    s = web_index.read_text()
    s = s.replace('content="arofi_support"', 'content="AroFi Support"')
    s = s.replace('<title>arofi_support</title>', '<title>AroFi Support</title>')
    web_index.write_text(s)

# Build Split APK - Quick Commands

## 🚀 One Command

```bash
flutter build apk --split-per-abi --release
```

**Done!** ✅

---

## 📁 Output

```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk
├── app-arm64-v8a-release.apk
├── app-x86-release.apk
└── app-x86_64-release.apk
```

---

## 📱 Install

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🎯 Complete Flow

```bash
# 1. Clean
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build
flutter build apk --split-per-abi --release

# 4. Install
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 5. Done!
```

---

## 📊 Sizes

- arm64-v8a: ~45MB (Most devices)
- armeabi-v7a: ~40MB (Older devices)
- x86: ~45MB (Emulator)
- x86_64: ~50MB (Emulator)

---

## ✅ Checklist

- [ ] Run build command
- [ ] Wait for completion
- [ ] Check output folder
- [ ] Install on device
- [ ] Test app

---

**Time**: 5-10 minutes
**Status**: Ready!

See: **BUILD_SPLIT_APK.md** for details

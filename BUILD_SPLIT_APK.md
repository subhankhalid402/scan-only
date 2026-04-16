# Build Split APK - Complete Guide

## 🎯 Split APK Kya Hai?

**Split APK** = Alag-alag APK har architecture ke liye
- ✅ Chhota size
- ✅ Faster download
- ✅ Better performance

---

## 🚀 Build Split APK

### Method 1: Command Line (Easiest)

```bash
flutter build apk --split-per-abi
```

**Output:**
```
✅ app-armeabi-v7a-release.apk
✅ app-arm64-v8a-release.apk
✅ app-x86-release.apk
✅ app-x86_64-release.apk
```

---

### Method 2: Build All Variants

```bash
# Build all split APKs
flutter build apk --split-per-abi --release

# Or with verbose output
flutter build apk --split-per-abi --release -v
```

---

### Method 3: Specific Architecture

```bash
# Only ARM64 (most common)
flutter build apk --target-platform android-arm64 --release

# Only ARM32
flutter build apk --target-platform android-arm --release

# Only x86
flutter build apk --target-platform android-x86 --release
```

---

## 📊 APK Sizes

| Architecture | Size | Devices |
|-------------|------|---------|
| armeabi-v7a | ~40MB | 32-bit ARM |
| arm64-v8a | ~45MB | 64-bit ARM (Most) |
| x86 | ~45MB | Intel x86 |
| x86_64 | ~50MB | Intel x86_64 |

---

## 📁 Output Location

```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk
├── app-arm64-v8a-release.apk
├── app-x86-release.apk
└── app-x86_64-release.apk
```

---

## 🎯 Which APK to Use?

### For Testing
- Use **arm64-v8a** (most common)
- Or **armeabi-v7a** (older devices)

### For Google Play
- Upload **all 4 APKs**
- Google Play automatically selects best one

### For Direct Distribution
- **arm64-v8a** = 95% of devices
- **armeabi-v7a** = 5% of devices

---

## 📱 Install Split APK

### On Device

```bash
# Install specific APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Or install all
adb install build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🔧 Build Configuration

### pubspec.yaml

```yaml
flutter:
  uses-material-design: true
```

### android/app/build.gradle.kts

```kotlin
android {
    compileSdk 34
    
    defaultConfig {
        applicationId "com.example.scanonly"
        minSdk 21
        targetSdk 34
        versionCode 1
        versionName "1.0.0"
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

---

## 🔐 Sign APK

### Step 1: Create Keystore

```bash
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key
```

### Step 2: Configure Signing

**android/key.properties:**
```
storePassword=your_password
keyPassword=your_password
keyAlias=key
storeFile=/path/to/key.jks
```

### Step 3: Build Signed APK

```bash
flutter build apk --split-per-abi --release
```

---

## 📊 Build Commands

### Build Release APK
```bash
flutter build apk --release
```

### Build Split APK
```bash
flutter build apk --split-per-abi --release
```

### Build with Verbose Output
```bash
flutter build apk --split-per-abi --release -v
```

### Build Specific Architecture
```bash
flutter build apk --target-platform android-arm64 --release
```

---

## 🎯 Complete Build Process

### Step 1: Clean Build
```bash
flutter clean
```

### Step 2: Get Dependencies
```bash
flutter pub get
```

### Step 3: Build Split APK
```bash
flutter build apk --split-per-abi --release
```

### Step 4: Check Output
```bash
ls -lh build/app/outputs/flutter-apk/
```

### Step 5: Install on Device
```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🆘 Troubleshooting

### Error: "Gradle build failed"
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --split-per-abi --release
```

### Error: "Signing failed"
```bash
# Check keystore path
# Verify key.properties file
# Rebuild
```

### Error: "Out of memory"
```bash
# Increase heap size
export GRADLE_OPTS="-Xmx4096m"
flutter build apk --split-per-abi --release
```

---

## 📝 Build Script

**build.sh:**
```bash
#!/bin/bash

echo "🧹 Cleaning..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🔨 Building Split APK..."
flutter build apk --split-per-abi --release

echo "✅ Build complete!"
echo "📁 Output: build/app/outputs/flutter-apk/"
ls -lh build/app/outputs/flutter-apk/

echo "📱 Installing on device..."
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

echo "🎉 Done!"
```

**Run:**
```bash
chmod +x build.sh
./build.sh
```

---

## 🚀 Upload to Google Play

### Step 1: Create Bundle
```bash
flutter build appbundle --release
```

### Step 2: Upload to Play Console
1. Go to Google Play Console
2. Create new app
3. Upload bundle
4. Fill details
5. Submit for review

---

## ✅ Checklist

- [ ] Flutter clean
- [ ] Dependencies updated
- [ ] Build split APK
- [ ] Check output files
- [ ] Install on device
- [ ] Test app
- [ ] Ready to distribute

---

## 📊 File Sizes

```
Single APK: ~180MB
Split APKs:
  - arm64-v8a: ~45MB
  - armeabi-v7a: ~40MB
  - x86: ~45MB
  - x86_64: ~50MB
```

---

## 🎯 Recommended

**For Distribution:**
- Build split APK
- Upload all 4 to Google Play
- Let Google Play choose best one

**For Testing:**
- Build arm64-v8a only
- Install on device
- Test thoroughly

---

**Status**: ✅ Ready to build
**Time**: 5-10 minutes
**Difficulty**: Easy

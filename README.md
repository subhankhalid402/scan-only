# ScanOnly - Free Document Scanner App

A full-featured document scanner app like CamScanner — 100% FREE, Offline, and Private!

## Features
- **Scan Documents** - Camera scanner with edge detection frame
- **Multiple Scan Types** - Document, ID Card, Receipt, QR Code, Book, Photo, Whiteboard, Gallery
- **Image Filters** - Original, Enhance, Grayscale, Black & White
- **Crop & Edit** - Crop, rotate, and edit scanned pages
- **PDF Export** - Save scans as PDF or JPG
- **Multi-Page** - Scan multiple pages into one document
- **Document Manager** - List + Grid view, sort by date/name/size
- **Favorites** - Mark important documents
- **Search** - Search documents by name, content, or tags
- **Share & Print** - Share PDFs, print directly
- **Settings** - Offline mode, No Ads, Private mode, Auto-enhance
- **No Internet Required** - Works completely offline

## Color Theme
- Background: Navy Blue (#0D1B4B, #1A2F6B)
- Accent: Gold/Yellow (#F5C518)
- Cards: White
- Exactly matches ScanOnly Figma design!

---

## Setup Instructions

### Prerequisites
- Flutter SDK 3.0+
- Android Studio or VS Code
- Android device or emulator (API 21+)

### Steps

1. **Extract this ZIP** to a folder

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

4. **Build APK:**
   ```bash
   flutter build apk --release
   ```
   APK will be at: `build/outputs/flutter-apk/app-release.apk`

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── theme.dart                   # Colors & theme
├── models/
│   └── document_model.dart      # Document data model
├── services/
│   ├── database_service.dart    # SQLite database
│   └── pdf_service.dart         # PDF creation & image processing
└── screens/
    ├── home_screen.dart          # Home page
    ├── scan_screen.dart          # Camera scanner
    ├── edit_scan_screen.dart     # Edit & filter scans
    ├── documents_screen.dart     # All documents
    ├── document_viewer_screen.dart # View PDF/Image
    ├── search_screen.dart        # Search
    └── settings_screen.dart      # Settings
```

## Dependencies Used (all free)
| Package | Purpose |
|---------|---------|
| camera | Live camera preview |
| image_picker | Pick from gallery |
| image_cropper | Crop scanned images |
| pdf | Create PDF files |
| printing | Print & preview PDFs |
| sqflite | Local database |
| image | Image filters & processing |
| share_plus | Share files |
| open_filex | Open files externally |
| permission_handler | Camera permissions |
| google_fonts | Nunito font |
| iconsax | Beautiful icons |
| flutter_slidable | Swipe to delete |

---

## Notes
- All data is stored locally on device
- No ads, no tracking, no internet required
- iOS setup requires additional Xcode configuration for camera permissions (Info.plist)

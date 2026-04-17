# How to Upload Documents - Complete Guide

## ✅ Your App is Working Perfectly!

**Message**: "No queued document found"

**Matlab**: 
- ✅ Supabase connected
- ✅ Sync working
- ❌ Koi document upload ke liye ready nahi

---

## 🎯 How to Upload Documents

### Step 1: Enable Cloud Backup

**Settings mein jao:**
1. Open app
2. Go to **Settings**
3. Find **Cloud Backup** option
4. **Toggle ON** karo ✅

**Important**: Yeh **pehle** karna hai!

---

### Step 2: Create New Document

**Document scan/save karo:**

**Option A: Scan Document**
1. Tap **Scan** button
2. Take photo
3. Save document

**Option B: Import PDF**
1. Tap **Import** button
2. Select PDF file
3. Save document

**Option C: Create from Gallery**
1. Tap **Gallery** button
2. Select image
3. Save document

---

### Step 3: Sync Now

**Sync button tap karo:**
1. Go to **Settings**
2. Find **Cloud Backup** section
3. Tap **Sync Now** button
4. Document upload hoga! ✅

---

## 🔄 How It Works

### When Cloud Backup is ON:

```
User saves document
    ↓
syncStatus = 'queued_for_upload'
    ↓
User taps "Sync Now"
    ↓
Document uploads to Supabase
    ↓
syncStatus = 'synced' ✅
```

### When Cloud Backup is OFF:

```
User saves document
    ↓
syncStatus = 'local_only'
    ↓
Document stays on device only
```

---

## 📝 Check Cloud Backup Status

### In Settings:

```
Settings
├── Cloud Backup
│   ├── Enable Cloud Backup [ON/OFF]
│   ├── Sync Now [Button]
│   └── Last Sync: [Time]
```

---

## 🔍 Debug: Check Documents

### Check Pending Documents:

```dart
import 'services/database_service.dart';

void checkPending() async {
  // Check queued documents
  final queued = await DatabaseService.instance.getBySyncStatus('queued_for_upload');
  print('Queued: ${queued.length}');
  
  // Check local only
  final local = await DatabaseService.instance.getBySyncStatus('local_only');
  print('Local only: ${local.length}');
  
  // Check synced
  final synced = await DatabaseService.instance.getBySyncStatus('synced');
  print('Synced: ${synced.length}');
}
```

---

## 🎯 Complete Flow

### First Time Setup:

1. **Enable Cloud Backup** (Settings)
2. **Scan/Save document**
3. **Tap Sync Now**
4. **Document uploads** ✅

### After Setup:

1. **Scan/Save document** (auto-queued)
2. **Tap Sync Now**
3. **Document uploads** ✅

---

## 🔧 Automatic Sync

### Queue Existing Documents:

Agar purane documents bhi upload karne hain:

```dart
import 'services/database_service.dart';

void queueExistingDocs() async {
  // Queue all local_only documents
  final count = await DatabaseService.instance.queueLocalOnlyForUpload();
  print('Queued $count documents');
}
```

---

## 📊 Sync Status States

| Status | Meaning |
|--------|---------|
| `local_only` | Device par hi hai |
| `queued_for_upload` | Upload ke liye ready |
| `synced` | Cloud par upload ho gaya ✅ |
| `upload_failed` | Upload fail ho gaya ❌ |

---

## ✅ Checklist

- [ ] Cloud Backup enabled
- [ ] Document created/scanned
- [ ] Sync Now tapped
- [ ] Document uploaded
- [ ] Check in Supabase

---

## 🚀 Test Upload

### Quick Test:

1. **Enable Cloud Backup**
   - Settings → Cloud Backup → ON

2. **Create Test Document**
   - Scan any paper
   - Or import any PDF
   - Save it

3. **Sync Now**
   - Settings → Sync Now
   - Wait for completion

4. **Verify**
   - Check Supabase dashboard
   - Go to Table Editor
   - See cloud_documents table
   - Your document should be there! ✅

---

## 🔍 Verify in Supabase

### Check Cloud Documents:

```sql
-- In Supabase SQL Editor
SELECT * FROM cloud_documents ORDER BY created_at DESC;
```

### Check Storage:

1. Go to **Storage** → **scan-only** bucket
2. See uploaded files
3. Your documents should be there! ✅

---

## 🆘 Troubleshooting

### Issue: "No queued document found"

**Solution**: 
1. Enable Cloud Backup first
2. Then create document
3. Then tap Sync Now

### Issue: Documents not uploading

**Solution**:
1. Check internet connection
2. Check Cloud Backup is ON
3. Check document exists
4. Try Sync Now again

### Issue: Upload failed

**Solution**:
1. Check file size (< 50MB)
2. Check file path exists
3. Check internet connection
4. Retry sync

---

## 📱 UI Flow

```
App Home
    ↓
Settings
    ↓
Cloud Backup Section
    ├─ Enable Cloud Backup [Toggle]
    ├─ Sync Now [Button]
    └─ Last Sync: [Time]
```

---

## 🎯 Summary

**Your app is working perfectly!**

**To upload documents:**
1. ✅ Enable Cloud Backup (Settings)
2. ✅ Create/Scan document
3. ✅ Tap Sync Now
4. ✅ Document uploads!

**That's it!** 🎉

---

## 📊 Expected Behavior

### When you tap "Sync Now":

**If Cloud Backup is ON:**
- ✅ Queues all local_only documents
- ✅ Uploads queued documents
- ✅ Shows success message

**If Cloud Backup is OFF:**
- ⚠️ Shows "Enable Cloud Backup first"

**If no documents:**
- ℹ️ Shows "No queued document found"
- ℹ️ Tells you to create document first

---

**Status**: ✅ App working perfectly!
**Next**: Enable Cloud Backup → Create document → Sync!

---

## 🎉 You're All Set!

Your app is **correctly configured** and **working as expected**!

Just follow the 3 steps:
1. Enable Cloud Backup
2. Create document
3. Tap Sync Now

**Happy scanning!** 📱✨

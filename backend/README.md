# ScanOnly Backend Setup

Quick setup guide for Supabase database tables.

## 🚀 Quick Start (2 minutes)

### Option 1: SQL Editor (Recommended)
1. Go to https://app.supabase.com
2. Select project `aowgmjiezwydhluigkuc`
3. Go to **SQL Editor** → **New Query**
4. Copy-paste from `create_tables.sql`
5. Click **Run**

### Option 2: Python Script
```bash
pip install -r requirements.txt
python setup_supabase.py
```

## 📋 What Gets Created

| Table | Purpose |
|-------|---------|
| `cloud_documents` | Document metadata |
| `sync_logs` | Sync operation logs |
| `users_metadata` | User preferences |
| `scan-olny` (bucket) | Document storage |

## 📁 Files

- `create_tables.sql` - SQL script for table creation
- `setup_supabase.py` - Python setup script
- `requirements.txt` - Python dependencies
- `SETUP_GUIDE.md` - Detailed setup instructions

## ✅ Verify Setup

```dart
// In your Flutter app
import 'services/backend_health_check.dart';

await BackendHealthCheck.printDiagnostics();
```

## 🔗 Supabase Credentials

- **URL**: https://aowgmjiezwydhluigkuc.supabase.co
- **Anon Key**: Embedded in `lib/main.dart`
- **Project**: aowgmjiezwydhluigkuc

## 📚 Full Documentation

See `SETUP_GUIDE.md` for detailed instructions and troubleshooting.

## 🆘 Troubleshooting

**Tables not created?**
- Check Supabase dashboard for errors
- Verify you're in correct project
- Try SQL Editor method

**Connection failed?**
- Verify internet connection
- Check credentials in `main.dart`
- Run `BackendHealthCheck.printDiagnostics()`

**Storage bucket missing?**
- Create manually in Supabase dashboard
- Name: `scan-olny`
- Set to private

---

**Status**: ✅ Ready to setup

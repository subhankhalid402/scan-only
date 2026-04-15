# Backend Setup Guide - Supabase Tables

## Overview
This guide explains how to create the required database tables in Supabase for the ScanOnly app.

## Tables Required

### 1. **cloud_documents**
Stores metadata for documents synced to cloud.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| local_id | INTEGER | Reference to local SQLite document ID |
| user_id | TEXT | Anonymous user ID |
| name | TEXT | Document name |
| scan_type | TEXT | Type: document, id_card, receipt, qr |
| file_type | TEXT | Type: pdf, jpg, png |
| file_size_mb | REAL | File size in MB |
| cloud_path | TEXT | Path in storage bucket |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

### 2. **sync_logs**
Tracks all sync operations for debugging.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | TEXT | Anonymous user ID |
| document_id | INTEGER | Local document ID |
| action | TEXT | Action: sync, upload, delete |
| status | TEXT | Status: pending, success, failed |
| error_message | TEXT | Error details if failed |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

### 3. **users_metadata** (Optional)
Stores user preferences and statistics.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| user_id | TEXT | Anonymous user ID |
| total_documents | INTEGER | Count of synced documents |
| total_storage_mb | REAL | Total storage used |
| last_sync | TIMESTAMP | Last sync timestamp |
| preferences | JSONB | User preferences JSON |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

### 4. **Storage Bucket: scan-olny**
Stores actual document files.

- **Bucket Name**: scan-olny
- **Public**: false (private)
- **Allowed MIME Types**: image/jpeg, image/png, application/pdf
- **File Size Limit**: 50MB

---

## Setup Methods

### Method 1: Using SQL Editor (Easiest) ✅

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Select your project: `aowgmjiezwydhluigkuc`
3. Go to **SQL Editor** → **New Query**
4. Copy entire content from `backend/create_tables.sql`
5. Paste into SQL editor
6. Click **Run**
7. Wait for completion (should see "Success")

**Advantages:**
- No installation required
- Instant execution
- Can see results immediately

---

### Method 2: Using Python Script

#### Prerequisites
```bash
# Install Python 3.8+
python --version

# Install dependencies
pip install -r backend/requirements.txt
```

#### Run Setup
```bash
# Navigate to backend directory
cd backend

# Run setup script
python setup_supabase.py
```

**Output:**
```
============================================================
🚀 ScanOnly Supabase Database Setup
============================================================

✓ Connected to Supabase
📦 Creating tables...

✓ cloud_documents table created successfully
✓ sync_logs table created successfully
✓ scan-olny storage bucket created successfully

📋 Verifying tables...
✓ cloud_documents table is accessible
✓ sync_logs table is accessible

============================================================
✅ Setup completed successfully!
============================================================
```

---

### Method 3: Manual Creation via Dashboard

#### Step 1: Create cloud_documents Table
1. Go to **Table Editor**
2. Click **Create a new table**
3. Name: `cloud_documents`
4. Add columns:
   - `id` (UUID, Primary Key, Default: gen_random_uuid())
   - `local_id` (Integer)
   - `user_id` (Text)
   - `name` (Text)
   - `scan_type` (Text)
   - `file_type` (Text)
   - `file_size_mb` (Float8)
   - `cloud_path` (Text)
   - `created_at` (Timestamp, Default: now())
   - `updated_at` (Timestamp, Default: now())
5. Click **Save**

#### Step 2: Create sync_logs Table
1. Click **Create a new table**
2. Name: `sync_logs`
3. Add columns:
   - `id` (UUID, Primary Key, Default: gen_random_uuid())
   - `user_id` (Text)
   - `document_id` (Integer)
   - `action` (Text)
   - `status` (Text)
   - `error_message` (Text, Nullable)
   - `created_at` (Timestamp, Default: now())
   - `updated_at` (Timestamp, Default: now())
5. Click **Save**

#### Step 3: Create Storage Bucket
1. Go to **Storage**
2. Click **Create a new bucket**
3. Name: `scan-olny`
4. Uncheck "Public bucket"
5. Click **Create bucket**

#### Step 4: Enable RLS
1. Go to **Authentication** → **Policies**
2. For each table, create policies:
   - **INSERT**: Allow anonymous
   - **SELECT**: Allow anonymous
   - **UPDATE**: Allow anonymous
   - **DELETE**: Allow anonymous

---

## Verification

### Check Tables Exist
```sql
SELECT tablename FROM pg_tables 
WHERE schemaname = 'public' 
AND tablename IN ('cloud_documents', 'sync_logs', 'users_metadata');
```

### Check Storage Bucket
```bash
# In Supabase dashboard, go to Storage
# You should see "scan-olny" bucket listed
```

### Test Connection from App
```dart
import 'services/backend_health_check.dart';

// Run this in your app
await BackendHealthCheck.printDiagnostics();
```

---

## Troubleshooting

### Issue: "Table already exists"
**Solution**: This is fine! The SQL script uses `IF NOT EXISTS` to avoid errors.

### Issue: "Permission denied"
**Solution**: 
1. Check you're using the correct Supabase project
2. Verify anon key has proper permissions
3. Go to **Authentication** → **Policies** and enable RLS policies

### Issue: "Storage bucket not found"
**Solution**:
1. Go to **Storage** in Supabase dashboard
2. Manually create bucket named `scan-olny`
3. Set to private (not public)

### Issue: "Connection test failed"
**Solution**:
1. Verify tables were created successfully
2. Check RLS policies are enabled
3. Verify anon key is correct in `main.dart`
4. Check internet connection

---

## Next Steps

1. ✅ Create tables using one of the methods above
2. ✅ Verify tables exist in Supabase dashboard
3. ✅ Run `BackendHealthCheck.printDiagnostics()` in app
4. ✅ Test document upload/sync
5. ✅ Monitor sync_logs for any errors

---

## Database Schema Diagram

```
┌─────────────────────────────────────┐
│      cloud_documents                │
├─────────────────────────────────────┤
│ id (UUID) [PK]                      │
│ local_id (INTEGER)                  │
│ user_id (TEXT)                      │
│ name (TEXT)                         │
│ scan_type (TEXT)                    │
│ file_type (TEXT)                    │
│ file_size_mb (REAL)                 │
│ cloud_path (TEXT)                   │
│ created_at (TIMESTAMP)              │
│ updated_at (TIMESTAMP)              │
└─────────────────────────────────────┘
           ↓ stores files in
┌─────────────────────────────────────┐
│    Storage: scan-olny               │
├─────────────────────────────────────┤
│ /user_id/document_id_timestamp.ext  │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│      sync_logs                      │
├─────────────────────────────────────┤
│ id (UUID) [PK]                      │
│ user_id (TEXT)                      │
│ document_id (INTEGER)               │
│ action (TEXT)                       │
│ status (TEXT)                       │
│ error_message (TEXT)                │
│ created_at (TIMESTAMP)              │
│ updated_at (TIMESTAMP)              │
└─────────────────────────────────────┘
```

---

## Security Notes

- ✅ RLS (Row Level Security) enabled on all tables
- ✅ Anonymous access configured for app users
- ✅ Storage bucket is private (not public)
- ✅ File size limited to 50MB
- ✅ MIME types restricted to documents only

---

## Support

If you encounter issues:
1. Check Supabase dashboard for error messages
2. Review sync_logs table for operation details
3. Run `BackendHealthCheck.printDiagnostics()` in app
4. Check internet connectivity
5. Verify credentials in `main.dart`

---

**Last Updated**: April 2026
**Supabase Version**: Latest
**Status**: Ready for Production

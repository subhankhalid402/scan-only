# ScanOnly Backend Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Flutter Mobile App                          │
│                    (ScanOnly - iOS/Android)                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │  Local Storage  │
                    ├─────────────────┤
                    │ SQLite Database │
                    │ (scanonly.db)   │
                    │                 │
                    │ • documents     │
                    │ • metadata      │
                    │ • sync status   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────────────────┐
                    │  Cloud Sync Service         │
                    ├─────────────────────────────┤
                    │ CloudBackupService          │
                    │ • Detects pending uploads   │
                    │ • Uploads to cloud          │
                    │ • Updates sync status       │
                    └────────┬────────────────────┘
                             │
                    ┌────────▼────────────────────────────────────┐
                    │         Supabase Backend                    │
                    │  (https://aowgmjiezwydhluigkuc.supabase.co) │
                    └────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
   ┌────▼─────┐      ┌──────▼──────┐      ┌─────▼──────┐
   │ PostgreSQL│      │   Storage   │      │   Auth     │
   │ Database  │      │   Bucket    │      │   Service  │
   └───────────┘      └─────────────┘      └────────────┘
        │                    │
   ┌────▼──────────────┐     │
   │ Tables:           │     │
   │ • cloud_documents │     │
   │ • sync_logs       │     │
   │ • users_metadata  │     │
   └───────────────────┘     │
                        ┌────▼──────────────┐
                        │ Bucket: scan-olny │
                        │                   │
                        │ /user_id/         │
                        │   doc_id_ts.ext   │
                        └───────────────────┘
```

## Data Flow

### 1. Document Creation
```
User scans document
        ↓
App creates DocumentModel
        ↓
Saves to local SQLite (syncStatus: 'local_only')
        ↓
Document ready for sync
```

### 2. Cloud Sync Process
```
CloudBackupService.syncPendingUploads()
        ↓
Query documents with syncStatus='queued_for_upload'
        ↓
For each document:
  ├─ Authenticate (anonymous sign-in if needed)
  ├─ Upload file to storage bucket
  ├─ Insert metadata to cloud_documents table
  ├─ Log operation to sync_logs
  └─ Update local syncStatus to 'synced'
        ↓
Return CloudSyncResult (uploaded, failed)
```

### 3. Error Handling
```
Upload fails
        ↓
Log error to sync_logs
        ↓
Update syncStatus to 'upload_failed'
        ↓
User can retry later
```

## Database Schema

### cloud_documents Table
```sql
CREATE TABLE cloud_documents (
    id UUID PRIMARY KEY,
    local_id INTEGER,           -- Reference to local SQLite ID
    user_id TEXT,               -- Anonymous user ID
    name TEXT,                  -- Document name
    scan_type TEXT,             -- document|id_card|receipt|qr
    file_type TEXT,             -- pdf|jpg|png
    file_size_mb REAL,          -- File size
    cloud_path TEXT,            -- Path in storage bucket
    created_at TIMESTAMP,       -- Creation time
    updated_at TIMESTAMP        -- Last update time
);

-- Indexes for performance
CREATE INDEX idx_cloud_documents_user_id ON cloud_documents(user_id);
CREATE INDEX idx_cloud_documents_local_id ON cloud_documents(local_id);
```

### sync_logs Table
```sql
CREATE TABLE sync_logs (
    id UUID PRIMARY KEY,
    user_id TEXT,               -- Anonymous user ID
    document_id INTEGER,        -- Local document ID
    action TEXT,                -- sync|upload|delete
    status TEXT,                -- pending|success|failed
    error_message TEXT,         -- Error details
    created_at TIMESTAMP,       -- Creation time
    updated_at TIMESTAMP        -- Last update time
);

-- Indexes for debugging
CREATE INDEX idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX idx_sync_logs_status ON sync_logs(status);
```

### users_metadata Table
```sql
CREATE TABLE users_metadata (
    id UUID PRIMARY KEY,
    user_id TEXT UNIQUE,        -- Anonymous user ID
    total_documents INTEGER,    -- Count of synced docs
    total_storage_mb REAL,      -- Total storage used
    last_sync TIMESTAMP,        -- Last sync time
    preferences JSONB,          -- User preferences
    created_at TIMESTAMP,       -- Creation time
    updated_at TIMESTAMP        -- Last update time
);
```

## Storage Structure

### Bucket: scan-olny
```
scan-olny/
├── user_id_1/
│   ├── 1_1704067200000.pdf
│   ├── 2_1704067300000.jpg
│   └── 3_1704067400000.png
├── user_id_2/
│   ├── 1_1704067500000.pdf
│   └── 2_1704067600000.jpg
└── user_id_3/
    └── 1_1704067700000.png
```

**Path Format**: `{user_id}/{local_id}_{timestamp}.{extension}`

## Sync Status States

```
┌──────────────┐
│  local_only  │  Document exists only locally
└──────┬───────┘
       │ User initiates sync
       ▼
┌──────────────────────┐
│ queued_for_upload    │  Waiting to be uploaded
└──────┬───────────────┘
       │ CloudBackupService processes
       ├─ Success ──────────────────┐
       │                            ▼
       │                    ┌──────────────┐
       │                    │   synced     │  Successfully uploaded
       │                    └──────────────┘
       │
       └─ Failure ──────────────────┐
                                    ▼
                            ┌──────────────────┐
                            │ upload_failed    │  Upload failed
                            └──────────────────┘
                                    │
                                    │ User retries
                                    ▼
                            ┌──────────────────────┐
                            │ queued_for_upload    │
                            └──────────────────────┘
```

## Security Architecture

### Row Level Security (RLS)
```
┌─────────────────────────────────────┐
│  Supabase RLS Policies              │
├─────────────────────────────────────┤
│ • INSERT: Allow anonymous           │
│ • SELECT: Allow anonymous           │
│ • UPDATE: Allow anonymous           │
│ • DELETE: Allow anonymous           │
└─────────────────────────────────────┘
```

### Authentication Flow
```
App starts
    ↓
Check if authenticated
    ├─ Yes: Use existing session
    └─ No: Sign in anonymously
    ↓
Get user ID (anonymous)
    ↓
Use user_id for all operations
```

### Storage Security
```
┌─────────────────────────────────────┐
│  Storage Bucket: scan-olny          │
├─────────────────────────────────────┤
│ • Public: false (private)           │
│ • Allowed MIME types:               │
│   - image/jpeg                      │
│   - image/png                       │
│   - application/pdf                 │
│ • File size limit: 50MB             │
│ • Access: Anonymous users only      │
└─────────────────────────────────────┘
```

## Performance Optimization

### Indexes
```
cloud_documents:
  ├─ idx_cloud_documents_user_id
  ├─ idx_cloud_documents_local_id
  └─ idx_cloud_documents_created_at

sync_logs:
  ├─ idx_sync_logs_user_id
  ├─ idx_sync_logs_status
  └─ idx_sync_logs_created_at
```

### Query Optimization
```
-- Fast: Uses index
SELECT * FROM cloud_documents WHERE user_id = 'xxx';

-- Fast: Uses index
SELECT * FROM sync_logs WHERE status = 'failed';

-- Slow: Full table scan (avoid)
SELECT * FROM cloud_documents WHERE name LIKE '%doc%';
```

## Monitoring & Debugging

### Health Check Flow
```
BackendHealthCheck.checkConnection()
    ├─ Check Supabase availability
    ├─ Check client initialization
    ├─ Test database query
    ├─ Check authentication
    └─ Return overall health status
```

### Logging
```
All operations logged to sync_logs:
  ├─ Successful uploads
  ├─ Failed uploads
  ├─ Sync attempts
  └─ Error details
```

## Disaster Recovery

### Backup Strategy
```
Local SQLite Database
    ├─ Primary copy on device
    ├─ Backed up to Supabase
    └─ Can recover from cloud if needed

Cloud Storage
    ├─ Redundant storage
    ├─ Automatic backups
    └─ Versioning available
```

### Sync Recovery
```
If sync fails:
    ├─ Document stays in local_only
    ├─ Error logged to sync_logs
    ├─ User can retry manually
    └─ Automatic retry on next sync
```

## Scalability

### Current Limits
- File size: 50MB per document
- Storage: Supabase default (100GB free tier)
- Concurrent users: Unlimited (anonymous)
- Requests: Supabase rate limits apply

### Future Scaling
- Implement pagination for large result sets
- Add caching layer for frequently accessed data
- Implement batch operations for bulk uploads
- Add CDN for faster file delivery

---

**Architecture Version**: 1.0
**Last Updated**: April 2026
**Status**: Production Ready

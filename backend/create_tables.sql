-- ============================================================
-- ScanOnly Supabase Database Schema
-- Run this in Supabase SQL Editor
-- ============================================================

-- 1. Create cloud_documents table
CREATE TABLE IF NOT EXISTS cloud_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    local_id INTEGER NOT NULL,
    user_id TEXT NOT NULL,
    name TEXT NOT NULL,
    scan_type TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_size_mb REAL NOT NULL DEFAULT 0,
    cloud_path TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, local_id)
);

-- Create indexes for cloud_documents
CREATE INDEX IF NOT EXISTS idx_cloud_documents_user_id ON cloud_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_cloud_documents_local_id ON cloud_documents(local_id);
CREATE INDEX IF NOT EXISTS idx_cloud_documents_created_at ON cloud_documents(created_at);

-- Enable RLS on cloud_documents
ALTER TABLE cloud_documents ENABLE ROW LEVEL SECURITY;

-- RLS Policies for cloud_documents (allow anonymous access)
CREATE POLICY "Allow anonymous insert" ON cloud_documents
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anonymous update" ON cloud_documents
    FOR UPDATE USING (true);

CREATE POLICY "Allow anonymous select" ON cloud_documents
    FOR SELECT USING (true);

CREATE POLICY "Allow anonymous delete" ON cloud_documents
    FOR DELETE USING (true);

-- ============================================================

-- 2. Create sync_logs table
CREATE TABLE IF NOT EXISTS sync_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    document_id INTEGER NOT NULL,
    action TEXT NOT NULL,
    status TEXT NOT NULL,
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for sync_logs
CREATE INDEX IF NOT EXISTS idx_sync_logs_user_id ON sync_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_status ON sync_logs(status);
CREATE INDEX IF NOT EXISTS idx_sync_logs_created_at ON sync_logs(created_at);

-- Enable RLS on sync_logs
ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies for sync_logs (allow anonymous access)
CREATE POLICY "Allow anonymous insert logs" ON sync_logs
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anonymous select logs" ON sync_logs
    FOR SELECT USING (true);

-- ============================================================

-- 3. Create users_metadata table (optional - for storing user preferences)
CREATE TABLE IF NOT EXISTS users_metadata (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL UNIQUE,
    total_documents INTEGER DEFAULT 0,
    total_storage_mb REAL DEFAULT 0,
    last_sync TIMESTAMP WITH TIME ZONE,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for users_metadata
CREATE INDEX IF NOT EXISTS idx_users_metadata_user_id ON users_metadata(user_id);

-- Enable RLS on users_metadata
ALTER TABLE users_metadata ENABLE ROW LEVEL SECURITY;

-- RLS Policies for users_metadata
CREATE POLICY "Allow anonymous insert metadata" ON users_metadata
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow anonymous update metadata" ON users_metadata
    FOR UPDATE USING (true);

CREATE POLICY "Allow anonymous select metadata" ON users_metadata
    FOR SELECT USING (true);

-- ============================================================

-- 4. Create storage bucket (if not exists)
-- Note: Storage buckets must be created via API or dashboard
-- This is a reference for manual creation:
-- Bucket name: scan-olny
-- Public: false
-- Allowed MIME types: image/jpeg, image/png, application/pdf
-- File size limit: 52428800 (50MB)

-- ============================================================

-- 5. Create functions for common operations

-- Function to update sync status
CREATE OR REPLACE FUNCTION update_sync_status(
    p_user_id TEXT,
    p_document_id INTEGER,
    p_status TEXT
)
RETURNS void AS $$
BEGIN
    INSERT INTO sync_logs (user_id, document_id, action, status)
    VALUES (p_user_id, p_document_id, 'sync', p_status)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- Function to get user statistics
CREATE OR REPLACE FUNCTION get_user_stats(p_user_id TEXT)
RETURNS TABLE (
    total_documents BIGINT,
    total_storage_mb REAL,
    last_sync TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*)::BIGINT,
        COALESCE(SUM(file_size_mb), 0)::REAL,
        MAX(updated_at)
    FROM cloud_documents
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================

-- 6. Verify tables were created
SELECT 
    tablename,
    (SELECT COUNT(*) FROM information_schema.columns WHERE table_name = tablename) as column_count
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('cloud_documents', 'sync_logs', 'users_metadata')
ORDER BY tablename;

-- ============================================================
-- Setup complete!
-- Tables created:
-- ✓ cloud_documents - Stores document metadata
-- ✓ sync_logs - Tracks sync operations
-- ✓ users_metadata - Stores user preferences
-- ============================================================

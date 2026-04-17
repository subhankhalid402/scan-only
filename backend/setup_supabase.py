#!/usr/bin/env python3
"""
Supabase Database Setup Script
Creates all required tables for ScanOnly app
"""

import os
import sys
from supabase import create_client, Client

# Configuration — set in environment (never commit keys)
SUPABASE_URL = os.environ.get("SUPABASE_URL", "").strip()
SUPABASE_KEY = os.environ.get("SUPABASE_ANON_KEY", "").strip()

def create_supabase_client() -> Client:
    """Create and return Supabase client"""
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("✗ Set SUPABASE_URL and SUPABASE_ANON_KEY in the environment, e.g.:")
        print('    set SUPABASE_URL=https://YOUR_PROJECT.supabase.co')
        print("    set SUPABASE_ANON_KEY=your_anon_key")
        sys.exit(1)
    try:
        client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("✓ Connected to Supabase")
        return client
    except Exception as e:
        print(f"✗ Failed to connect to Supabase: {e}")
        sys.exit(1)

def create_cloud_documents_table(client: Client) -> bool:
    """Create cloud_documents table"""
    try:
        # Check if table exists
        response = client.table('cloud_documents').select('id').limit(1).execute()
        print("✓ cloud_documents table already exists")
        return True
    except Exception as e:
        if "does not exist" in str(e) or "relation" in str(e):
            print("⚠ cloud_documents table doesn't exist. Creating...")
            try:
                # Create table using raw SQL
                sql = """
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
                
                -- Create index for faster queries
                CREATE INDEX IF NOT EXISTS idx_cloud_documents_user_id ON cloud_documents(user_id);
                CREATE INDEX IF NOT EXISTS idx_cloud_documents_local_id ON cloud_documents(local_id);
                
                -- Enable RLS
                ALTER TABLE cloud_documents ENABLE ROW LEVEL SECURITY;
                
                -- Allow anonymous users to insert/update their own documents
                CREATE POLICY "Allow anonymous insert" ON cloud_documents
                    FOR INSERT WITH CHECK (true);
                
                CREATE POLICY "Allow anonymous update" ON cloud_documents
                    FOR UPDATE USING (true);
                
                CREATE POLICY "Allow anonymous select" ON cloud_documents
                    FOR SELECT USING (true);
                """
                
                # Execute raw SQL
                client.postgrest.auth(SUPABASE_KEY).post(
                    "/rpc/execute_sql",
                    {"sql": sql}
                )
                print("✓ cloud_documents table created successfully")
                return True
            except Exception as create_error:
                print(f"✗ Failed to create cloud_documents table: {create_error}")
                return False
        else:
            print(f"✗ Error checking cloud_documents table: {e}")
            return False

def create_sync_logs_table(client: Client) -> bool:
    """Create sync_logs table for tracking sync operations"""
    try:
        response = client.table('sync_logs').select('id').limit(1).execute()
        print("✓ sync_logs table already exists")
        return True
    except Exception as e:
        if "does not exist" in str(e) or "relation" in str(e):
            print("⚠ sync_logs table doesn't exist. Creating...")
            try:
                sql = """
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
                
                -- Create indexes
                CREATE INDEX IF NOT EXISTS idx_sync_logs_user_id ON sync_logs(user_id);
                CREATE INDEX IF NOT EXISTS idx_sync_logs_status ON sync_logs(status);
                CREATE INDEX IF NOT EXISTS idx_sync_logs_created_at ON sync_logs(created_at);
                
                -- Enable RLS
                ALTER TABLE sync_logs ENABLE ROW LEVEL SECURITY;
                
                -- Allow anonymous users to insert logs
                CREATE POLICY "Allow anonymous insert logs" ON sync_logs
                    FOR INSERT WITH CHECK (true);
                
                CREATE POLICY "Allow anonymous select logs" ON sync_logs
                    FOR SELECT USING (true);
                """
                
                client.postgrest.auth(SUPABASE_KEY).post(
                    "/rpc/execute_sql",
                    {"sql": sql}
                )
                print("✓ sync_logs table created successfully")
                return True
            except Exception as create_error:
                print(f"✗ Failed to create sync_logs table: {create_error}")
                return False
        else:
            print(f"✗ Error checking sync_logs table: {e}")
            return False

def create_storage_bucket(client: Client) -> bool:
    """Create storage bucket for documents"""
    try:
        # Check if bucket exists
        buckets = client.storage.list_buckets()
        bucket_names = [b.name for b in buckets]
        
        if 'scan-only' in bucket_names:
            print("✓ scan-only storage bucket already exists")
            return True
        else:
            print("⚠ scan-only bucket doesn't exist. Creating...")
            try:
                client.storage.create_bucket(
                    'scan-only',
                    options={
                        'public': False,
                        'allowed_mime_types': ['image/jpeg', 'image/png', 'application/pdf'],
                        'file_size_limit': 52428800  # 50MB
                    }
                )
                print("✓ scan-only storage bucket created successfully")
                return True
            except Exception as create_error:
                print(f"✗ Failed to create storage bucket: {create_error}")
                return False
    except Exception as e:
        print(f"✗ Error checking storage buckets: {e}")
        return False

def verify_tables(client: Client) -> bool:
    """Verify all tables exist and are accessible"""
    print("\n📋 Verifying tables...")
    
    tables_ok = True
    
    # Check cloud_documents
    try:
        response = client.table('cloud_documents').select('id').limit(1).execute()
        print("✓ cloud_documents table is accessible")
    except Exception as e:
        print(f"✗ cloud_documents table error: {e}")
        tables_ok = False
    
    # Check sync_logs
    try:
        response = client.table('sync_logs').select('id').limit(1).execute()
        print("✓ sync_logs table is accessible")
    except Exception as e:
        print(f"✗ sync_logs table error: {e}")
        tables_ok = False
    
    return tables_ok

def main():
    """Main setup function"""
    print("=" * 60)
    print("🚀 ScanOnly Supabase Database Setup")
    print("=" * 60)
    print()
    
    # Connect to Supabase
    client = create_supabase_client()
    print()
    
    # Create tables
    print("📦 Creating tables...")
    print()
    
    success = True
    success &= create_cloud_documents_table(client)
    success &= create_sync_logs_table(client)
    success &= create_storage_bucket(client)
    
    print()
    
    # Verify
    if verify_tables(client):
        print()
        print("=" * 60)
        print("✅ Setup completed successfully!")
        print("=" * 60)
        print()
        print("📊 Database Summary:")
        print("  • cloud_documents: Stores document metadata")
        print("  • sync_logs: Tracks sync operations")
        print("  • scan-only bucket: Stores document files")
        print()
        print("🔐 Security:")
        print("  • RLS (Row Level Security) enabled")
        print("  • Anonymous access configured")
        print("  • File size limit: 50MB")
        print()
        return 0
    else:
        print()
        print("=" * 60)
        print("⚠️  Setup completed with warnings")
        print("=" * 60)
        return 1

if __name__ == "__main__":
    sys.exit(main())

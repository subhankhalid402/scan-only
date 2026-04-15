# Backend Setup Checklist

Complete this checklist to ensure your backend is properly configured.

## Phase 1: Database Setup

### Create Tables
- [ ] Read `SETUP_GUIDE.md`
- [ ] Choose setup method (SQL Editor / Python / Manual)
- [ ] Execute table creation script
- [ ] Verify no errors in Supabase dashboard

### Verify Tables
- [ ] Go to Supabase dashboard
- [ ] Check **Table Editor**
- [ ] Confirm `cloud_documents` table exists
- [ ] Confirm `sync_logs` table exists
- [ ] Confirm `users_metadata` table exists

### Create Storage Bucket
- [ ] Go to **Storage** in Supabase
- [ ] Create bucket named `scan-olny`
- [ ] Set to **Private** (not public)
- [ ] Verify bucket appears in list

## Phase 2: Security Configuration

### Enable RLS (Row Level Security)
- [ ] Go to **Authentication** → **Policies**
- [ ] For `cloud_documents`:
  - [ ] Create INSERT policy (allow anonymous)
  - [ ] Create SELECT policy (allow anonymous)
  - [ ] Create UPDATE policy (allow anonymous)
  - [ ] Create DELETE policy (allow anonymous)
- [ ] For `sync_logs`:
  - [ ] Create INSERT policy (allow anonymous)
  - [ ] Create SELECT policy (allow anonymous)
- [ ] For `users_metadata`:
  - [ ] Create INSERT policy (allow anonymous)
  - [ ] Create SELECT policy (allow anonymous)
  - [ ] Create UPDATE policy (allow anonymous)

### Verify Credentials
- [ ] Confirm Supabase URL: `https://aowgmjiezwydhluigkuc.supabase.co`
- [ ] Confirm Anon Key is in `lib/main.dart`
- [ ] Verify credentials are not expired

## Phase 3: App Integration

### Backend Health Check
- [ ] Import `BackendHealthCheck` in your app
- [ ] Run `BackendHealthCheck.printDiagnostics()`
- [ ] Verify output shows:
  - [ ] Supabase Available: true
  - [ ] Client Initialized: true
  - [ ] Connection Working: true
  - [ ] Authenticated: true
  - [ ] Overall Health: Healthy

### Backend Status Screen
- [ ] Navigate to `BackendStatusScreen`
- [ ] Verify all status indicators are green
- [ ] Check user ID is displayed
- [ ] Test retry button

### Test Utilities
- [ ] Run `BackendTestUtils.runAllTests()`
- [ ] Verify all 5 tests pass:
  - [ ] Test 1: Supabase Availability ✓
  - [ ] Test 2: Client Connection ✓
  - [ ] Test 3: Database Query ✓
  - [ ] Test 4: Authentication ✓
  - [ ] Test 5: Overall Health Check ✓

## Phase 4: Functionality Testing

### Document Upload
- [ ] Create a test document in app
- [ ] Mark for cloud sync
- [ ] Trigger sync operation
- [ ] Verify document appears in `cloud_documents` table
- [ ] Verify file appears in `scan-olny` bucket

### Sync Logs
- [ ] Check `sync_logs` table for entries
- [ ] Verify successful uploads logged
- [ ] Verify failed uploads logged (if any)
- [ ] Check error messages are descriptive

### User Metadata
- [ ] Check `users_metadata` table
- [ ] Verify user statistics are updated
- [ ] Verify last_sync timestamp is current

## Phase 5: Error Handling

### Network Failure
- [ ] Disable internet connection
- [ ] Try to sync document
- [ ] Verify app gracefully handles error
- [ ] Verify document stays in `queued_for_upload`
- [ ] Re-enable internet
- [ ] Verify sync completes successfully

### Invalid Credentials
- [ ] Temporarily change anon key in `main.dart`
- [ ] Run health check
- [ ] Verify it detects connection failure
- [ ] Restore correct credentials
- [ ] Verify connection works again

### Database Errors
- [ ] Check Supabase logs for errors
- [ ] Review sync_logs for failed operations
- [ ] Verify error messages are logged
- [ ] Check for any permission issues

## Phase 6: Performance Testing

### Query Performance
- [ ] Create 100+ test documents
- [ ] Verify queries still respond quickly
- [ ] Check database indexes are working
- [ ] Monitor query execution time

### Storage Performance
- [ ] Upload large files (near 50MB limit)
- [ ] Verify upload completes successfully
- [ ] Check file integrity in storage
- [ ] Monitor upload speed

### Sync Performance
- [ ] Sync 50+ documents
- [ ] Verify all upload successfully
- [ ] Check sync_logs for any failures
- [ ] Monitor total sync time

## Phase 7: Monitoring & Logging

### Enable Debug Logging
- [ ] Add debug flag to Supabase initialization
- [ ] Monitor console output during sync
- [ ] Verify all operations are logged
- [ ] Check for any warnings or errors

### Monitor Sync Logs
- [ ] Regularly check `sync_logs` table
- [ ] Look for patterns in failures
- [ ] Identify any recurring issues
- [ ] Optimize based on findings

### Health Monitoring
- [ ] Set up periodic health checks
- [ ] Monitor connection status
- [ ] Alert on failures
- [ ] Track uptime metrics

## Phase 8: Production Readiness

### Documentation
- [ ] Review `SETUP_GUIDE.md`
- [ ] Review `ARCHITECTURE.md`
- [ ] Review `README.md`
- [ ] Document any custom configurations

### Backup & Recovery
- [ ] Verify local SQLite backups work
- [ ] Test cloud recovery process
- [ ] Document recovery procedures
- [ ] Test disaster recovery plan

### Security Audit
- [ ] Verify RLS policies are correct
- [ ] Check storage bucket permissions
- [ ] Verify credentials are secure
- [ ] Review access logs

### Performance Baseline
- [ ] Document baseline performance metrics
- [ ] Set up monitoring alerts
- [ ] Establish SLA targets
- [ ] Plan for scaling

## Phase 9: Deployment

### Pre-Deployment
- [ ] All checklist items completed
- [ ] All tests passing
- [ ] No errors in logs
- [ ] Performance acceptable

### Deployment
- [ ] Deploy app to test devices
- [ ] Verify backend connection
- [ ] Test all sync operations
- [ ] Monitor for errors

### Post-Deployment
- [ ] Monitor sync_logs for issues
- [ ] Check user feedback
- [ ] Monitor performance metrics
- [ ] Be ready to rollback if needed

## Phase 10: Maintenance

### Regular Tasks
- [ ] Weekly: Review sync_logs for errors
- [ ] Weekly: Check storage usage
- [ ] Monthly: Verify backups
- [ ] Monthly: Review performance metrics
- [ ] Quarterly: Security audit

### Optimization
- [ ] Monitor slow queries
- [ ] Optimize indexes if needed
- [ ] Clean up old sync logs
- [ ] Archive old documents

### Updates
- [ ] Keep Supabase SDK updated
- [ ] Monitor for security patches
- [ ] Test updates in staging first
- [ ] Deploy to production

---

## Quick Status Check

Run this command to verify everything is working:

```dart
import 'services/backend_health_check.dart';
import 'utils/backend_test_utils.dart';

// Quick check
final status = await BackendHealthCheck.checkConnection();
print('Backend Healthy: ${status.isHealthy}');

// Full diagnostics
await BackendHealthCheck.printDiagnostics();

// Run all tests
final results = await BackendTestUtils.runAllTests();
```

---

## Support Resources

- **Supabase Docs**: https://supabase.com/docs
- **Flutter Supabase**: https://supabase.com/docs/reference/flutter/introduction
- **Project Dashboard**: https://app.supabase.com/project/aowgmjiezwydhluigkuc
- **Backend Guide**: See `SETUP_GUIDE.md`
- **Architecture**: See `ARCHITECTURE.md`

---

**Checklist Version**: 1.0
**Last Updated**: April 2026
**Status**: Ready for Use

## Notes

Use this space to track your progress:

```
Date: ___________
Completed by: ___________
Notes: ___________________________________________
       ___________________________________________
       ___________________________________________
```

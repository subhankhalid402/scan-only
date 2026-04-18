import 'package:flutter/material.dart';
import '../services/backend_health_check.dart';
import '../utils/backend_test_utils.dart';
import '../services/cloud_backup_service.dart';

/// Setup screen to verify backend connection
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String _status = 'Ready to test...';
  bool _isLoading = false;
  final List<String> _logs = [];

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
      _status = 'Testing...';
    });

    _addLog('🔍 Starting backend connection test...\n');

    try {
      // Test 1: Health check
      _addLog('📡 Test 1: Checking Supabase availability...');
      final status = await BackendHealthCheck.checkConnection();

      if (status.supabaseAvailable) {
        _addLog('✓ Supabase is available');
      } else {
        _addLog('✗ Supabase is not available');
      }

      // Test 2: Client
      if (status.clientInitialized) {
        _addLog('✓ Client initialized');
      } else {
        _addLog('✗ Client not initialized');
      }

      // Test 3: Connection
      if (status.connectionWorking) {
        _addLog('✓ Database connection working');
      } else {
        _addLog('✗ Database connection failed');
      }

      // Test 4: Authentication
      if (status.authenticated) {
        _addLog('✓ Authenticated (User: ${status.userId})');
      } else {
        _addLog('✗ Authentication failed');
      }

      // Final status
      _addLog('\n${'=' * 50}');
      if (status.isHealthy) {
        _addLog('✅ Backend is HEALTHY and ready to use!');
        setState(() => _status = 'Connected ✅');
      } else {
        _addLog('⚠️  Backend has issues: ${status.message}');
        setState(() => _status = 'Error: ${status.message}');
      }
      _addLog('=' * 50);
    } catch (e) {
      _addLog('❌ Error: $e');
      setState(() => _status = 'Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _runFullTests() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
      _status = 'Running tests...';
    });

    _addLog('🧪 Running full backend test suite...\n');

    try {
      final results = await BackendTestUtils.runAllTests();

      _addLog('\n📊 Test Results:');
      results.forEach((test, result) {
        if (result is Map) {
          final passed = result['passed'] == true;
          final icon = passed ? '✓' : '✗';
          _addLog('$icon $test: ${result['message']}');
        }
      });

      setState(() => _status = 'Tests completed');
    } catch (e) {
      _addLog('❌ Error running tests: $e');
      setState(() => _status = 'Error: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _testSync() async {
    setState(() {
      _isLoading = true;
      _logs.clear();
      _status = 'Testing sync...';
    });

    _addLog('📤 Testing cloud sync...\n');

    try {
      _addLog('Checking for pending uploads...');
      final result = await CloudBackupService.instance.syncPendingUploads();

      _addLog('✓ Sync completed');
      _addLog('  Uploaded: ${result.uploaded}');
      _addLog('  Failed: ${result.failed}');
      _addLog('  Newly queued (local→queued): ${result.newlyQueuedCount}');
      _addLog('  Still queued after run: ${result.pendingUploadCount}');

      if (result.uploaded > 0) {
        _addLog('\n✅ Documents synced successfully!');
        setState(() => _status = 'Sync successful ✅');
      } else if (result.failed > 0) {
        _addLog('\n⚠️  Some documents failed to sync');
        setState(() => _status = 'Sync had errors');
      } else if (result.pendingUploadCount > 0) {
        _addLog('\n⚠️  Documents are queued but not uploaded (check Supabase / network)');
        setState(() => _status = 'Upload pending');
      } else {
        _addLog('\nℹ️  No documents to sync');
        setState(() => _status = 'No pending uploads');
      }
    } catch (e) {
      _addLog('❌ Sync error: $e');
      setState(() => _status = 'Sync error: $e');
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Setup & Testing'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            Card(
              color: _status.contains('✅')
                  ? Colors.green[50]
                  : _status.contains('Error')
                      ? Colors.red[50]
                      : Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _status.contains('✅')
                          ? Icons.check_circle
                          : _status.contains('Error')
                              ? Icons.error_outline
                              : Icons.info_outline,
                      color: _status.contains('✅')
                          ? Colors.green
                          : _status.contains('Error')
                              ? Colors.red
                              : Colors.blue,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _status,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Test Buttons
            Text(
              'Tests',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: const Icon(Icons.cloud_queue),
                  label: const Text('Test Connection'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _runFullTests,
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Run All Tests'),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testSync,
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Test Sync'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Logs
            Text(
              'Logs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              constraints: const BoxConstraints(minHeight: 200),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : _logs.isEmpty
                      ? Center(
                          child: Text(
                            'Click a button to run tests',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Text(
                            _logs.join('\n'),
                            style: const TextStyle(
                              color: Colors.green,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 24),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Setup Instructions',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Click "Test Connection" to verify backend\n'
                    '2. Click "Run All Tests" for detailed diagnostics\n'
                    '3. Click "Test Sync" to test document upload\n'
                    '4. Check logs for any errors\n'
                    '5. If all tests pass, backend is ready!',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

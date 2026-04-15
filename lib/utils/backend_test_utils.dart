import 'package:flutter/foundation.dart';
import '../services/backend_health_check.dart';
import '../services/supabase_service.dart';

/// Utility functions for testing backend connectivity
class BackendTestUtils {
  BackendTestUtils._();

  /// Run all backend tests and return results
  static Future<Map<String, dynamic>> runAllTests() async {
    final results = <String, dynamic>{};

    debugPrint('🧪 Starting Backend Tests...\n');

    // Test 1: Supabase Availability
    results['supabase_available'] = await _testSupabaseAvailability();

    // Test 2: Client Connection
    results['client_connection'] = await _testClientConnection();

    // Test 3: Database Query
    results['database_query'] = await _testDatabaseQuery();

    // Test 4: Authentication
    results['authentication'] = await _testAuthentication();

    // Test 5: Health Check
    results['health_check'] = await _testHealthCheck();

    debugPrint('\n✅ Backend Tests Complete\n');
    _printTestSummary(results);

    return results;
  }

  static Future<Map<String, dynamic>> _testSupabaseAvailability() async {
    debugPrint('📡 Test 1: Supabase Availability');
    try {
      final available = SupabaseService.isAvailable;
      debugPrint('   Result: ${available ? "✓ Available" : "✗ Not Available"}');
      return {
        'passed': available,
        'message': available ? 'Supabase is available' : 'Supabase is not available',
      };
    } catch (e) {
      debugPrint('   Error: $e');
      return {'passed': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _testClientConnection() async {
    debugPrint('🔌 Test 2: Client Connection');
    try {
      final client = SupabaseService.client;
      final connected = client != null;
      debugPrint('   Result: ${connected ? "✓ Connected" : "✗ Not Connected"}');
      return {
        'passed': connected,
        'message': connected ? 'Client is connected' : 'Client is null',
      };
    } catch (e) {
      debugPrint('   Error: $e');
      return {'passed': false, 'message': 'Error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _testDatabaseQuery() async {
    debugPrint('🗄️  Test 3: Database Query');
    try {
      final client = SupabaseService.client;
      if (client == null) {
        debugPrint('   Result: ✗ Client is null');
        return {'passed': false, 'message': 'Client is null'};
      }

      final response = await client.from('cloud_documents').select('id').limit(1);
      debugPrint('   Result: ✓ Query successful (${response.length} records)');
      return {
        'passed': true,
        'message': 'Database query successful',
        'records': response.length,
      };
    } catch (e) {
      debugPrint('   Error: $e');
      return {'passed': false, 'message': 'Query failed: $e'};
    }
  }

  static Future<Map<String, dynamic>> _testAuthentication() async {
    debugPrint('🔐 Test 4: Authentication');
    try {
      final client = SupabaseService.client;
      if (client == null) {
        debugPrint('   Result: ✗ Client is null');
        return {'passed': false, 'message': 'Client is null'};
      }

      var session = client.auth.currentSession;
      if (session != null) {
        debugPrint('   Result: ✓ Already authenticated (User: ${session.user.id})');
        return {
          'passed': true,
          'message': 'User is authenticated',
          'user_id': session.user.id,
        };
      }

      debugPrint('   Attempting anonymous sign-in...');
      await client.auth.signInAnonymously();
      session = client.auth.currentSession;

      if (session != null) {
        debugPrint('   Result: ✓ Anonymous sign-in successful (User: ${session.user.id})');
        return {
          'passed': true,
          'message': 'Anonymous sign-in successful',
          'user_id': session.user.id,
        };
      } else {
        debugPrint('   Result: ✗ Sign-in failed');
        return {'passed': false, 'message': 'Sign-in failed'};
      }
    } catch (e) {
      debugPrint('   Error: $e');
      return {'passed': false, 'message': 'Auth error: $e'};
    }
  }

  static Future<Map<String, dynamic>> _testHealthCheck() async {
    debugPrint('❤️  Test 5: Overall Health Check');
    try {
      final status = await BackendHealthCheck.checkConnection();
      debugPrint('   Result: ${status.isHealthy ? "✓ Healthy" : "✗ Unhealthy"}');
      debugPrint('   Message: ${status.message}');
      return {
        'passed': status.isHealthy,
        'message': status.message,
        'details': status.toString(),
      };
    } catch (e) {
      debugPrint('   Error: $e');
      return {'passed': false, 'message': 'Health check error: $e'};
    }
  }

  static void _printTestSummary(Map<String, dynamic> results) {
    int passed = 0;
    int failed = 0;

    results.forEach((test, result) {
      if (result is Map && result['passed'] == true) {
        passed++;
      } else {
        failed++;
      }
    });

    debugPrint('═' * 50);
    debugPrint('📊 Test Summary');
    debugPrint('═' * 50);
    debugPrint('Passed: $passed/${results.length}');
    debugPrint('Failed: $failed/${results.length}');
    debugPrint('Status: ${failed == 0 ? "✅ ALL TESTS PASSED" : "⚠️  SOME TESTS FAILED"}');
    debugPrint('═' * 50);
  }

  /// Quick connectivity test (returns true/false)
  static Future<bool> isBackendConnected() async {
    try {
      final status = await BackendHealthCheck.checkConnection();
      return status.isHealthy;
    } catch (_) {
      return false;
    }
  }

  /// Get detailed status as string
  static Future<String> getStatusString() async {
    final status = await BackendHealthCheck.checkConnection();
    return '''
Backend Status Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Supabase Available: ${status.supabaseAvailable}
Client Initialized: ${status.clientInitialized}
Connection Working: ${status.connectionWorking}
Authenticated: ${status.authenticated}
User ID: ${status.userId ?? 'N/A'}
Overall Health: ${status.isHealthy ? '✓ Healthy' : '✗ Unhealthy'}
Message: ${status.message}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
''';
  }
}

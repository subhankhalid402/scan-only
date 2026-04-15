import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

/// Backend health check and diagnostics
class BackendHealthCheck {
  BackendHealthCheck._();

  static Future<BackendHealthStatus> checkConnection() async {
    final status = BackendHealthStatus();

    // Check 1: Supabase availability
    status.supabaseAvailable = SupabaseService.isAvailable;
    debugPrint('[Backend Check] Supabase Available: ${status.supabaseAvailable}');

    if (!status.supabaseAvailable) {
      status.message = 'Supabase is not initialized. Cloud features disabled.';
      return status;
    }

    // Check 2: Client initialization
    final client = SupabaseService.client;
    if (client == null) {
      status.message = 'Supabase client is null.';
      return status;
    }
    status.clientInitialized = true;
    debugPrint('[Backend Check] Client Initialized: true');

    // Check 3: Test connection with a simple query
    try {
      final response = await client.from('cloud_documents').select('id').limit(1);
      status.connectionWorking = true;
      status.message = 'Backend connection successful.';
      debugPrint('[Backend Check] Connection Working: true');
    } catch (e) {
      status.connectionWorking = false;
      status.message = 'Connection test failed: $e';
      debugPrint('[Backend Check] Connection Error: $e');
    }

    // Check 4: Authentication status
    try {
      final session = client.auth.currentSession;
      if (session != null) {
        status.authenticated = true;
        status.userId = session.user.id;
        debugPrint('[Backend Check] Authenticated: true (User: ${session.user.id})');
      } else {
        status.authenticated = false;
        debugPrint('[Backend Check] Not authenticated. Attempting anonymous sign-in...');
        
        // Try anonymous sign-in
        try {
          await client.auth.signInAnonymously();
          status.authenticated = true;
          status.userId = client.auth.currentSession?.user.id;
          debugPrint('[Backend Check] Anonymous sign-in successful');
        } catch (authError) {
          status.authenticated = false;
          status.message = 'Authentication failed: $authError';
          debugPrint('[Backend Check] Anonymous sign-in failed: $authError');
        }
      }
    } catch (e) {
      status.authenticated = false;
      debugPrint('[Backend Check] Auth check error: $e');
    }

    status.isHealthy = status.supabaseAvailable && 
                       status.clientInitialized && 
                       status.connectionWorking;

    return status;
  }

  static Future<void> printDiagnostics() async {
    debugPrint('=== Backend Connection Diagnostics ===');
    final status = await checkConnection();
    debugPrint('Supabase Available: ${status.supabaseAvailable}');
    debugPrint('Client Initialized: ${status.clientInitialized}');
    debugPrint('Connection Working: ${status.connectionWorking}');
    debugPrint('Authenticated: ${status.authenticated}');
    debugPrint('User ID: ${status.userId ?? "N/A"}');
    debugPrint('Status: ${status.message}');
    debugPrint('Overall Health: ${status.isHealthy ? "✓ Healthy" : "✗ Unhealthy"}');
    debugPrint('=====================================');
  }
}

class BackendHealthStatus {
  bool supabaseAvailable = false;
  bool clientInitialized = false;
  bool connectionWorking = false;
  bool authenticated = false;
  String? userId;
  String message = 'Checking backend connection...';
  bool isHealthy = false;

  @override
  String toString() {
    return '''
BackendHealthStatus(
  supabaseAvailable: $supabaseAvailable,
  clientInitialized: $clientInitialized,
  connectionWorking: $connectionWorking,
  authenticated: $authenticated,
  userId: $userId,
  message: $message,
  isHealthy: $isHealthy
)''';
  }
}

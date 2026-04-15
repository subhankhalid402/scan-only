import 'package:flutter/foundation.dart';
import 'services/backend_health_check.dart';
import 'utils/backend_test_utils.dart';

/// Quick connection test - run this to check if app is connected to Supabase
Future<void> testSupabaseConnection() async {
  debugPrint('=' * 70);
  debugPrint('🧪 SUPABASE CONNECTION TEST');
  debugPrint('=' * 70);

  try {
    // Test 1: Health Check
    debugPrint('\n📡 Test 1: Health Check');
    debugPrint('─' * 70);
    final status = await BackendHealthCheck.checkConnection();

    debugPrint('Supabase Available: ${status.supabaseAvailable ? "✅" : "❌"}');
    debugPrint('Client Initialized: ${status.clientInitialized ? "✅" : "❌"}');
    debugPrint('Connection Working: ${status.connectionWorking ? "✅" : "❌"}');
    debugPrint('Authenticated: ${status.authenticated ? "✅" : "❌"}');
    debugPrint('User ID: ${status.userId ?? "N/A"}');

    // Test 2: Overall Status
    debugPrint('\n📊 Overall Status');
    debugPrint('─' * 70);
    if (status.isHealthy) {
      debugPrint('✅ CONNECTED - Backend is working!');
    } else {
      debugPrint('❌ NOT CONNECTED - ${status.message}');
    }

    // Test 3: Detailed Diagnostics
    debugPrint('\n🔍 Detailed Diagnostics');
    debugPrint('─' * 70);
    await BackendHealthCheck.printDiagnostics();

    // Test 4: Full Test Suite
    debugPrint('\n🧪 Running Full Test Suite');
    debugPrint('─' * 70);
    final results = await BackendTestUtils.runAllTests();

    // Summary
    debugPrint('\n' + '=' * 70);
    debugPrint('✅ TEST COMPLETE');
    debugPrint('=' * 70);

    if (status.isHealthy) {
      debugPrint('\n🎉 SUCCESS! Your app is connected to Supabase!');
      debugPrint('\nNext steps:');
      debugPrint('1. Create a test document');
      debugPrint('2. Sync to cloud');
      debugPrint('3. Check cloud_documents table');
      debugPrint('4. Generate public URL');
    } else {
      debugPrint('\n⚠️  CONNECTION ISSUES DETECTED');
      debugPrint('\nTroubleshooting:');
      debugPrint('1. Check internet connection');
      debugPrint('2. Verify Supabase credentials in main.dart');
      debugPrint('3. Check Supabase project status');
      debugPrint('4. Verify RLS policies are enabled');
    }

    debugPrint('\n' + '=' * 70);
  } catch (e) {
    debugPrint('❌ ERROR: $e');
    debugPrint('=' * 70);
  }
}

/// Simple connection check - returns true/false
Future<bool> isConnectedToSupabase() async {
  try {
    final status = await BackendHealthCheck.checkConnection();
    return status.isHealthy;
  } catch (e) {
    debugPrint('Connection check error: $e');
    return false;
  }
}

/// Get connection status as string
Future<String> getConnectionStatus() async {
  try {
    final status = await BackendHealthCheck.checkConnection();
    return status.isHealthy ? 'Connected ✅' : 'Not Connected ❌';
  } catch (e) {
    return 'Error: $e';
  }
}

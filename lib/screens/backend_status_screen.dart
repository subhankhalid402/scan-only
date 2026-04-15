import 'package:flutter/material.dart';
import '../services/backend_health_check.dart';

/// Screen to display backend connection status and diagnostics
class BackendStatusScreen extends StatefulWidget {
  const BackendStatusScreen({super.key});

  @override
  State<BackendStatusScreen> createState() => _BackendStatusScreenState();
}

class _BackendStatusScreenState extends State<BackendStatusScreen> {
  late Future<BackendHealthStatus> _healthCheckFuture;

  @override
  void initState() {
    super.initState();
    _healthCheckFuture = BackendHealthCheck.checkConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Connection Status'),
        elevation: 0,
      ),
      body: FutureBuilder<BackendHealthStatus>(
        future: _healthCheckFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final status = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Overall Status Card
                Card(
                  color: status.isHealthy ? Colors.green[50] : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          status.isHealthy ? Icons.check_circle : Icons.error,
                          color: status.isHealthy ? Colors.green : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                status.isHealthy ? 'Backend Connected' : 'Backend Disconnected',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: status.isHealthy ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                status.message,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Detailed Status
                Text(
                  'Connection Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildStatusItem(
                  'Supabase Available',
                  status.supabaseAvailable,
                ),
                _buildStatusItem(
                  'Client Initialized',
                  status.clientInitialized,
                ),
                _buildStatusItem(
                  'Connection Working',
                  status.connectionWorking,
                ),
                _buildStatusItem(
                  'Authenticated',
                  status.authenticated,
                ),
                const SizedBox(height: 16),

                // User Info
                if (status.userId != null) ...[
                  Text(
                    'User Information',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User ID:',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          status.userId!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Retry Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _healthCheckFuture = BackendHealthCheck.checkConnection();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Connection Check'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isHealthy ? Icons.check_circle : Icons.cancel,
            color: isHealthy ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          Text(
            isHealthy ? 'OK' : 'FAILED',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isHealthy ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

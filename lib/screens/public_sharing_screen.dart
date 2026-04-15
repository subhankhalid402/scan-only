import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/public_url_service.dart';
import '../widgets/public_url_widget.dart';

/// Screen to manage and share public URLs
class PublicSharingScreen extends StatefulWidget {
  final String userId;
  final int documentId;
  final String documentName;
  final String fileExtension;

  const PublicSharingScreen({
    super.key,
    required this.userId,
    required this.documentId,
    required this.documentName,
    required this.fileExtension,
  });

  @override
  State<PublicSharingScreen> createState() => _PublicSharingScreenState();
}

class _PublicSharingScreenState extends State<PublicSharingScreen> {
  late String _publicUrl;
  bool _isLoading = false;
  List<String> _userUrls = [];

  @override
  void initState() {
    super.initState();
    _generatePublicUrl();
    _loadUserUrls();
  }

  void _generatePublicUrl() {
    _publicUrl = PublicUrlService.getPublicUrlForDocument(
      userId: widget.userId,
      documentId: widget.documentId,
      extension: widget.fileExtension,
    );
  }

  Future<void> _loadUserUrls() async {
    setState(() => _isLoading = true);
    try {
      final urls = await PublicUrlService.getUserPublicUrls(widget.userId);
      setState(() => _userUrls = urls);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading URLs: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _copyUrl() {
    Clipboard.setData(ClipboardData(text: _publicUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ URL copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareUrl() {
    // You can use share_plus package
    // Share.share(_publicUrl);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share URL: $_publicUrl')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Document'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Document',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.documentName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ID: ${widget.documentId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Public URL Section
            Text(
              'Public URL',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
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
                    'This URL is publicly accessible:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _publicUrl,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyUrl,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy URL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareUrl,
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ℹ️ Public Access',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Anyone with this URL can view the document\n'
                    '• No authentication required\n'
                    '• URL is permanent\n'
                    '• Share safely with others',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // User Documents Section
            Text(
              'Your Public Documents',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_userUrls.isEmpty)
              Center(
                child: Text(
                  'No public documents yet',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _userUrls.length,
                itemBuilder: (context, index) {
                  final url = _userUrls[index];
                  return ListTile(
                    leading: const Icon(Icons.link),
                    title: Text('Document ${index + 1}'),
                    subtitle: Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: url));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✓ Copied')),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

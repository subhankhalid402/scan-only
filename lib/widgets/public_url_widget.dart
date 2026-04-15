import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/public_url_service.dart';

/// Widget to display and share public URLs
class PublicUrlWidget extends StatefulWidget {
  final String filePath;
  final String? title;
  final VoidCallback? onCopy;

  const PublicUrlWidget({
    super.key,
    required this.filePath,
    this.title,
    this.onCopy,
  });

  @override
  State<PublicUrlWidget> createState() => _PublicUrlWidgetState();
}

class _PublicUrlWidgetState extends State<PublicUrlWidget> {
  late String _publicUrl;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _publicUrl = PublicUrlService.getPublicUrl(widget.filePath);
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: _publicUrl));
    setState(() => _copied = true);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ URL copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });

    widget.onCopy?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title != null) ...[
              Text(
                widget.title!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
            ],
            // URL Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Public URL:',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _publicUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _copyToClipboard,
                    icon: Icon(_copied ? Icons.check : Icons.copy),
                    label: Text(_copied ? 'Copied!' : 'Copy URL'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _copied ? Colors.green : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // Open URL in browser
                    // You can use: url_launcher package
                  },
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple URL display widget
class SimplePublicUrlDisplay extends StatelessWidget {
  final String filePath;

  const SimplePublicUrlDisplay({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final url = PublicUrlService.getPublicUrl(filePath);

    return ListTile(
      leading: const Icon(Icons.link),
      title: const Text('Public URL'),
      subtitle: Text(
        url.isEmpty ? 'Failed to generate URL' : url,
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
  }
}

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// "Load more" row shown at the end of a paged list.
class LoadMoreButton extends StatelessWidget {
  final int shown;
  final VoidCallback onPressed;
  final String? hint;

  const LoadMoreButton({
    super.key,
    required this.shown,
    required this.onPressed,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(
            'Showing the first $shown',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.expand_more, color: AppTheme.neonCyan),
            label: const Text(
              'Load more',
              style: TextStyle(color: AppTheme.neonCyan),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: AppTheme.neonCyan.withValues(alpha: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

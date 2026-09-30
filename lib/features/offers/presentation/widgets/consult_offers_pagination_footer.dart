import 'package:flutter/material.dart';

class ConsultOffersPaginationFooter extends StatelessWidget {
  const ConsultOffersPaginationFooter({
    super.key,
    required this.hasMore,
    required this.loading,
    required this.failed,
    required this.onLoad,
  });

  final bool hasMore;
  final bool loading;
  final bool failed;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        children: [
          Text(
            failed
                ? 'La suite des annonces n’a pas pu être chargée.'
                : 'D’autres annonces restent à parcourir.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('consult-load-more'),
            onPressed: loading ? null : onLoad,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            label: Text(
              loading
                  ? 'Chargement…'
                  : failed
                      ? 'Réessayer'
                      : 'Continuer la recherche',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

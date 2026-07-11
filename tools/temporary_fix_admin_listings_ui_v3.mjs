import { readFile, writeFile } from 'node:fs/promises';

const path = 'lib/admin/listings/admin_listings_management_page.dart';
let source = await readFile(path, 'utf8');

const finallyBefore = `    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
`;
const finallyAfter = `    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
`;
if (source.includes(finallyBefore)) {
  source = source.replace(finallyBefore, finallyAfter);
} else if (!source.includes(finallyAfter)) {
  throw new Error('load page finally block not found');
}

const reasonFunction = `  Future<String?> _askDeletionReason() async {
    var reason = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: !_deleting,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text('Supprimer \${_selectedIds.length} annonce(s) ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Les annonces réussies seront archivées avant suppression. '
                'Les échecs resteront sélectionnés.',
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                onChanged: (value) => reason = value,
                decoration: const InputDecoration(
                  labelText: 'Motif obligatoire',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(reason.trim()),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

`;
const reasonPattern = /  Future<String\?> _askDeletionReason\(\) async \{[\s\S]*?\n  \}\n\n  Future<void> _deleteSelected\(\) async \{/;
const matches = [...source.matchAll(new RegExp(reasonPattern.source, 'g'))];
if (matches.length !== 1) {
  throw new Error(`deletion reason function: expected one match, found ${matches.length}`);
}
source = source.replace(
  reasonPattern,
  `${reasonFunction}  Future<void> _deleteSelected() async {`,
);

await writeFile(path, source, 'utf8');
console.log('admin listings UI fixes applied');

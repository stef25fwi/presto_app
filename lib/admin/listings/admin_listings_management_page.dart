import 'dart:async';

import 'package:flutter/material.dart';

import '../shared/admin_bulk_listing_service.dart';
import 'admin_listing_record.dart';
import 'admin_listings_repository.dart';

class AdminListingsManagementPage extends StatefulWidget {
  const AdminListingsManagementPage({
    super.key,
    this.repository,
    this.deletionService,
  });

  final AdminListingsRepository? repository;
  final AdminBulkListingService? deletionService;

  @override
  State<AdminListingsManagementPage> createState() =>
      _AdminListingsManagementPageState();
}

class _AdminListingsManagementPageState
    extends State<AdminListingsManagementPage> {
  static const int _pageSize = 30;

  late final AdminListingsRepository _repository;
  late final AdminBulkListingService _deletionService;

  final List<AdminListingRecord> _items = <AdminListingRecord>[];
  final Set<String> _selectedIds = <String>{};

  Object? _cursor;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _deleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? FirestoreAdminListingsRepository();
    _deletionService = widget.deletionService ?? AdminBulkListingService();
    unawaited(_loadPage(reset: true));
  }

  Future<void> _loadPage({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _errorMessage = null;
        _cursor = null;
        _hasMore = true;
      });
    } else {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = await _repository.fetchPage(
        startAfter: reset ? null : _cursor,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _items
            ..clear()
            ..addAll(page.items);
          _selectedIds.clear();
        } else {
          final knownIds = _items.map((item) => item.id).toSet();
          _items.addAll(
            page.items.where((item) => !knownIds.contains(item.id)),
          );
        }
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Chargement impossible : $error');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _toggleSelection(String listingId, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(listingId);
      } else {
        _selectedIds.remove(listingId);
      }
    });
  }

  void _toggleAllVisible() {
    final visibleIds = _items.map((item) => item.id).toSet();
    final allSelected =
        visibleIds.isNotEmpty && visibleIds.every(_selectedIds.contains);
    setState(() {
      if (allSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  Future<String?> _askDeletionReason() async {
    var reason = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: !_deleting,
      builder: (dialogContext) {
        return AlertDialog(
          scrollable: true,
          title: Text('Supprimer ${_selectedIds.length} annonce(s) ?'),
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

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty || _deleting) return;
    final reason = await _askDeletionReason();
    if (!mounted || reason == null) return;
    if (reason.isEmpty) {
      _showMessage('Le motif de suppression est obligatoire.');
      return;
    }

    final requestedIds = List<String>.from(_selectedIds);
    setState(() => _deleting = true);
    try {
      final summary = await _deletionService.deleteListings(
        listingIds: requestedIds,
        reason: reason,
      );
      if (!mounted) return;
      final succeededIds = summary.succeededIds.toSet();
      setState(() {
        _items.removeWhere((item) => succeededIds.contains(item.id));
        _selectedIds.removeAll(succeededIds);
      });

      if (summary.failedCount == 0) {
        _showMessage(
          '${summary.succeededCount} annonce(s) supprimée(s) et archivée(s).',
        );
      } else {
        _showMessage(
          '${summary.succeededCount} suppression(s) réussie(s), '
          '${summary.failedCount} échec(s). Les échecs restent sélectionnés.',
        );
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('Suppression impossible : $error');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final allVisibleSelected = _items.isNotEmpty &&
        _items.every((item) => _selectedIds.contains(item.id));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des annonces'),
        actions: <Widget>[
          if (_items.isNotEmpty)
            IconButton(
              tooltip: allVisibleSelected
                  ? 'Désélectionner toutes les annonces visibles'
                  : 'Sélectionner toutes les annonces visibles',
              onPressed: _deleting ? null : _toggleAllVisible,
              icon: Icon(
                allVisibleSelected
                    ? Icons.deselect_rounded
                    : Icons.select_all_rounded,
              ),
            ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _deleting ? null : () => _loadPage(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _selectedIds.isEmpty
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                onPressed: _deleting ? null : _deleteSelected,
                icon: _deleting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded),
                label: Text(
                  _deleting
                      ? 'Suppression en cours…'
                      : 'Supprimer ${_selectedIds.length} sélectionnée(s)',
                ),
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _items.isEmpty) {
      return _AdminListingsMessage(
        icon: Icons.cloud_off_rounded,
        message: _errorMessage!,
        actionLabel: 'Réessayer',
        onAction: () => _loadPage(reset: true),
      );
    }
    if (_items.isEmpty) {
      return _AdminListingsMessage(
        icon: Icons.inventory_2_outlined,
        message: 'Aucune annonce à administrer.',
        actionLabel: 'Actualiser',
        onAction: () => _loadPage(reset: true),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(reset: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _hasMore
                  ? OutlinedButton.icon(
                      onPressed: _loadingMore || _deleting
                          ? null
                          : () => _loadPage(reset: false),
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: const Text('Charger la suite'),
                    )
                  : const Center(
                      child: Text('Toutes les annonces sont chargées.'),
                    ),
            );
          }

          final item = _items[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: CheckboxListTile(
              value: _selectedIds.contains(item.id),
              onChanged: _deleting
                  ? null
                  : (value) => _toggleSelection(item.id, value == true),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(_subtitleFor(item)),
              secondary: _StatusChip(status: item.status),
            ),
          );
        },
      ),
    );
  }

  String _subtitleFor(AdminListingRecord item) {
    final parts = <String>[
      if (item.city.isNotEmpty) item.city,
      if (item.ownerId.isNotEmpty) 'Auteur ${_shortId(item.ownerId)}',
      if (item.createdAt != null) _formatDate(item.createdAt!),
    ];
    return parts.isEmpty ? 'ID ${_shortId(item.id)}' : parts.join(' • ');
  }

  String _shortId(String value) {
    return value.length <= 10 ? value : '${value.substring(0, 10)}…';
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final active = status == 'active' || status == 'published';
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(status),
      avatar: Icon(
        active ? Icons.visibility_rounded : Icons.visibility_off_rounded,
        size: 16,
      ),
    );
  }
}

class _AdminListingsMessage extends StatelessWidget {
  const _AdminListingsMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

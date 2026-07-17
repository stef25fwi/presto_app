import 'package:flutter/material.dart';

import '../../features/subscriptions/subscription_credit_service.dart';
import '../../features/subscriptions/subscription_credits_card.dart';
import '../../services/journey_local_storage_service.dart';
import '../../services/journey_pdf_export_service.dart';
import '../toolbox_je_me_lance_page.dart';
import 'saved_journey_summary_page.dart';

const _orange = Color(0xFFFF6600);
const _blue = Color(0xFF1A73E8);
const _background = Color(0xFFF6F7FB);
const _text = Color(0xFF111827);
const _muted = Color(0xFF6B7280);
const _border = Color(0xFFE5E7EB);

class MonEntrepriseParcoursLibraryPage extends StatefulWidget {
  const MonEntrepriseParcoursLibraryPage({super.key});

  @override
  State<MonEntrepriseParcoursLibraryPage> createState() =>
      _MonEntrepriseParcoursLibraryPageState();
}

class _MonEntrepriseParcoursLibraryPageState
    extends State<MonEntrepriseParcoursLibraryPage> {
  static const _storage = JourneyLocalStorageService();
  static const _pdf = JourneyPdfExportService();

  bool _loading = true;
  String? _error;
  String? _busyId;
  List<SavedJourneyRecord> _journeys = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final journeys = await _storage.loadLibrary();
      if (!mounted) return;
      setState(() {
        _journeys = journeys;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger vos parcours pour le moment.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text('Je crée mon entreprise'),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                children: [
                  const SubscriptionCreditsInlineBadges(
                    kinds: [
                      SubscriptionCreditKind.journeys,
                      SubscriptionCreditKind.pdf,
                    ],
                  ),
                  const SizedBox(height: 16),
                  _LibraryHeader(count: _journeys.length),
                  const SizedBox(height: 12),
                  if (_error != null)
                    _MessageCard(
                      icon: Icons.error_outline_rounded,
                      message: _error!,
                      action: TextButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    )
                  else if (_journeys.isEmpty)
                    const _MessageCard(
                      icon: Icons.route_outlined,
                      message:
                          'Aucun parcours sauvegardé. Créez-en un pour le retrouver sur tous vos appareils.',
                    )
                  else
                    for (final journey in _journeys) ...[
                      _JourneyTile(
                        journey: journey,
                        busy: _busyId == journey.id,
                        onOpen: () => _open(journey.snapshot),
                        onPdf: () => _export(journey),
                        onDelete: () => _delete(journey),
                      ),
                      const SizedBox(height: 10),
                    ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(58),
                    ),
                    onPressed: () => Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => const ToolboxJeMeLancePage(),
                          ),
                        )
                        .then((_) => _load()),
                    icon: const Icon(Icons.add_road_rounded),
                    label: const Text(
                      'Créer un nouveau parcours',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _open(Map<String, dynamic> snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedJourneySummaryPage(snapshot: snapshot),
      ),
    );
  }

  Future<void> _export(SavedJourneyRecord journey) async {
    if (_busyId != null) return;
    setState(() => _busyId = journey.id);
    try {
      final ok = await _pdf.downloadJourneyPdf(journey.snapshot);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF généré et téléchargé.')),
        );
      }
    } on SubscriptionQuotaExceededException catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Crédit PDF atteint'),
          content: Text(error.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de générer le PDF : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(SavedJourneyRecord journey) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce parcours ?'),
        content: Text(
          '« ${journey.title.isEmpty ? 'Mon parcours personnalisé' : journey.title} » sera supprimé de tous vos appareils.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busyId != null) return;
    setState(() => _busyId = journey.id);
    try {
      await _storage.deleteLibraryJourney(journey.id);
      await _load();
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _LibraryHeader extends StatelessWidget {
  final int count;
  const _LibraryHeader({required this.count});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes parcours sauvegardés',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Synchronisés sur tous vos appareils.',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: _blue,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      );
}

class _JourneyTile extends StatelessWidget {
  final SavedJourneyRecord journey;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onPdf;
  final VoidCallback onDelete;

  const _JourneyTile({
    required this.journey,
    required this.busy,
    required this.onOpen,
    required this.onPdf,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = journey.title.isNotEmpty
        ? journey.title
        : journey.activity.isNotEmpty
            ? journey.activity
            : 'Mon parcours personnalisé';
    final detail = [journey.currentStatus, journey.region]
        .where((value) => value.isNotEmpty)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.route_rounded, color: _orange, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: const TextStyle(
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: busy ? null : onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onOpen,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Ouvrir'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _blue),
                  onPressed: busy ? null : onPdf,
                  icon: busy
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const _MessageCard({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: _muted, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
      );
}

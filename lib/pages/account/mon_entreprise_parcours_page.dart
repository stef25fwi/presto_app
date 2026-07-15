import 'package:flutter/material.dart';

import '../../features/subscriptions/journey_entitlements_service.dart';
import '../../features/subscriptions/subscription_models.dart';
import '../../services/journey_local_storage_service.dart';
import '../../services/journey_pdf_export_service.dart';
import '../toolbox_je_me_lance_page.dart';
import 'saved_journey_summary_page.dart';

const Color _kOrange = Color(0xFFFF6600);
const Color _kBg = Color(0xFFF6F7FB);

/// Onglet "Je crée mon entreprise" de la page "Mon compte iliPresto".
///
/// Affiche deux parcours distincts, stockés localement sur l'appareil :
/// - le parcours **véritablement sauvegardé** par l'utilisateur (action
///   explicite sur le bouton "Sauvegarder", limitée par le quota mensuel) ;
/// - le **dernier parcours de l'historique**, mis à jour automatiquement à
///   chaque parcours terminé, sans quota, et toujours écrasé par le suivant.
///
/// Ainsi qu'un rappel du quota mensuel de sauvegarde/export en fonction de
/// l'abonnement.
class MonEntrepriseParcoursPage extends StatefulWidget {
  const MonEntrepriseParcoursPage({super.key});

  @override
  State<MonEntrepriseParcoursPage> createState() =>
      _MonEntrepriseParcoursPageState();
}

class _MonEntrepriseParcoursPageState extends State<MonEntrepriseParcoursPage> {
  static const _localStorageService = JourneyLocalStorageService();
  static const _pdfExportService = JourneyPdfExportService();
  final _entitlementsService = JourneyEntitlementsService();

  bool _loading = true;
  bool _exportingPdf = false;
  Map<String, dynamic>? _savedSnapshot;
  Map<String, dynamic>? _historySnapshot;
  JourneyEntitlements? _entitlements;
  int _savesUsed = 0;
  int _pdfExportsUsed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final savedSnapshot = await _localStorageService.loadSnapshot();
    final historySnapshot = await _localStorageService.loadHistorySnapshot();
    final entitlements = await _entitlementsService.resolveEntitlements();
    final savesUsed = await _entitlementsService.getLocalSavesUsedThisMonth();
    final pdfUsed = await _entitlementsService.getPdfExportsUsedThisMonth();

    if (!mounted) return;
    setState(() {
      _savedSnapshot = savedSnapshot;
      _historySnapshot = historySnapshot;
      _entitlements = entitlements;
      _savesUsed = savesUsed;
      _pdfExportsUsed = pdfUsed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSaved = _savedSnapshot != null;
    final hasHistory = _historySnapshot != null;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Je crée mon entreprise'),
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                children: [
                  _buildQuotaCard(),
                  const SizedBox(height: 16),
                  if (!hasSaved && !hasHistory)
                    _EmptyState(onCreate: _openToolbox)
                  else ...[
                    const _SectionLabel('Mon parcours sauvegardé'),
                    const SizedBox(height: 8),
                    hasSaved
                        ? _JourneyCard(
                            snapshot: _savedSnapshot!,
                            dateLabel: 'Sauvegardé le',
                            isExportingPdf: _exportingPdf,
                            onResume: () => _openSavedJourney(_savedSnapshot!),
                            onExportPdf: () => _exportPdf(_savedSnapshot!),
                          )
                        : const _EmptyInlineNote(
                            'Aucun parcours sauvegardé pour le moment.',
                          ),
                    const SizedBox(height: 20),
                    const _SectionLabel('Dernier parcours consulté'),
                    const SizedBox(height: 8),
                    hasHistory
                        ? _JourneyCard(
                            snapshot: _historySnapshot!,
                            dateLabel: 'Généré le',
                            isExportingPdf: _exportingPdf,
                            onResume: () =>
                                _openSavedJourney(_historySnapshot!),
                            onExportPdf: () => _exportPdf(_historySnapshot!),
                          )
                        : const _EmptyInlineNote(
                            'Aucun parcours généré pour le moment.',
                          ),
                  ],
                ],
              ),
            ),
    );
  }

  void _openToolbox() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ToolboxJeMeLancePage()),
    );
  }

  void _openSavedJourney(Map<String, dynamic> snapshot) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SavedJourneySummaryPage(snapshot: snapshot),
      ),
    );
  }

  Future<void> _exportPdf(Map<String, dynamic> snapshot) async {
    if (_exportingPdf) return;

    setState(() => _exportingPdf = true);
    var loadingDialogOpen = false;

    void showLoadingDialog() {
      if (!mounted || loadingDialogOpen) return;
      loadingDialogOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          title: Text('Préparation du PDF'),
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Création du PDF avec logo et filigrane iliprestō...',
                ),
              ),
            ],
          ),
        ),
      ).whenComplete(() => loadingDialogOpen = false);
    }

    void closeLoadingDialog() {
      if (!mounted || !loadingDialogOpen) return;
      Navigator.of(context, rootNavigator: true).pop();
      loadingDialogOpen = false;
    }

    try {
      showLoadingDialog();

      final decision = await _entitlementsService.evaluatePdfExport();
      if (!mounted) return;

      if (!decision.allowed) {
        closeLoadingDialog();
        final quotaText = decision.requiresUpgrade
            ? 'L’export PDF est réservé aux abonnements iliprestō+ et ilipro.'
            : 'Quota PDF atteint pour ce mois-ci. Vous avez déjà utilisé ${decision.usedThisMonth} / ${decision.entitlements.maxPdfExportsPerMonth} export(s).';
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Export PDF indisponible'),
            content: Text(quotaText),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
        return;
      }

      final downloaded = await _pdfExportService.downloadJourneyPdf(snapshot);
      if (!mounted) return;
      closeLoadingDialog();

      if (downloaded) {
        await _entitlementsService.recordPdfExport();
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF généré et téléchargé avec succès.'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Téléchargement PDF annulé.')),
        );
      }
    } catch (e) {
      closeLoadingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de générer le PDF : $e')),
      );
    } finally {
      closeLoadingDialog();
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Widget _buildQuotaCard() {
    final entitlements = _entitlements;
    if (entitlements == null) return const SizedBox.shrink();

    final savesLabel = entitlements.hasUnlimitedLocalSaves
        ? 'Sauvegardes locales illimitées'
        : '$_savesUsed / ${entitlements.maxLocalSavesPerMonth} sauvegarde(s) locale(s) utilisée(s) ce mois-ci';
    final pdfLabel = !entitlements.canExportPdf
        ? 'Export PDF réservé à IliPresto+ / ilipro'
        : '$_pdfExportsUsed / ${entitlements.maxPdfExportsPerMonth} export(s) PDF utilisé(s) ce mois-ci';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: _kOrange),
              SizedBox(width: 8),
              Text(
                'Mon quota du mois',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            savesLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(pdfLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: Color(0xFF6B7280),
        letterSpacing: 0.2,
      ),
    );
  }
}

class _EmptyInlineNote extends StatelessWidget {
  final String text;

  const _EmptyInlineNote(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.route_outlined,
              size: 56,
              color: Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 16),
            const Text(
              'Aucun parcours sauvegardé sur cet appareil.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _kOrange,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(62),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                  elevation: 4,
                  shadowColor: _kOrange,
                ),
                onPressed: onCreate,
                icon: const Icon(Icons.rocket_launch_rounded, size: 22),
                label: const Text('Je crée mon entreprise'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  final String dateLabel;
  final bool isExportingPdf;
  final VoidCallback onResume;
  final VoidCallback onExportPdf;

  const _JourneyCard({
    required this.snapshot,
    required this.dateLabel,
    required this.isExportingPdf,
    required this.onResume,
    required this.onExportPdf,
  });

  @override
  Widget build(BuildContext context) {
    final projectLabel = '${snapshot['projectLabel'] ?? ''}'.trim();
    final region = '${snapshot['region'] ?? ''}'.trim();
    final currentStatus = '${snapshot['currentStatus'] ?? ''}'.trim();
    final selectedActivity = '${snapshot['selectedActivity'] ?? ''}'.trim();
    final recommendation =
        (snapshot['recommendation'] as Map?)?.cast<String, dynamic>() ??
            const {};
    final statut = '${recommendation['statut'] ?? '—'}';
    final savedAt = DateTime.tryParse('${snapshot['savedAt'] ?? ''}');

    final title = selectedActivity.isNotEmpty
        ? selectedActivity
        : (projectLabel.isNotEmpty
            ? projectLabel
            : 'Mon parcours personnalisé');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (region.isNotEmpty) _InfoLine(label: 'Région', value: region),
          if (currentStatus.isNotEmpty)
            _InfoLine(label: 'Statut actuel', value: currentStatus),
          if (selectedActivity.isNotEmpty)
            _InfoLine(label: 'Activité', value: selectedActivity),
          _InfoLine(label: 'Statut recommandé', value: statut),
          if (savedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '$dateLabel ${savedAt.day.toString().padLeft(2, '0')}/${savedAt.month.toString().padLeft(2, '0')}/${savedAt.year}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Voir'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isExportingPdf ? null : onExportPdf,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                  ),
                  icon: isExportingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: Text(isExportingPdf ? 'PDF...' : 'PDF'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label : $value',
        style: const TextStyle(color: Color(0xFF374151)),
      ),
    );
  }
}

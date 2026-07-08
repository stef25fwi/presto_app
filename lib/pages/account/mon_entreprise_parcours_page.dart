import 'package:flutter/material.dart';

import '../../features/subscriptions/journey_entitlements_service.dart';
import '../../features/subscriptions/subscription_models.dart';
import '../../services/journey_local_storage_service.dart';
import '../toolbox_je_me_lance_page.dart';

const Color _kOrange = Color(0xFFFF6600);
const Color _kBg = Color(0xFFF6F7FB);

/// Onglet "Je crée mon entreprise" de la page "Mon compte iliPresto".
///
/// Affiche le dernier parcours personnalisé sauvegardé localement sur cet
/// appareil, ainsi que le quota mensuel de sauvegarde/export en fonction de
/// l'abonnement (Gratuit : 1 sauvegarde locale/mois, aucun export ;
/// IliPresto+ : sauvegardes illimitées + 2 exports PDF/mois).
class MonEntrepriseParcoursPage extends StatefulWidget {
  const MonEntrepriseParcoursPage({super.key});

  @override
  State<MonEntrepriseParcoursPage> createState() =>
      _MonEntrepriseParcoursPageState();
}

class _MonEntrepriseParcoursPageState
    extends State<MonEntrepriseParcoursPage> {
  static const _localStorageService = JourneyLocalStorageService();
  final _entitlementsService = JourneyEntitlementsService();

  bool _loading = true;
  Map<String, dynamic>? _snapshot;
  JourneyEntitlements? _entitlements;
  int _savesUsed = 0;
  int _pdfExportsUsed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final snapshot = await _localStorageService.loadSnapshot();
    final entitlements = await _entitlementsService.resolveEntitlements();
    final savesUsed = await _entitlementsService.getLocalSavesUsedThisMonth();
    final pdfUsed = await _entitlementsService.getPdfExportsUsedThisMonth();

    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _entitlements = entitlements;
      _savesUsed = savesUsed;
      _pdfExportsUsed = pdfUsed;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                  _snapshot == null
                      ? _EmptyState(onCreate: _openToolbox)
                      : _SavedJourneyCard(
                          snapshot: _snapshot!,
                          onResume: _openToolbox,
                        ),
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

  Widget _buildQuotaCard() {
    final entitlements = _entitlements;
    if (entitlements == null) return const SizedBox.shrink();

    final savesLabel = entitlements.hasUnlimitedLocalSaves
        ? 'Sauvegardes locales illimitées'
        : '$_savesUsed / ${entitlements.maxLocalSavesPerMonth} sauvegarde(s) locale(s) utilisée(s) ce mois-ci';
    final pdfLabel = !entitlements.canExportPdf
        ? 'Export PDF réservé à IliPresto+'
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
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _kOrange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onCreate,
              icon: const Icon(Icons.rocket_launch_rounded),
              label: const Text('Créer mon parcours'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedJourneyCard extends StatelessWidget {
  final Map<String, dynamic> snapshot;
  final VoidCallback onResume;

  const _SavedJourneyCard({required this.snapshot, required this.onResume});

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
          _InfoLine(label: 'Statut recommandé', value: statut),
          if (savedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Sauvegardé le ${savedAt.day.toString().padLeft(2, '0')}/${savedAt.month.toString().padLeft(2, '0')}/${savedAt.year}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onResume,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Reprendre / voir le parcours complet'),
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

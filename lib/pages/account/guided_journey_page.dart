import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:presto_app/features/guided_journey/guided_journey_models.dart';
import 'package:presto_app/features/guided_journey/widgets/guided_journey_common_widgets.dart';
import 'package:presto_app/features/guided_journey/widgets/guided_journey_overview.dart';
import 'package:presto_app/features/guided_journey/widgets/guided_journey_stage_view.dart';
import 'package:presto_app/features/subscriptions/journey_entitlements_service.dart';
import 'package:presto_app/services/journey_local_storage_service.dart';
import 'package:presto_app/services/journey_pdf_export_service.dart';
import 'package:presto_app/services/screen_capture_protection_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Renderer unique de toutes les fiches « Mon parcours personnalisé ».
///
/// Il conserve la totalité des informations historiques, mais les répartit dans
/// huit étapes guidées : comprendre, vérifier, choisir, préparer, déclarer,
/// sécuriser, financer puis lancer sur 30 jours.
class GuidedJourneyPage extends StatefulWidget {
  final String projectLabel;
  final String region;
  final String currentStatus;
  final String selectedActivity;
  final Map<String, dynamic> recommendation;
  final List<String> blockingAlerts;
  final Map<String, dynamic> costs;
  final List<Map<String, dynamic>> aides;
  final List<Map<String, dynamic>> plan30;
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> regulationTutorial;
  final List<Map<String, dynamic>> statusWarnings;
  final Map<String, dynamic> recommendedLegalStatus;
  final List<Map<String, dynamic>> steps;
  final Map<String, dynamic> guidedProgress;
  final String savedAt;

  const GuidedJourneyPage({
    super.key,
    required this.projectLabel,
    required this.region,
    required this.currentStatus,
    required this.selectedActivity,
    required this.recommendation,
    required this.blockingAlerts,
    required this.costs,
    required this.aides,
    required this.plan30,
    required this.summary,
    required this.regulationTutorial,
    required this.statusWarnings,
    required this.recommendedLegalStatus,
    required this.steps,
    this.guidedProgress = const <String, dynamic>{},
    this.savedAt = '',
  });

  @override
  State<GuidedJourneyPage> createState() => _GuidedJourneyPageState();
}

class _GuidedJourneyPageState extends State<GuidedJourneyPage> {
  static const JourneyLocalStorageService _localStorage =
      JourneyLocalStorageService();
  static const JourneyPdfExportService _pdfExport = JourneyPdfExportService();
  static final JourneyEntitlementsService _entitlements =
      JourneyEntitlementsService();

  late final List<JourneyStage> _stages;
  late Set<String> _completedStageIds;
  late Map<String, Set<String>> _checklistDone;
  int _activeIndex = 0;
  bool _showOverview = true;
  bool _saving = false;

  String get _activity => widget.selectedActivity.trim().isNotEmpty
      ? widget.selectedActivity.trim()
      : widget.projectLabel.trim().isNotEmpty
          ? widget.projectLabel.trim()
          : 'votre projet';

  double get _progress =>
      _stages.isEmpty ? 0 : _completedStageIds.length / _stages.length;

  int get _nextIncompleteIndex {
    final index = _stages.indexWhere(
      (stage) => !_completedStageIds.contains(stage.id),
    );
    return index == -1 ? _stages.length - 1 : index;
  }

  JourneyStage get _activeStage => _stages[_activeIndex];

  @override
  void initState() {
    super.initState();
    _stages = GuidedJourneyContentFactory(
      projectLabel: widget.projectLabel,
      region: widget.region,
      currentStatus: widget.currentStatus,
      selectedActivity: widget.selectedActivity,
      recommendation: widget.recommendation,
      blockingAlerts: widget.blockingAlerts,
      costs: widget.costs,
      aides: widget.aides,
      plan30: widget.plan30,
      summary: widget.summary,
      regulationTutorial: widget.regulationTutorial,
      statusWarnings: widget.statusWarnings,
      recommendedLegalStatus: widget.recommendedLegalStatus,
      steps: widget.steps,
    ).build();
    final restored = GuidedJourneyProgress.fromMap(
      widget.guidedProgress,
      _stages,
    );
    _completedStageIds = Set<String>.from(restored.completedStageIds);
    _checklistDone = <String, Set<String>>{
      for (final entry in restored.checklistDone.entries)
        entry.key: Set<String>.from(entry.value),
    };
    _activeIndex = _stages.indexWhere(
      (stage) => stage.id == restored.activeStageId,
    );
    if (_activeIndex < 0) _activeIndex = _nextIncompleteIndex;
    _showOverview = widget.guidedProgress.isEmpty;
    unawaited(_setScreenProtection(true));
  }

  @override
  void dispose() {
    unawaited(_setScreenProtection(false));
    super.dispose();
  }

  Future<void> _setScreenProtection(bool enabled) async {
    try {
      if (enabled) {
        await ScreenCaptureProtection.enable();
      } else {
        await ScreenCaptureProtection.disable();
      }
    } catch (_) {
      // La protection reste une amélioration de confidentialité non bloquante.
    }
  }

  Map<String, dynamic> _progressMap() => GuidedJourneyProgress(
        activeStageId: _activeStage.id,
        completedStageIds: _completedStageIds,
        checklistDone: _checklistDone,
      ).toMap();

  Map<String, dynamic> _snapshot() => <String, dynamic>{
        'savedAt': widget.savedAt.trim().isNotEmpty
            ? widget.savedAt
            : DateTime.now().toIso8601String(),
        'projectLabel': widget.projectLabel,
        'region': widget.region,
        'currentStatus': widget.currentStatus,
        'selectedActivity': widget.selectedActivity,
        'recommendation': widget.recommendation,
        'blockingAlerts': widget.blockingAlerts,
        'costs': widget.costs,
        'aides': widget.aides,
        'plan30': widget.plan30,
        'summary': widget.summary,
        'regulationTutorial': widget.regulationTutorial,
        'statusWarnings': widget.statusWarnings,
        'recommendedLegalStatus': widget.recommendedLegalStatus,
        'steps': widget.steps,
        'guidedProgress': _progressMap(),
      };

  void _persistProgress() {
    unawaited(() async {
      try {
        await _localStorage.saveHistorySnapshot(_snapshot());
      } catch (_) {
        // La progression reste disponible à l’écran même si le cache échoue.
      }
    }());
  }

  void _openStage(int index) {
    setState(() {
      _activeIndex = index.clamp(0, _stages.length - 1);
      _showOverview = false;
    });
    _persistProgress();
  }

  void _toggleChecklist(String itemId) {
    final done = _checklistDone.putIfAbsent(
      _activeStage.id,
      () => <String>{},
    );
    setState(() {
      if (!done.add(itemId)) done.remove(itemId);
      if (done.isNotEmpty && !_completedStageIds.contains(_activeStage.id)) {
        // L’étape devient « en cours » sans être déclarée terminée.
      }
    });
    _persistProgress();
  }

  bool get _allActiveChecksDone {
    final done = _checklistDone[_activeStage.id] ?? const <String>{};
    return _activeStage.checklist.every((item) => done.contains(item.id));
  }

  void _completeActiveStage() {
    if (!_allActiveChecksDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cochez les actions vérifiées avant de terminer cette étape.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _completedStageIds.add(_activeStage.id);
      if (_activeIndex < _stages.length - 1) {
        _activeIndex += 1;
      } else {
        _showOverview = true;
      }
    });
    _persistProgress();
    if (_completedStageIds.length == _stages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre parcours guidé est terminé.')),
      );
    }
  }

  void _previousStage() {
    if (_activeIndex == 0) {
      setState(() => _showOverview = true);
      return;
    }
    setState(() => _activeIndex -= 1);
    _persistProgress();
  }

  Future<void> _openResource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir cette ressource.')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final saveDecision = await _entitlements.evaluateLocalSave();
      if (!saveDecision.allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Votre quota de sauvegardes est actuellement atteint.'),
          ),
        );
        return;
      }
      final snapshot = _snapshot();
      await _localStorage.saveSnapshot(snapshot);
      await _entitlements.recordLocalSave();
      if (!saveDecision.entitlements.canExportPdf) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parcours sauvegardé sur cet appareil.')),
        );
        return;
      }
      final pdfDecision = await _entitlements.evaluatePdfExport();
      if (pdfDecision.allowed) {
        final downloaded = await _pdfExport.downloadJourneyPdf(snapshot);
        if (downloaded) await _entitlements.recordPdfExport();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parcours sauvegardé avec sa progression guidée.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La sauvegarde est temporairement indisponible.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: kGuidedJourneyOrange,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: const Text(
            'Mon parcours personnalisé',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          backgroundColor: kGuidedJourneyOrange,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'Vue d’ensemble',
              onPressed: () => setState(() => _showOverview = true),
              icon: const Icon(Icons.route_outlined),
            ),
            IconButton(
              tooltip: 'Sauvegarder',
              onPressed: _saving ? null : _handleSave,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: _showOverview
            ? GuidedJourneyOverview(
                activity: _activity,
                region: widget.region,
                currentStatus: widget.currentStatus,
                stages: _stages,
                completedStageIds: _completedStageIds,
                nextStageIndex: _nextIncompleteIndex,
                onOpenStage: _openStage,
              )
            : GuidedJourneyStageView(
                stage: _activeStage,
                totalStages: _stages.length,
                progress: _progress,
                checkedIds:
                    _checklistDone[_activeStage.id] ?? const <String>{},
                onToggleChecklist: _toggleChecklist,
                onOpenResource: _openResource,
              ),
        bottomNavigationBar: _showOverview
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      top: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _previousStage,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Précédent'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _completeActiveStage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGuidedJourneyBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: Text(
                            _activeIndex == _stages.length - 1
                                ? 'J’ai terminé le parcours'
                                : 'J’ai terminé — continuer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

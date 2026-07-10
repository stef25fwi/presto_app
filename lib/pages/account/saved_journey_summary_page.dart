import 'package:flutter/material.dart';

const Color _kOrange = Color(0xFFFF6600);
const Color _kBlue = Color(0xFF1A73E8);
const Color _kBg = Color(0xFFF6F7FB);
const Color _kTextDark = Color(0xFF071B4D);
const Color _kMutedText = Color(0xFF66728A);

/// Page de consultation directe d'un parcours déjà sauvegardé localement.
///
/// Elle est ouverte depuis "Je crée mon entreprise" quand l'utilisateur clique
/// sur "Voir le parcours". Les champs clés du parcours sont repris depuis le
/// snapshot local : région, statut actuel et activité. L'utilisateur arrive
/// directement sur sa fiche déjà générée, sans repasser par le formulaire.
class SavedJourneySummaryPage extends StatelessWidget {
  final Map<String, dynamic> snapshot;

  const SavedJourneySummaryPage({
    super.key,
    required this.snapshot,
  });

  String _text(String key, {String fallback = ''}) {
    final value = snapshot[key];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  Map<String, dynamic> _map(String key) {
    final value = snapshot[key];
    if (value is Map) return value.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  List<String> _stringList(String key) {
    final value = snapshot[key];
    if (value is List) return value.map((item) => '$item').toList();
    return const <String>[];
  }

  List<Map<String, dynamic>> _mapList(String key) {
    final value = snapshot[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return const <Map<String, dynamic>>[];
  }

  String _dateLabel() {
    final savedAt = DateTime.tryParse(_text('savedAt'));
    if (savedAt == null) return 'Parcours sauvegardé';
    final day = savedAt.day.toString().padLeft(2, '0');
    final month = savedAt.month.toString().padLeft(2, '0');
    return 'Sauvegardé le $day/$month/${savedAt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final projectLabel = _text('projectLabel');
    final region = _text('region', fallback: 'Région non renseignée');
    final currentStatus =
        _text('currentStatus', fallback: 'Statut non renseigné');
    final selectedActivity =
        _text('selectedActivity', fallback: 'Activité non renseignée');
    final recommendation = _map('recommendation');
    final recommendedStatus =
        '${recommendation['statut'] ?? recommendation['recommended'] ?? '—'}';
    final why = '${recommendation['why'] ?? recommendation['justification'] ?? ''}'
        .trim();
    final planB = '${recommendation['planB'] ?? ''}'.trim();

    final costs = _map('costs');
    final summary = _map('summary');
    final recommendedLegalStatus = _map('recommendedLegalStatus');
    final blockingAlerts = _stringList('blockingAlerts');
    final regulationTutorial = _mapList('regulationTutorial');
    final statusWarnings = _mapList('statusWarnings');
    final aides = _mapList('aides');
    final plan30 = _mapList('plan30');
    final steps = _mapList('steps');

    final title = selectedActivity != 'Activité non renseignée'
        ? selectedActivity
        : (projectLabel.isNotEmpty ? projectLabel : 'Mon parcours personnalisé');

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Mon parcours personnalisé'),
        backgroundColor: _kOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          _HeroCard(
            title: title,
            subtitle: _dateLabel(),
            region: region,
            currentStatus: currentStatus,
            selectedActivity: selectedActivity,
          ),
          const SizedBox(height: 14),
          _SectionCard(
            title: 'Recommandation',
            icon: Icons.workspace_premium_outlined,
            children: [
              _HighlightedValue(
                label: 'Statut conseillé',
                value: recommendedStatus,
              ),
              if (why.isNotEmpty) _Paragraph(why),
              if (planB.isNotEmpty)
                _InfoLine(label: 'Alternative possible', value: planB),
              if (recommendedLegalStatus.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoLine(
                  label: 'Statut recommandé',
                  value: '${recommendedLegalStatus['recommended'] ?? '—'}',
                ),
                if ('${recommendedLegalStatus['justification'] ?? ''}'
                    .trim()
                    .isNotEmpty)
                  _Paragraph('${recommendedLegalStatus['justification']}'),
              ],
            ],
          ),
          if (blockingAlerts.isNotEmpty) ...[
            const SizedBox(height: 14),
            _ListSectionCard(
              title: 'Alertes importantes',
              icon: Icons.warning_amber_rounded,
              items: blockingAlerts,
              tone: const Color(0xFFB45309),
            ),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Résumé du parcours',
              icon: Icons.summarize_outlined,
              children: summary.entries
                  .map(
                    (entry) => _InfoLine(
                      label: _prettyLabel(entry.key),
                      value: '${entry.value}',
                    ),
                  )
                  .toList(),
            ),
          ],
          if (costs.isNotEmpty) ...[
            const SizedBox(height: 14),
            _SectionCard(
              title: 'Coûts et points financiers',
              icon: Icons.euro_rounded,
              children: costs.entries
                  .map(
                    (entry) => _InfoLine(
                      label: _prettyLabel(entry.key),
                      value: _formatDynamicValue(entry.value),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (regulationTutorial.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TimelineSectionCard(
              title: 'Réglementation et démarches',
              icon: Icons.gavel_outlined,
              items: regulationTutorial,
            ),
          ],
          if (statusWarnings.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TimelineSectionCard(
              title: 'Points de vigilance liés au statut',
              icon: Icons.privacy_tip_outlined,
              items: statusWarnings,
            ),
          ],
          if (aides.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TimelineSectionCard(
              title: 'Aides possibles',
              icon: Icons.volunteer_activism_outlined,
              items: aides,
            ),
          ],
          if (plan30.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TimelineSectionCard(
              title: 'Plan d’action 30 jours',
              icon: Icons.task_alt_rounded,
              items: plan30,
            ),
          ],
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 14),
            _TimelineSectionCard(
              title: 'Étapes détaillées',
              icon: Icons.route_outlined,
              items: steps,
            ),
          ],
        ],
      ),
    );
  }

  static String _prettyLabel(String raw) {
    final spaced = raw
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .trim();
    if (spaced.isEmpty) return 'Information';
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  static String _formatDynamicValue(dynamic value) {
    if (value is Map) {
      return value.entries
          .map((entry) => '${_prettyLabel('${entry.key}')} : ${entry.value}')
          .join(' · ');
    }
    if (value is List) return value.map((item) => '$item').join(' · ');
    return '$value';
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String region;
  final String currentStatus;
  final String selectedActivity;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.region,
    required this.currentStatus,
    required this.selectedActivity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3EA), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD7BF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _kOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  color: _kOrange,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _kTextDark,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _kMutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilledChip(icon: Icons.place_outlined, label: region),
              _FilledChip(icon: Icons.badge_outlined, label: currentStatus),
              _FilledChip(icon: Icons.work_outline_rounded, label: selectedActivity),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, icon: icon),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ListSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final Color tone;

  const _ListSectionCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline_rounded, color: tone, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: _Paragraph(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _TimelineSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Map<String, dynamic>> items;

  const _TimelineSectionCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: title,
      icon: icon,
      children: [
        for (final item in items) _TimelineItem(item: item),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> item;

  const _TimelineItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = '${item['title'] ?? item['label'] ?? item['name'] ?? 'Étape'}';
    final description =
        '${item['description'] ?? item['text'] ?? item['summary'] ?? ''}'.trim();
    final todos = item['todos'];
    final checks = item['checks'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _kTextDark,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 6),
            _Paragraph(description),
          ],
          ..._listValue(todos).map((value) => _SmallBullet(value)),
          ..._listValue(checks).map((value) => _SmallBullet(value)),
        ],
      ),
    );
  }

  static List<String> _listValue(dynamic value) {
    if (value is List) return value.map((item) => '$item').toList();
    if (value is String && value.trim().isNotEmpty) return [value.trim()];
    return const <String>[];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: _kOrange),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: _kTextDark,
            ),
          ),
        ),
      ],
    );
  }
}

class _HighlightedValue extends StatelessWidget {
  final String label;
  final String value;

  const _HighlightedValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBlue.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kBlue,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 14,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: '$label : ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  final String text;

  const _Paragraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontWeight: FontWeight.w600,
          height: 1.38,
        ),
      ),
    );
  }
}

class _SmallBullet extends StatelessWidget {
  final String text;

  const _SmallBullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6, color: _kOrange),
          ),
          const SizedBox(width: 8),
          Expanded(child: _Paragraph(text)),
        ],
      ),
    );
  }
}

class _FilledChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FilledChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kBlue),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _kTextDark,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

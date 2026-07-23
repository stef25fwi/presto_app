import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../features/operating_mode/app_operating_mode.dart';
import '../features/operating_mode/legal_documents.dart';

class LegalInfoPage extends StatefulWidget {
  const LegalInfoPage({
    super.key,
    this.initialTab = 0,
    this.operatingModeService,
  });

  final int initialTab;
  final AppOperatingModeService? operatingModeService;

  @override
  State<LegalInfoPage> createState() => _LegalInfoPageState();
}

class _LegalInfoPageState extends State<LegalInfoPage> {
  static const Color _orange = Color(0xFFFF6600);
  static const Color _background = Color(0xFFF7F8FA);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  late int _tab;

  AppOperatingModeService get _service =>
      widget.operatingModeService ?? AppOperatingModeService();

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
  }

  List<LegalDocumentSection> _sections(AppOperatingModeState state) {
    switch (_tab) {
      case 1:
        return LegalDocumentCatalog.privacy(state);
      case 2:
        return LegalDocumentCatalog.terms(state);
      default:
        return LegalDocumentCatalog.legalNotices(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('iliprestō', style: kPrestoAppBarTitleStyle),
      ),
      body: StreamBuilder<AppOperatingModeState>(
        stream: _service.watchState(ensureExists: true),
        builder: (context, snapshot) {
          final state = snapshot.data ?? AppOperatingModeState.defaults();
          final sections = _sections(state);
          return SafeArea(
            top: false,
            child: Column(
              children: [
                _ModeBanner(state: state),
                _Tabs(
                  index: _tab,
                  onChanged: (value) => setState(() => _tab = value),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    itemCount: sections.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      if (index == sections.length) {
                        return _ContactCard(email: state.publisher.email);
                      }
                      final section = sections[index];
                      return _SectionCard(
                        section: section,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _LegalSectionPage(
                              title: section.title,
                              content: section.content,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  final AppOperatingModeState state;

  const _ModeBanner({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = state.mode.isCommercial
        ? const Color(0xFFFF6600)
        : const Color(0xFF138A46);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            state.mode.isCommercial
                ? Icons.workspace_premium_outlined
                : Icons.science_outlined,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.mode.label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  state.mode.isCommercial
                      ? 'Les conditions commerciales sont actives.'
                      : 'Aucun abonnement, paiement ou commission n’est prélevé par Ilipresto.',
                  style: const TextStyle(
                    color: _LegalInfoPageState._muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!state.isPublicReady) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Configuration juridique incomplète : la mise en ligne publique doit rester bloquée jusqu’à sa finalisation dans l’administration.',
                    style: TextStyle(
                      color: Color(0xFFD93025),
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _Tabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = <String>['Mentions légales', 'Confidentialité', 'CGU'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LegalInfoPageState._border),
      ),
      child: Row(
        children: List<Widget>.generate(labels.length, (i) {
          final active = i == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active
                      ? _LegalInfoPageState._orange
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : _LegalInfoPageState._text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final LegalDocumentSection section;
  final VoidCallback onTap;

  const _SectionCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _LegalInfoPageState._border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: _LegalInfoPageState._orange,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        color: _LegalInfoPageState._text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      section.subtitle,
                      style: const TextStyle(
                        color: _LegalInfoPageState._muted,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final String email;

  const _ContactCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: email.trim().isEmpty
          ? null
          : () => launchUrl(Uri.parse('mailto:${email.trim()}')),
      icon: const Icon(Icons.mail_outline_rounded),
      label: Text(email.trim().isEmpty ? 'Contact non configuré' : email),
    );
  }
}

class _LegalSectionPage extends StatelessWidget {
  final String title;
  final String content;

  const _LegalSectionPage({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LegalInfoPageState._background,
      appBar: AppBar(
        backgroundColor: _LegalInfoPageState._orange,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: SelectableText(
            content.trim(),
            style: const TextStyle(
              color: _LegalInfoPageState._text,
              fontSize: 14,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}

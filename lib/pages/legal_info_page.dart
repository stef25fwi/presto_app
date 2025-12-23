import 'package:flutter/material.dart';

class LegalInfoPage extends StatefulWidget {
  const LegalInfoPage({super.key});

  @override
  State<LegalInfoPage> createState() => _LegalInfoPageState();
}

class _LegalInfoPageState extends State<LegalInfoPage> {
  static const Color kOrange = Color(0xFFFF6600);
  static const Color kBg = Color(0xFFF7EFE8);

  int _tab = 0; // 0=Mentions, 1=Confidentialité, 2=CGU
  int _bottomIndex = 4; // Compte (comme le mockup)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kOrange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          "ilprestō",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: ouvrir une recherche interne si tu veux
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: _SegmentTabs(
                activeIndex: _tab,
                labels: const ["Mentions légales", "Confidentialité", "CGU"],
                onChanged: (i) => setState(() => _tab = i),
                orange: kOrange,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                child: Column(
                  children: [
                    const SizedBox(height: 4),
                    ..._buildTabContent(context),
                    const SizedBox(height: 12),

                    // ✅ UN SEUL bloc "Vous avez une question ?" (doublon supprimé)
                    _QuestionCard(
                      orange: kOrange,
                      email: "contact@ilpresto.fr",
                      onTapEmail: () {
                        // TODO: lancer un mailto: contact@ilpresto.fr
                      },
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomBar(
        orange: kOrange,
        currentIndex: _bottomIndex,
        onTap: (i) => setState(() => _bottomIndex = i),
      ),
    );
  }

  List<Widget> _buildTabContent(BuildContext context) {
    switch (_tab) {
      case 0: // Mentions légales
        return [
          _InfoTileCard(
            title: "À propos de nous",
            subtitle: "Informations sur la société derrière ilprestō.",
            onTap: () {
              // TODO: navigation vers détail "À propos"
            },
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Responsable de publication",
            subtitle: "Coordonnées du responsable de la publication.",
            onTap: () {
              // TODO: navigation
            },
          ),
          const SizedBox(height: 12),
          _HostingCard(
            orange: kOrange,
            onTap: () {
              // TODO: navigation vers détails hébergement
            },
            onDownloadPdf: () {
              // TODO: ouvrir PDF (url_launcher)
            },
            lastUpdateText: "Dernière mise à jour : 15 avril 2024",
          ),
        ];

      case 1: // Confidentialité
        return [
          _InfoTileCard(
            title: "Données collectées",
            subtitle: "Quelles données nous collectons et pourquoi.",
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Durée de conservation",
            subtitle: "Combien de temps nous gardons vos données.",
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Vos droits (RGPD)",
            subtitle: "Accès, rectification, suppression, opposition…",
            onTap: () {},
          ),
        ];

      case 2: // CGU
        return [
          _InfoTileCard(
            title: "Objet des CGU",
            subtitle: "Règles d'utilisation de la plateforme.",
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Comptes & sécurité",
            subtitle: "Création de compte, responsabilités, accès.",
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _InfoTileCard(
            title: "Publication d'annonces",
            subtitle: "Contenus autorisés, modération, signalements.",
            onTap: () {},
          ),
        ];

      default:
        return [];
    }
  }
}

/* ---------------- UI COMPONENTS ---------------- */

class _SegmentTabs extends StatelessWidget {
  final int activeIndex;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  final Color orange;

  const _SegmentTabs({
    required this.activeIndex,
    required this.labels,
    required this.onChanged,
    required this.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E1DC)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = i == activeIndex;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: isActive ? orange : const Color(0xFF8A817B),
                    ),
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

class _InfoTileCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _InfoTileCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF7C7772)),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, size: 28),
        onTap: onTap,
      ),
    );
  }
}

class _HostingCard extends StatelessWidget {
  final Color orange;
  final VoidCallback onTap;
  final VoidCallback onDownloadPdf;
  final String lastUpdateText;

  const _HostingCard({
    required this.orange,
    required this.onTap,
    required this.onDownloadPdf,
    required this.lastUpdateText,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Row(
                children: const [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Hébergement",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Détails sur l'hébergeur du site.",
                          style: TextStyle(color: Color(0xFF7C7772)),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 28),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onDownloadPdf,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1E8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFD6BF)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_rounded, color: orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Télécharger nos mentions légales (PDF)",
                        style: TextStyle(
                          color: const Color(0xFF4A3F39),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                lastUpdateText,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A817B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final Color orange;
  final String email;
  final VoidCallback onTapEmail;

  const _QuestionCard({
    required this.orange,
    required this.email,
    required this.onTapEmail,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Vous avez une question ?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              "Contactez-nous à l'adresse suivante :",
              style: TextStyle(color: Color(0xFF7C7772)),
            ),
            const SizedBox(height: 12),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onTapEmail,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7F2),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6E1DC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_rounded, color: orange, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        email,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF3A332F),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Color orange;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomBar({
    required this.orange,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: orange,
      unselectedItemColor: const Color(0xFF9A918A),
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: "Accueil"),
        BottomNavigationBarItem(
            icon: Icon(Icons.search_rounded), label: "Offres"),
        BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: "Publier"),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded), label: "Messages"),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded), label: "Compte"),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ HEADER + "TOP CARD" de la page détail (style comme ton visuel)
/// - AppBar orange : back, titre centré, share + coeur
/// - Carte blanche avec bandeau orange + infos + chips
/// - Mini carrousel photos + points
///
/// Tu peux l'intégrer dans ta page OfferDetailV2 (le body complet viendra après).

class OfferDetailV2Top extends StatefulWidget {
  const OfferDetailV2Top({super.key});

  @override
  State<OfferDetailV2Top> createState() => _OfferDetailV2TopState();
}

class _OfferDetailV2TopState extends State<OfferDetailV2Top> {
  static const kPrestoOrange = Color(0xFFFF6A00);
  static const kPrestoBlue = Color(0xFF1A73E8);

  final _pageCtrl = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = <Widget>[
      _MockPhotoTile(icon: Icons.local_shipping_outlined, label: "Utilitaire"),
      _MockPhotoTile(icon: Icons.inventory_2_outlined, label: "Colis"),
      _MockPhotoTile(icon: Icons.location_on_outlined, label: "Localisation"),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F6),
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(),
        title: const Text(
          "OffreDetailV2",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Partager",
            onPressed: () {},
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: "Favori",
            onPressed: () {},
            icon: const Icon(Icons.favorite_border_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
        children: [
          _TopOfferCard(
            orange: kPrestoOrange,
            blue: kPrestoBlue,
            title: "Livraison de colis",
            distanceAndPrice: "15 km - 20 €",
            dateLine: "À effectuer le 25 avril",
            chipLeft: _ChipSpec(
              label: "Rapide",
              bg: kPrestoBlue,
              fg: Colors.white,
            ),
            chipRight: _ChipSpec(
              label: "Utilitaire requis",
              bg: const Color(0xFFE9EDF3),
              fg: const Color(0xFF243041),
              border: const Color(0xFFD7DEE8),
            ),
          ),
          const SizedBox(height: 12),

          // --- Carrousel + dots (comme ton visuel) ---
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                children: [
                  SizedBox(
                    height: 92,
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: images[i],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Dots(
                    count: images.length,
                    index: _pageIndex,
                    active: const Color(0xFF1C1C1C),
                    inactive: const Color(0xFFC9CED8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopOfferCard extends StatelessWidget {
  final Color orange;
  final Color blue;

  final String title;
  final String distanceAndPrice;
  final String dateLine;
  final _ChipSpec chipLeft;
  final _ChipSpec chipRight;

  const _TopOfferCard({
    required this.orange,
    required this.blue,
    required this.title,
    required this.distanceAndPrice,
    required this.dateLine,
    required this.chipLeft,
    required this.chipRight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Bandeau orange
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: orange,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                _RowInfo(
                  icon: Icons.check_circle_rounded,
                  iconColor: orange,
                  text: distanceAndPrice,
                ),
                const SizedBox(height: 10),
                _RowInfo(
                  icon: Icons.check_circle_rounded,
                  iconColor: orange,
                  text: dateLine,
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    _Pill(
                      label: chipLeft.label,
                      bg: chipLeft.bg,
                      fg: chipLeft.fg,
                      border: chipLeft.border,
                    ),
                    const SizedBox(width: 10),
                    _Pill(
                      label: chipRight.label,
                      bg: chipRight.bg,
                      fg: chipRight.fg,
                      border: chipRight.border,
                    ),
                    const Spacer(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RowInfo extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _RowInfo({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChipSpec {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  const _ChipSpec({required this.label, required this.bg, required this.fg, this.border});
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;

  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border != null ? Border.all(color: border!, width: 1) : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color active;
  final Color inactive;

  const _Dots({
    required this.count,
    required this.index,
    required this.active,
    required this.inactive,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isActive = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 7,
          width: 7,
          decoration: BoxDecoration(
            color: isActive ? active : inactive,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

/// Placeholders "photos" (pour coller au mock)
class _MockPhotoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MockPhotoTile({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEFF2F7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: const Color(0xFF111827).withOpacity(0.70)),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE4E7EE), width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Color blue;
  final String phoneMasked;
  final VoidCallback onToggle;
  final bool isVisible;
  final VoidCallback onMessage;
  final VoidCallback onShare;

  const _ContactCard({
    required this.blue,
    required this.phoneMasked,
    required this.onToggle,
    required this.isVisible,
    required this.onMessage,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bg = Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2F7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.call, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phoneMasked, // si tu veux: isVisible ? full : masked
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: onToggle,
                  child: Text(
                    isVisible ? "Masquer" : "Afficher le numéro",
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onMessage,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text(
                      "Message",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6A00),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: onShare,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      "Partager",
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


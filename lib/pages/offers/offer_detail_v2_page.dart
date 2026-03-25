import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:presto_app/main.dart';

class OfferDetailV2Page extends StatefulWidget {
  final String offerId;
  const OfferDetailV2Page({super.key, required this.offerId});

  @override
  State<OfferDetailV2Page> createState() => _OfferDetailV2PageState();
}

class _OfferDetailV2PageState extends State<OfferDetailV2Page> {
  final PageController _pageCtrl = PageController();
  int _pageIndex = 0;

  bool _isPhoneVisible = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  // ----------------------------
  // Robust parsing helpers
  // ----------------------------
  String _s(dynamic v) => (v ?? '').toString().trim();

  num? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    final s = v.toString().replaceAll(',', '.').trim();
    return num.tryParse(s);
  }

  List<String> _listStr(dynamic v) {
    if (v is List) {
      return v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  String _pickTitle(Map<String, dynamic> data) {
    final t = _s(data['title']);
    if (t.isNotEmpty) return t;
    final t2 = _s(data['name']);
    if (t2.isNotEmpty) return t2;
    return 'Annonce';
  }

  String _pickLocation(Map<String, dynamic> data) {
    final a = _s(data['location']);
    if (a.isNotEmpty) return a;
    final b = _s(data['city']);
    if (b.isNotEmpty) return b;
    final c = _s(data['commune']);
    if (c.isNotEmpty) return c;
    return '';
  }

  String _pickPostalCode(Map<String, dynamic> data) {
    final a = _s(data['postalCode']);
    if (a.isNotEmpty) return a;
    final b = _s(data['postal_code']);
    if (b.isNotEmpty) return b;
    final c = _s(data['cp']);
    if (c.isNotEmpty) return c;
    return '';
  }

  String _pickAnnonceurId(Map<String, dynamic> data) {
    final a = _s(data['userId']);
    if (a.isNotEmpty) return a;
    final b = _s(data['uid']);
    if (b.isNotEmpty) return b;
    final c = _s(data['ownerId']);
    if (c.isNotEmpty) return c;
    return '';
  }

  String _pickAnnonceurPseudo(Map<String, dynamic> data) {
    final candidates = [
      _s(data['pseudo']),
      _s(data['userPseudo']),
      _s(data['displayName']),
      _s(data['username']),
      _s(data['authorName']),
      _s(data['ownerName']),
    ];
    for (final c in candidates) {
      if (c.isNotEmpty) return c;
    }
    return 'Annonceur';
  }

  bool _pickProfileVerified(Map<String, dynamic> data) {
    return data['isProfileVerified'] == true ||
        data['isVerified'] == true ||
        data['verified'] == true;
  }

  double _pickRating(Map<String, dynamic> data) {
    final r = _num(data['rating'] ?? data['averageRating'] ?? data['sellerRating']);
    if (r == null) return 0;
    return r.toDouble().clamp(0, 5);
  }

  int _pickReviewsCount(Map<String, dynamic> data) {
    final v = _num(data['reviewsCount'] ?? data['avisCount'] ?? data['ratingsCount']);
    return v?.toInt() ?? 0;
  }

  String _pickMissionDelay(Map<String, dynamic> data) {
    final d = _s(
      data['missionDelay'] ??
          data['averageDelay'] ??
          data['responseDelay'] ??
          data['dateLabel'],
    );
    return d.isEmpty ? 'Non précisé' : d;
  }

  String _sanitizeTitleForHeader({
    required String rawTitle,
    required String location,
    required String postalCode,
    String? commune,
  }) {
    var out = rawTitle.trim();
    if (out.isEmpty) return 'Annonce';

    final safeLoc = location.trim();
    final safeCp = postalCode.trim();
    final safeCommune = (commune ?? '').trim();

    if (safeLoc.isNotEmpty) {
      out = out.replaceAll(RegExp(RegExp.escape(safeLoc), caseSensitive: false), ' ');
    }
    if (safeCp.isNotEmpty) {
      out = out.replaceAll(RegExp('\\b${RegExp.escape(safeCp)}\\b', caseSensitive: false), ' ');
    }
    if (safeCommune.isNotEmpty) {
      out = out.replaceAll(RegExp(RegExp.escape(safeCommune), caseSensitive: false), ' ');
    }

    out = out.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\s*[-–|/]\s*$'), '').trim();
    return out.isEmpty ? rawTitle.trim() : out;
  }

  String? _pickPhone(Map<String, dynamic> data) {
    final p = _s(data['phone']);
    if (p.isNotEmpty) return p;
    final p2 = _s(data['tel']);
    if (p2.isNotEmpty) return p2;
    return null;
  }

  String _formatPrice(num? b) => b == null ? "—" : "${b.toDouble().toStringAsFixed(0)} €";

  String _extractDuration(String title) {
    final reg = RegExp(r'(\d+\s*(h|min))', caseSensitive: false);
    final m = reg.firstMatch(title);
    return m?.group(1)?.replaceAll(' ', '') ?? "—";
  }

  // ----------------------------
  // Phone format / masking
  // ----------------------------
  String _toE164Like(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('+')) {
      final digits = trimmed.replaceAll(RegExp(r'\D'), '');
      return digits.isEmpty ? trimmed : '+$digits';
    }

    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';

    // FR convention
    if (digits.length == 10 && digits.startsWith('0')) return '+33${digits.substring(1)}';
    if (digits.length == 9 && (digits.startsWith('6') || digits.startsWith('7'))) return '+33$digits';

    return digits;
  }

  String _formatPhoneWithIndicatif(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('+')) return trimmed.replaceAll(RegExp(r'\s+'), ' ');

    final e164 = _toE164Like(trimmed);
    if (e164.startsWith('+33') && e164.length == 12) {
      final n = e164.substring(3);
      return '+33 ${n.substring(0, 1)} ${n.substring(1, 3)} ${n.substring(3, 5)} ${n.substring(5, 7)} ${n.substring(7, 9)}';
    }
    return e164;
  }

  String _maskPhone(String value) {
    final formatted = _formatPhoneWithIndicatif(value);
    final digits = formatted.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '••••••••••';
    if (digits.length <= 2) return digits;
    return '••••••${digits.substring(digits.length - 2)}';
  }

  // ----------------------------
  // Analytics
  // ----------------------------
  // ----------------------------
  // Firebase actions
  // ----------------------------
  Future<void> _openOrCreateConversation({
    required BuildContext context,
    required String annonceurId,
    required String offerTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final me = user?.uid;

    if (me == null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountPage()));
      return;
    }

    if (annonceurId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Annonceur introuvable.")),
      );
      return;
    }

    // ✅ Cherche une conversation existante (participants + offerId)
    final convCol = FirebaseFirestore.instance.collection('conversations');
    final q = await convCol
        .where('participants', arrayContains: me)
        .where('offerId', isEqualTo: widget.offerId)
        .limit(20)
        .get();

    String? conversationId;

    for (final d in q.docs) {
      final data = d.data();
      final parts = (data['participants'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
      if (parts.contains(annonceurId)) {
        conversationId = d.id;
        break;
      }
    }

    // ✅ Sinon crée une conversation
    if (conversationId == null) {
      final doc = await convCol.add({
        'offerId': widget.offerId,
        'offerTitle': offerTitle,
        'participants': [me, annonceurId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'unreadCount': {me: 0, annonceurId: 0},
      });
      conversationId = doc.id;
    }

    if (!context.mounted) return;

    // Ouvre la messagerie après création/récupération de la conversation.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Conversation prête. Ouverture de la messagerie...")),
    );

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MessagesPage()),
    );
  }

  Future<void> _callPhone(BuildContext context, String? phone) async {
    if (!context.mounted) return;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun numéro disponible.")),
      );
      return;
    }

    final dial = _toE164Like(phone.trim());
    final uri = Uri(scheme: 'tel', path: dial.isNotEmpty ? dial : phone.trim());

    final ok = await canLaunchUrl(uri);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lancer l'appel sur cet appareil.")),
      );
      return;
    }
    await launchUrl(uri);
  }

  Future<void> _openExternalMessaging(
    BuildContext context, {
    required String? phone,
    required String title,
  }) async {
    if (!context.mounted) return;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Aucun numéro disponible pour envoyer un message.")),
      );
      return;
    }

    final dial = _toE164Like(phone.trim());
    final smsUri = Uri(
      scheme: 'sms',
      path: dial.isNotEmpty ? dial : phone.trim(),
      queryParameters: {
        'body': 'Bonjour, je vous contacte pour votre annonce: $title',
      },
    );

    final ok = await canLaunchUrl(smsUri);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir la messagerie sur cet appareil.")),
      );
      return;
    }

    await launchUrl(smsUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink(BuildContext context) async {
    final url = 'https://prestoo.app/offers/${widget.offerId}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Lien copié.")),
    );
  }

  Future<void> _shareBasic(BuildContext context, String title, String location) async {
    // Simple: on copie le texte dans le presse-papier (fiable partout)
    final url = 'https://prestoo.app/offers/${widget.offerId}';
    final text = "$title – $location\n$url";
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Texte de partage copié.")),
    );
  }

  String _descriptionWithLineBreaks(String text) {
    final value = text.trim();
    if (value.isEmpty) return value;
    if (value.contains('\n')) return value;
    return value
        .replaceAll('. ', '.\n')
        .replaceAll('; ', ';\n')
        .replaceAll(' - ', '\n- ')
        .trim();
  }

  Future<void> _showContactOptionsSheet({
    required BuildContext context,
    required String annonceurId,
    required String offerTitle,
    required String? phone,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Proposer mes services',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openExternalMessaging(
                        context,
                        phone: phone,
                        title: offerTitle,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrestoBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Envoyer un message'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _callPhone(context, phone);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrestoBlue,
                      side: const BorderSide(color: Color(0xFFD7DEE8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Appeler'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ----------------------------
  // Streams
  // ----------------------------
  Stream<DocumentSnapshot<Map<String, dynamic>>> _offerStream() {
    return FirebaseFirestore.instance.collection('offers').doc(widget.offerId).snapshots().map((snap) {
      PrestoMonitoring.I.trackOtherStream(key: 'offerDetailV2.offerDoc', docsCount: snap.exists ? 1 : 0);
      return snap;
    });
  }

  // ----------------------------
  // UI
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _offerStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _loadingScaffold();
        }
        if (!snap.hasData || !(snap.data?.exists ?? false)) {
          return _notFoundScaffold();
        }

        final data = snap.data!.data() ?? <String, dynamic>{};

        final title = _pickTitle(data);
        final location = _pickLocation(data);
        final postalCode = _pickPostalCode(data);
        final annonceurId = _pickAnnonceurId(data);
        final annonceurPseudo = _pickAnnonceurPseudo(data);
        final isProfileVerified = _pickProfileVerified(data);
        final rating = _pickRating(data);
        final reviewsCount = _pickReviewsCount(data);
        final missionDelay = _pickMissionDelay(data);
        final headerTitle = _sanitizeTitleForHeader(
          rawTitle: title,
          location: location,
          postalCode: postalCode,
          commune: _s(data['commune']),
        );

        final budget = _num(data['budget'] ?? data['price'] ?? data['amount']);
        final duration = _pickMissionDelay(data);

        final phone = _pickPhone(data);
        final images = _listStr(data['imageUrls'] ?? data['photos'] ?? data['images']);

        final hasPhone = (phone ?? '').trim().isNotEmpty;
        final phoneDisplay = hasPhone
            ? (_isPhoneVisible ? _formatPhoneWithIndicatif(phone!) : _maskPhone(phone!))
            : "Numéro non renseigné";

        return Scaffold(
          backgroundColor: const Color(0xFFF2F3F6),
          appBar: AppBar(
            systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
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
                onPressed: () => _shareBasic(context, title, location),
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

          // ✅ bouton sticky
          bottomSheet: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              color: Colors.transparent,
              child: SizedBox(
                height: 64,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrestoOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 10,
                    textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () => _showContactOptionsSheet(
                    context: context,
                    annonceurId: annonceurId,
                    offerTitle: title,
                    phone: phone,
                  ),
                  child: const Text('Proposer mes services'),
                ),
              ),
            ),
          ),

          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 140),
            children: [
              _TopOfferCard(
                orange: kPrestoOrange,
                blue: kPrestoBlue,
                title: headerTitle,
                rightPrice: _formatPrice(budget),
                locationLine: postalCode.isNotEmpty ? "$location ($postalCode)" : location,
                chipLeft: _ChipSpec(label: "Rapide", bg: kPrestoBlue, fg: Colors.white),
                chipRight: _ChipSpec(
                  label: _s(data['distance'] ?? '15 km'),
                  bg: const Color(0xFFE9EDF3),
                  fg: const Color(0xFF243041),
                  border: const Color(0xFFD7DEE8),
                ),
                rightDelayBadge: duration != "Non précisé" ? duration : null,
              ),
              const SizedBox(height: 12),

              if (images.isNotEmpty) ...[
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
                                child: Image.network(
                                  images[i],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _MockPhotoTile(
                                    icon: Icons.broken_image_outlined,
                                    label: "Image",
                                  ),
                                ),
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
              ] else ...[
                // fallback (comme ton mock)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Row(
                      children: const [
                        Expanded(child: _MockPhotoTile(icon: Icons.local_shipping_outlined, label: "Utilitaire")),
                        SizedBox(width: 10),
                        Expanded(child: _MockPhotoTile(icon: Icons.inventory_2_outlined, label: "Colis")),
                        SizedBox(width: 10),
                        Expanded(child: _MockPhotoTile(icon: Icons.location_on_outlined, label: "Localisation")),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),
              const _SectionTitle("Description"),
              const SizedBox(height: 8),
              _SectionBody(_s(data['description']).isEmpty
                  ? "Aucune description détaillée fournie."
                  : _descriptionWithLineBreaks(_s(data['description']))),

              const SizedBox(height: 16),
              const _SectionTitle("Infos annonceur"),
              const SizedBox(height: 10),

              _AnnonceurInfoCard(
                pseudo: annonceurPseudo,
                isProfileVerified: isProfileVerified,
                rating: rating,
                reviewsCount: reviewsCount,
                missionDelay: missionDelay,
              ),

              const SizedBox(height: 16),
              const _SectionTitle("Contact"),
              const SizedBox(height: 10),
              _ContactCard(
                blue: kPrestoBlue,
                phoneText: phoneDisplay,
                toggleLabel:
                    hasPhone ? (_isPhoneVisible ? "Masquer" : "Afficher le numéro") : "Indisponible",
                onToggle: hasPhone ? () => setState(() => _isPhoneVisible = !_isPhoneVisible) : null,
                onMessage: () => _openExternalMessaging(
                  context,
                  phone: phone,
                  title: title,
                ),
                onShare: () => _copyLink(context),
                onCall: () => _callPhone(context, phone),
              ),
            ],
          ),
        );
      },
    );
  }

  Scaffold _loadingScaffold() => Scaffold(
        backgroundColor: const Color(0xFFF2F3F6),
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
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
        ),
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(kPrestoOrange)),
        ),
      );

  Scaffold _notFoundScaffold() => Scaffold(
        backgroundColor: const Color(0xFFF2F3F6),
        appBar: AppBar(
          systemOverlayStyle: prestoOverlayStyleFor(kPrestoBlue),
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
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.search_off, size: 58, color: Colors.black26),
                const SizedBox(height: 12),
                const Text(
                  "Annonce introuvable ou supprimée.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text("ID : ${widget.offerId}", style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      );
}

// -----------------------------------------------------------------------------
// UI Widgets (identiques style mock)
// -----------------------------------------------------------------------------
class _TopOfferCard extends StatelessWidget {
  final Color orange;
  final Color blue;

  final String title;
  final String rightPrice;
  final String locationLine;
  final _ChipSpec chipLeft;
  final _ChipSpec chipRight;
  final String? rightDelayBadge;

  const _TopOfferCard({
    required this.orange,
    required this.blue,
    required this.title,
    required this.rightPrice,
    required this.locationLine,
    required this.chipLeft,
    required this.chipRight,
    this.rightDelayBadge,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: orange,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      rightPrice,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (rightDelayBadge != null) ...[
                      const SizedBox(height: 6),
                      _Pill(
                        label: rightDelayBadge!,
                        bg: const Color(0xFFFFEDD5),
                        fg: const Color(0xFF9A3412),
                        border: const Color(0xFFFEC89A),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RowInfo(icon: Icons.place_outlined, iconColor: orange, text: locationLine),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Pill(label: chipLeft.label, bg: chipLeft.bg, fg: chipLeft.fg, border: chipLeft.border),
                    const SizedBox(width: 10),
                    _Pill(label: chipRight.label, bg: chipRight.bg, fg: chipRight.fg, border: chipRight.border),
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

class _AnnonceurInfoCard extends StatelessWidget {
  final String pseudo;
  final bool isProfileVerified;
  final double rating;
  final int reviewsCount;
  final String missionDelay;

  const _AnnonceurInfoCard({
    required this.pseudo,
    required this.isProfileVerified,
    required this.rating,
    required this.reviewsCount,
    required this.missionDelay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                child: const Icon(Icons.person_outline, color: Color(0xFF0F172A)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pseudo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isProfileVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7EE),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Profil vérifié',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0B7A3E),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 6),
              Text(
                rating > 0 ? rating.toStringAsFixed(1) : 'N/A',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$reviewsCount avis',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF4B5563),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Délai pour effectuer la mission : $missionDelay',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
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

  const _RowInfo({required this.icon, required this.iconColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
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

  const _Pill({required this.label, required this.bg, required this.fg, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: border != null ? Border.all(color: border!, width: 1) : null,
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w900)),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  final Color active;
  final Color inactive;

  const _Dots({required this.count, required this.index, required this.active, required this.inactive});

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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
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
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
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
        border: Border(top: BorderSide(color: Color(0xFFE4E7EE), width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final Color blue;
  final String phoneText;
  final String toggleLabel;
  final VoidCallback? onToggle;
  final VoidCallback onMessage;
  final VoidCallback onShare;
  final VoidCallback onCall;

  const _ContactCard({
    required this.blue,
    required this.phoneText,
    required this.toggleLabel,
    required this.onToggle,
    required this.onMessage,
    required this.onShare,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: onCall,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: const Color(0xFFEFF2F7), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.call, color: Color(0xFF0F172A)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phoneText,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: onToggle,
                  child: Text(toggleLabel, style: const TextStyle(fontWeight: FontWeight.w900)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onMessage,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text("Message", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrestoOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onShare,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text("Partager", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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

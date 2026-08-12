import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import 'fiche_pro_form_widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import '../app_core.dart' show kPrestoOrange;
import '../app/system_ui_style.dart' show prestoOverlayStyleFor;
import '../services/offer_details_mapper.dart' show buildOfferDetailsOffer;
import '../services/public_offers_query_helpers.dart';
import '../services/user_profile_bootstrap_service.dart';
import '../utils/friendly_snackbar.dart';
import '../utils/offer_helpers.dart';
import '../utils/profile_avatar_resolver.dart';
import '../widgets/verification_status_tooltip.dart';
import 'offers/offer_details_page.dart';

const Color _kOrange = Color(0xFFFF6600);
const Color _kBlue = Color(0xFF1A6FFF);

class FicheProPage extends StatefulWidget {
  const FicheProPage({super.key, required this.uid, this.isOwner = false});

  final String uid;
  final bool isOwner;

  @override
  State<FicheProPage> createState() => _FicheProPageState();
}

class _FicheProPageState extends State<FicheProPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _offersFuture;

  String _companyName = '';
  String _city = '';
  String _department = '';
  bool _siretVerified = false;
  double? _rating;
  String _photoUrl = '';

  String _description = '';
  List<String> _categories = [];
  List<String> _zones = [];
  String _experience = '';
  List<Map<String, String>> _disponibilites = [];
  List<String> _realisations = [];

  bool _isUploadingRealisation = false;

  @override
  void initState() {
    super.initState();
    _load();
    _offersFuture = _loadOffers();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadOffers() async {
    final results =
        await Future.wait<List<QueryDocumentSnapshot<Map<String, dynamic>>>>([
      FirebaseFirestore.instance
          .collection(kListingsCollection)
          .where('ownerId', isEqualTo: widget.uid)
          .where(publicListingsFilter())
          .get()
          .then((s) => s.docs),
      loadLegacyPublicOffersByOwner(
        ownerField: 'uid',
        ownerId: widget.uid,
        limit: 50,
        source: 'fiche_pro_offers_uid',
      ),
      loadLegacyPublicOffersByOwner(
        ownerField: 'userId',
        ownerId: widget.uid,
        limit: 50,
        source: 'fiche_pro_offers_userId',
      ),
    ]);

    final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final docs in results) {
      for (final d in docs) {
        byId[d.id] = d;
      }
    }

    return byId.values.where((d) => isVisibleInPublicBrowse(d.data())).toList();
  }

  Future<void> _load() async {
    try {
      final db = FirebaseFirestore.instance;

      final results = await Future.wait([
        db.collection('pro_profiles').doc(widget.uid).get(),
        db.collection('users').doc(widget.uid).get(),
      ]);

      final proData = results[0].data() ?? {};
      final userData = results[1].data() ?? {};

      // Fallback to legacy pros/{uid} if pro_profiles empty
      Map<String, dynamic> src = proData;
      if (src.isEmpty) {
        final legacy = await db.collection('pros').doc(widget.uid).get();
        src = legacy.data() ?? {};
      }

      final cats = _parseStringOrList(src['serviceCategories']);
      final zones = _parseStringOrList(
        src['interventionZones'] ?? src['interventionZone'],
      );

      final rawDispos = src['disponibilites'];
      final dispos = <Map<String, String>>[];
      if (rawDispos is List) {
        for (final d in rawDispos) {
          if (d is Map) {
            dispos.add({
              'day': d['day']?.toString() ?? '',
              'heures': d['heures']?.toString() ?? '',
            });
          }
        }
      }

      final rawReals = src['realisations'];
      final reals = <String>[];
      if (rawReals is List) {
        reals.addAll(rawReals.map((e) => e.toString()));
      }

      double? rating;
      final ratingSummary = src['ratingSummary'];
      if (ratingSummary is Map) {
        final avg = ratingSummary['averageRating'];
        if (avg != null) rating = (avg as num).toDouble();
      }

      String photoUrl = '';
      if (widget.isOwner) {
        photoUrl = customProfilePhotoUrl(
              FirebaseAuth.instance.currentUser?.photoURL,
            ) ??
            '';
      }
      if (photoUrl.isEmpty) {
        photoUrl = customProfilePhotoUrl(
              userData['profilePhotoUrl']?.toString() ??
                  userData['photoURL']?.toString(),
            ) ??
            '';
      }

      if (mounted) {
        setState(() {
          _companyName = src['companyName']?.toString() ??
              userData['displayName']?.toString() ??
              '';
          _city = src['city']?.toString() ?? '';
          _department = src['department']?.toString() ?? '';
          _siretVerified = src['siretVerified'] == true;
          _rating = rating;
          _photoUrl = photoUrl;
          _description = src['description']?.toString() ?? '';
          _categories = cats;
          _zones = zones;
          _experience = src['experience']?.toString() ?? '';
          _disponibilites = dispos;
          _realisations = reals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _parseStringOrList(dynamic raw) {
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await UserProfileBootstrapService.prepareProfileFirestoreAccess(
        user: user,
        forceRefreshToken: false,
        forceRefreshAppCheckToken: false,
      );

      await FirebaseFirestore.instance
          .collection('pro_profiles')
          .doc(widget.uid)
          .set({
        'description': _description,
        'serviceCategories': _categories,
        'interventionZones': _zones,
        'experience': _experience,
        'disponibilites': _disponibilites,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        showPrestoSnackBar(context, 'Fiche Pro enregistrée');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, "Impossible d'enregistrer. Réessayez.");
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Réalisations upload ──────────────────────────────────────────────────

  Future<void> _addRealisationPhoto() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 100);
    if (files.isEmpty || !mounted) return;

    setState(() => _isUploadingRealisation = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final newUrls = <String>[];
      for (final file in files) {
        final raw = await file.readAsBytes();
        final webp = await FlutterImageCompress.compressWithList(
          raw,
          format: CompressFormat.webp,
          quality: 85,
          minWidth: 1600,
          minHeight: 1,
        );
        final ts = DateTime.now().millisecondsSinceEpoch;
        final path = 'pro_realisations/${user.uid}/$ts.webp';
        final ref = FirebaseStorage.instance.ref(path);
        await ref.putData(
          webp,
          SettableMetadata(
            contentType: 'image/webp',
            cacheControl: 'public,max-age=604800',
          ),
        );
        newUrls.add(await ref.getDownloadURL());
      }

      await FirebaseFirestore.instance
          .collection('pro_profiles')
          .doc(widget.uid)
          .set({
        'realisations': FieldValue.arrayUnion(newUrls),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _realisations = [..._realisations, ...newUrls]);
      }
    } catch (_) {
      if (mounted) showErrorSnackBar(context, "Impossible d'ajouter la photo.");
    } finally {
      if (mounted) setState(() => _isUploadingRealisation = false);
    }
  }

  Future<void> _deleteRealisation(String url) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette photo ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FirebaseFirestore.instance
          .collection('pro_profiles')
          .doc(widget.uid)
          .set({
        'realisations': FieldValue.arrayRemove([url]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        setState(() => _realisations.remove(url));
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackBar(context, 'Impossible de supprimer la photo.');
      }
    }
  }

  // ─── Edit bottom sheets ────────────────────────────────────────────────────

  Future<void> _editDescription() async {
    final ctrl = TextEditingController(text: _description);
    final result = await _openSheet<String>(
      title: 'Description',
      builder: (ctx, setModal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            maxLines: 5,
            autofocus: true,
            decoration: ficheProInputDecoration('Décrivez votre activité, vos services…'),
          ),
          const SizedBox(height: 14),
          ficheProConfirmButton(ctx, () => Navigator.pop(ctx, ctrl.text.trim())),
        ],
      ),
    );
    if (result != null && result != _description) {
      setState(() {
        _description = result;
      });
    }
  }

  Future<void> _editExperience() async {
    final ctrl = TextEditingController(text: _experience);
    final result = await _openSheet<String>(
      title: 'Expérience',
      builder: (ctx, setModal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            decoration: ficheProInputDecoration('Ex : 3 ans, 10 ans, Débutant…'),
          ),
          const SizedBox(height: 14),
          ficheProConfirmButton(ctx, () => Navigator.pop(ctx, ctrl.text.trim())),
        ],
      ),
    );
    if (result != null && result != _experience) {
      setState(() {
        _experience = result;
      });
    }
  }

  Future<void> _editListField(
    String title,
    List<String> current,
    void Function(List<String>) onSave,
  ) async {
    final items = List<String>.from(current);
    final ctrl = TextEditingController();

    final result = await _openSheet<List<String>>(
      title: title,
      builder: (ctx, setModal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items
                  .map(
                    (item) => Chip(
                      label: Text(item),
                      onDeleted: () => setModal(() => items.remove(item)),
                      deleteIconColor: _kOrange,
                      backgroundColor: _kBlue.withValues(alpha: 0.10),
                      labelStyle: const TextStyle(
                        color: _kBlue,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (items.isNotEmpty) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: ficheProInputDecoration('Ajouter…'),
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) {
                      setModal(() {
                        items.add(v.trim());
                        ctrl.clear();
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Ajouter',
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (v.isNotEmpty) {
                    setModal(() {
                      items.add(v);
                      ctrl.clear();
                    });
                  }
                },
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: _kOrange,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ficheProConfirmButton(
            ctx,
            () => Navigator.pop(ctx, List<String>.from(items)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        onSave(result);
      });
    }
  }

  Future<void> _editDisponibilites() async {
    final dispos = List<Map<String, String>>.from(_disponibilites);
    final dayCtrl = TextEditingController();
    final heuresCtrl = TextEditingController();

    final result = await _openSheet<List<Map<String, String>>>(
      title: 'Disponibilités',
      scrollable: true,
      builder: (ctx, setModal) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...dispos.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kBlue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${d['day']}${(d['heures'] ?? '').isNotEmpty ? '  ${d['heures']}' : ''}',
                        style: const TextStyle(
                          color: _kBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Supprimer cette disponibilité',
                    onPressed: () => setModal(() => dispos.remove(d)),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (dispos.isNotEmpty) const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dayCtrl,
                  decoration: ficheProInputDecoration('Jour(s)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: heuresCtrl,
                  decoration: ficheProInputDecoration('Heures'),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Ajouter cette disponibilité',
                onPressed: () {
                  final day = dayCtrl.text.trim();
                  if (day.isNotEmpty) {
                    setModal(() {
                      dispos.add({
                        'day': day,
                        'heures': heuresCtrl.text.trim(),
                      });
                      dayCtrl.clear();
                      heuresCtrl.clear();
                    });
                  }
                },
                icon: const Icon(
                  Icons.add_circle_rounded,
                  color: _kOrange,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ficheProConfirmButton(
            ctx,
            () => Navigator.pop(ctx, List<Map<String, String>>.from(dispos)),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() {
        _disponibilites = result;
      });
    }
  }

  Future<T?> _openSheet<T>({
    required String title,
    required Widget Function(
      BuildContext ctx,
      void Function(void Function()) setModal,
    ) builder,
    bool scrollable = false,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            final inner = Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0A1F44),
                    ),
                  ),
                  const SizedBox(height: 14),
                  builder(ctx, setModal),
                ],
              ),
            );
            return scrollable ? SingleChildScrollView(child: inner) : inner;
          },
        );
      },
    );
  }

  // ─── UI builders ──────────────────────────────────────────────────────────

  Widget _sectionCard({
    required IconData icon,
    required String label,
    required Widget content,
    VoidCallback? onTap,
  }) {
    final tappable = widget.isOwner && onTap != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: tappable ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF6B7280), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0A1F44),
                      ),
                    ),
                    const SizedBox(height: 8),
                    content,
                  ],
                ),
              ),
              if (tappable) ...[
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E0),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyHint(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF9CA3AF),
          fontStyle: FontStyle.italic,
        ),
      );

  Widget _chipRow(List<String> items) {
    if (items.isEmpty) return _emptyHint('Appuyez pour ajouter');
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kBlue,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _dispoChips(List<Map<String, String>> dispos) {
    if (dispos.isEmpty) return _emptyHint('Appuyez pour ajouter');
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: dispos
          .map(
            (d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: _kBlue,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${d['day']}${(d['heures'] ?? '').isNotEmpty ? '  ${d['heures']}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kBlue,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildHeader() {
    final locationParts = [
      _city,
      _department,
    ].where((s) => s.isNotEmpty).toList();
    final location = locationParts.join(' • ');
    final initial =
        _companyName.isNotEmpty ? _companyName[0].toUpperCase() : '?';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEEEEEE), width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundImage:
                      _photoUrl.isNotEmpty ? NetworkImage(_photoUrl) : null,
                  onForegroundImageError:
                      _photoUrl.isNotEmpty ? (_, __) {} : null,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                if (widget.isOwner)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _kBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _companyName.isNotEmpty ? _companyName : 'Mon entreprise',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0A1F44),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_siretVerified) ...[
                        const VerificationStatusBadge(
                          icon: Icons.verified_rounded,
                          label: 'SIRET vérifié',
                          color: _kBlue,
                          backgroundColor: Color(0xFFEBF5FB),
                          message: kSiretVerificationDisclaimer,
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (_rating != null) ...[
                        Text(
                          _rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A1F44),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: _kOrange,
                        ),
                      ],
                    ],
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF6B7280),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            location,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(
              _isSaving ? 'Enregistrement…' : 'Enregistrer ma fiche',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffersSection() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _offersFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final docs = snap.data ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        return _sectionCard(
          icon: Icons.local_offer_outlined,
          label: 'Mes annonces',
          content: Column(children: docs.map(_offerMiniCard).toList()),
        );
      },
    );
  }

  Widget _offerMiniCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final title =
        data['title']?.toString() ?? data['titre']?.toString() ?? 'Annonce';
    final price = data['price'] ?? data['prix'];
    final priceText = price != null ? '$price €' : null;
    final imageUrls = data['imageUrls'];
    String? imageUrl;
    if (imageUrls is List && imageUrls.isNotEmpty) {
      imageUrl = imageUrls.first?.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OfferDetailsPage(
              offer: buildOfferDetailsOffer(offerId: doc.id, data: data),
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEEEEEE)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                  child: Image(
                    image: CachedNetworkImageProvider(imageUrl),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const SizedBox(width: 72, height: 72),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(11),
                      bottomLeft: Radius.circular(11),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_offer_outlined,
                    color: Color(0xFF6B7280),
                    size: 28,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A1F44),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (priceText != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          priceText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFCBD5E0),
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        systemOverlayStyle: prestoOverlayStyleFor(kPrestoOrange),
        title: Text(
          widget.isOwner
              ? 'Ma fiche Pro'
              : _companyName.isNotEmpty
                  ? _companyName
                  : 'Fiche Pro',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: kPrestoOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _sectionCard(
                  icon: Icons.description_outlined,
                  label: 'Description',
                  onTap: _editDescription,
                  content: _description.isEmpty
                      ? _emptyHint(
                          widget.isOwner
                              ? 'Appuyez pour ajouter'
                              : 'Non renseigné',
                        )
                      : Text(
                          _description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                            height: 1.5,
                          ),
                        ),
                ),
                _sectionCard(
                  icon: Icons.label_outline_rounded,
                  label: 'Catégories',
                  onTap: () => _editListField(
                    'Catégories',
                    _categories,
                    (v) => _categories = v,
                  ),
                  content: _chipRow(_categories),
                ),
                _sectionCard(
                  icon: Icons.location_on_outlined,
                  label: "Zone d'intervention",
                  onTap: () => _editListField(
                    "Zone d'intervention",
                    _zones,
                    (v) => _zones = v,
                  ),
                  content: _chipRow(_zones),
                ),
                _sectionCard(
                  icon: Icons.work_outline_rounded,
                  label: 'Expérience',
                  onTap: _editExperience,
                  content: _experience.isEmpty
                      ? _emptyHint(
                          widget.isOwner
                              ? 'Appuyez pour ajouter'
                              : 'Non renseigné',
                        )
                      : Text(
                          _experience,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4A5568),
                          ),
                        ),
                ),
                _sectionCard(
                  icon: Icons.schedule_outlined,
                  label: 'Disponibilités',
                  onTap: _editDisponibilites,
                  content: _dispoChips(_disponibilites),
                ),
                if (_realisations.isNotEmpty || widget.isOwner)
                  _sectionCard(
                    icon: Icons.photo_library_outlined,
                    label: 'Réalisations',
                    onTap: widget.isOwner ? _addRealisationPhoto : null,
                    content: _isUploadingRealisation
                        ? const SizedBox(
                            height: 90,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _realisations.isEmpty
                            ? _emptyHint(
                                widget.isOwner
                                    ? 'Appuyez pour ajouter des photos'
                                    : 'Photos de réalisations à venir',
                              )
                            : SizedBox(
                                height: 90,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _realisations.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (ctx, i) {
                                    final url = _realisations[i];
                                    return GestureDetector(
                                      onLongPress: widget.isOwner
                                          ? () => _deleteRealisation(url)
                                          : null,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image(
                                          image:
                                              CachedNetworkImageProvider(url),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                  ),
                _buildOffersSection(),
              ],
            ),
      bottomNavigationBar: widget.isOwner ? _buildSaveButton() : null,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin_space_page.dart';

class AccountPremiumPage extends StatefulWidget {
  const AccountPremiumPage({super.key});

  @override
  State<AccountPremiumPage> createState() => _AccountPremiumPageState();
}

class _AccountPremiumPageState extends State<AccountPremiumPage> {
  // ---- Style Prestō
  static const prestoOrange = Color(0xFFFF6600);
  static const textMuted = Color(0xFF6B7280);

  // ---- Données (branchement Firebase/Firestore)
  String displayName = "";
  String email = "";
  String avatarLetter = "";

  // Champs profil
  final pseudoCtrl = TextEditingController();
  String? selectedCity;
  String phoneCountryCode = "+33";
  final phoneCtrl = TextEditingController();

  // Exemple de complétude
  double profileCompletion = 0.0; // 0.0 -> 1.0

  // Sections “exemples”
  bool alertsDirty = false; // devient true si modifié
  String? selectedOffer; // titre sélectionné
  List<String> myOffers = const [];
  final Map<String, String> _offerIdByTitle = {};

  // Catégories favorites
  String? favCategory;
  String? favSubCategory;

  bool saving = false;

  bool get profileIncomplete => profileCompletion < 1.0;

  @override
  void dispose() {
    pseudoCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      email = user.email ?? "";
      displayName = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : (email.isNotEmpty ? email.split('@').first : 'Utilisateur');
      avatarLetter = (displayName.isNotEmpty ? displayName[0] : 'U').toUpperCase();
    });

    try {
      await Future.wait([
        _loadProfile(user.uid),
        _loadMyOffers(user.uid),
      ]);
    } catch (_) {
      // best-effort
    }

    setState(() {
      profileCompletion = _computeCompletion();
    });
  }

  Future<void> _loadProfile(String uid) async {
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snap.exists) return;
    final data = snap.data();
    if (data == null) return;
    String? s(dynamic v) => v == null ? null : v.toString();

    final pseudo = s(data['pseudo']);
    final city = s(data['city']);
    final phone = s(data['phone']);
    final favs = (data['favoriteCategories'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final selectedCats = (data['selectedFavoriteCategories'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final selectedSubs = (data['selectedFavoriteSubcategories'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

    if (mounted) {
      setState(() {
        if (pseudo != null) pseudoCtrl.text = pseudo;
        selectedCity = city;
        if (phone != null && phone.trim().isNotEmpty) {
          // essaye d’extraire l’indicatif si présent (simple heuristique)
          final p = phone.trim();
          if (p.startsWith('+') && p.length > 3) {
            final parts = p.split(' ');
            if (parts.length >= 2) {
              phoneCountryCode = parts.first;
              phoneCtrl.text = parts.sublist(1).join(' ');
            } else {
              phoneCtrl.text = p; // fallback simple
            }
          } else {
            phoneCtrl.text = p;
          }
        }

        // Renseigne une catégorie / sous-catégorie si existante
        favCategory = (selectedCats.isNotEmpty
                ? selectedCats.first
                : (favs.isNotEmpty ? favs.first : null)) ??
            favCategory;

        if (selectedSubs.isNotEmpty) {
          final first = selectedSubs.first;
          final idx = first.indexOf(' — ');
          if (idx > 0) {
            final cat = first.substring(0, idx);
            final sub = first.substring(idx + 3);
            // Si aucune catégorie explicitement choisie, cale-toi dessus
            favCategory ??= cat;
            favSubCategory = sub;
          }
        }
      });
    }
  }

  Future<void> _loadMyOffers(String uid) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('offers')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();
      final titles = <String>[];
      for (final doc in q.docs) {
        final data = doc.data();
        final t = (data['title'] ?? '').toString();
        if (t.isNotEmpty) titles.add(t);
        _offerIdByTitle[t] = doc.id;
      }
      if (mounted) {
        setState(() {
          myOffers = titles;
          if (selectedOffer == null && titles.isNotEmpty) {
            selectedOffer = titles.first;
          }
        });
      }
    } catch (_) {
      // silencieux
    }
  }

  // ---------------- ACTIONS (branche ton code ici) ----------------
  Future<void> onSaveProfile() async {
    setState(() => saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final pseudo = pseudoCtrl.text.trim();
      final city = (selectedCity ?? '').trim();
      final phone = phoneCtrl.text.trim();
      final phoneFull = phone.isEmpty ? null : '$phoneCountryCode $phone';

      final data = <String, dynamic>{
        'pseudo': pseudo,
        'city': city,
        'phone': phoneFull,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(data, SetOptions(merge: true));

      // Aligne aussi le displayName Firebase Auth si fourni
      if (pseudo.isNotEmpty) {
        try {
          await user.updateDisplayName(pseudo);
        } catch (_) {}
      }

      // Exemple recalcul complétude :
      setState(() => profileCompletion = _computeCompletion());
      if (!mounted) return;
      _snack("Profil enregistré ✅");
    } catch (e) {
      if (!mounted) return;
      _snack("Erreur: $e", error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void onOpenMessages() {
    Navigator.of(context).pushNamed('/messages');
  }

  Future<void> onValidateAlerts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favs = <String>[];
    if ((favCategory ?? '').isNotEmpty) favs.add(favCategory!);

    final selectedCats = <String>[];
    if ((favCategory ?? '').isNotEmpty) selectedCats.add(favCategory!);

    final selectedSubs = <String>[];
    if ((favCategory ?? '').isNotEmpty && (favSubCategory ?? '').isNotEmpty) {
      selectedSubs.add('${favCategory!} — ${favSubCategory!}');
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'favoriteCategories': favs,
        'selectedFavoriteCategories': selectedCats,
        'selectedFavoriteSubcategories': selectedSubs,
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      setState(() => alertsDirty = false);
      _snack("Alertes validées ✅");
    }
  }

  void onViewOfferDetail() {
    final offerTitle = selectedOffer ?? (myOffers.isNotEmpty ? myOffers.first : null);
    if (offerTitle == null) {
      _snack("Aucune annonce sélectionnée", error: true);
      return;
    }

    final offerId = _offerIdByTitle[offerTitle];
    if (offerId == null) {
      _snack("Annonce introuvable", error: true);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (ctx) {
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('offers').doc(offerId).get(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snap.hasData || !snap.data!.exists) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Annonce introuvable ou supprimée."),
              );
            }

            final data = snap.data!.data() ?? {};
            String s(String k) => (data[k] ?? '').toString();
            final budget = data['budget'];
            final budgetText = budget == null
                ? 'Budget non renseigné'
                : budget is num
                    ? '${budget.toString()} €'
                    : budget.toString();
            final images = (data['imageUrls'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .where((e) => e.isNotEmpty)
                    .toList() ??
                const <String>[];

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s('title').isEmpty ? offerTitle : s('title'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s('city').isNotEmpty ? s('city') : s('location'),
                      style: const TextStyle(color: textMuted, fontSize: 13.5),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (s('category').isNotEmpty)
                          _chip("Catégorie", s('category')),
                        if (s('subcategory').isNotEmpty)
                          _chip("Sous-catégorie", s('subcategory')),
                        _chip("Budget", budgetText),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s('description').isEmpty ? 'Pas de description.' : s('description'),
                      style: const TextStyle(fontSize: 14.5, height: 1.35),
                    ),
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (_, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.network(images[index], width: 200, height: 140, fit: BoxFit.cover),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: prestoOrange,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                            label: const Text('Fermer'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> onDeleteOffer() async {
    final offerTitle = selectedOffer ?? (myOffers.isNotEmpty ? myOffers.first : null);
    if (offerTitle == null) {
      _snack("Aucune annonce sélectionnée", error: true);
      return;
    }

    final offerId = _offerIdByTitle[offerTitle];
    if (offerId == null) {
      _snack("Annonce introuvable", error: true);
      return;
    }

    // Suppression sans confirmation complexe pour rester rapide
    try {
      await FirebaseFirestore.instance.collection('offers').doc(offerId).delete();
      if (!mounted) return;

      setState(() {
        myOffers = myOffers.where((t) => t != offerTitle).toList();
        _offerIdByTitle.remove(offerTitle);
        if (selectedOffer == offerTitle) {
          selectedOffer = myOffers.isNotEmpty ? myOffers.first : null;
        }
      });

      _snack("Annonce supprimée 🗑️");
    } catch (e) {
      if (!mounted) return;
      _snack("Suppression impossible: $e", error: true);
    }
  }

  void onCreatePro() {
    // TODO: open pro onboarding
    _snack("💼 Créer un compte Pro");
  }

  void onOpenAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const AdminSpacePage(),
      ),
    );
  }

  Future<void> onLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      _snack("Déconnecté ✅");
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      _snack("Erreur déconnexion: $e", error: true);
    }
  }

  double _computeCompletion() {
    int total = 3; // pseudo + ville + tel (ex)
    int done = 0;
    if (pseudoCtrl.text.trim().isNotEmpty) done++;
    if ((selectedCity ?? "").trim().isNotEmpty) done++;
    if (phoneCtrl.text.trim().length >= 6) done++;
    return done / total;
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red.shade700 : Colors.black87,
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label : $value",
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          "Mon compte Prestō",
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.black.withOpacity(0.06)),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // 1) HEADER PROFIL PREMIUM
            _PremiumCard(
              radius: 28,
              child: Column(
                children: [
                  Row(
                    children: [
                      _AvatarCircle(letter: avatarLetter),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _CompletionChip(progress: profileCompletion),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: profileCompletion.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: Colors.black.withOpacity(0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        profileCompletion >= 1.0 ? Colors.green.shade600 : prestoOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profileIncomplete
                        ? "Complète ton profil pour améliorer ta visibilité et la qualité des mises en relation."
                        : "Profil complet ✅ Tu restes connecté automatiquement.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.2, color: textMuted, height: 1.3),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2) ACTION DOMINANTE (1 seul bouton orange)
            _PremiumCard(
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (profileIncomplete) ...[
                    _SectionTitle("Mon profil"),
                    const SizedBox(height: 10),

                    _Input(hint: "Pseudo", controller: pseudoCtrl, enabled: !saving),
                    const SizedBox(height: 10),

                    // Ville (remplace par ton dropdown / autocomplete)
                    _Dropdown(
                      hint: "Ville",
                      value: selectedCity,
                      items: const ["Morne-à-l'Eau", "Les Abymes", "Pointe-à-Pitre", "Baie-Mahault"],
                      onChanged: saving ? null : (v) => setState(() => selectedCity = v),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _Dropdown(
                            hint: phoneCountryCode,
                            value: phoneCountryCode,
                            items: const ["+33", "+590", "+594", "+596"],
                            onChanged: saving ? null : (v) => setState(() => phoneCountryCode = v ?? "+33"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 7,
                          child: _Input(
                            hint: "Téléphone",
                            controller: phoneCtrl,
                            enabled: !saving,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    _MainOrangeButton(
                      label: "Enregistrer mon profil",
                      loading: saving,
                      onTap: saving ? null : onSaveProfile,
                    ),

                    const SizedBox(height: 10),

                    // Secondaire (outline)
                    _OutlineButton(
                      label: "Ouvrir mes messages",
                      onTap: saving ? null : onOpenMessages,
                    ),
                  ] else ...[
                    _SectionTitle("Accès rapide"),
                    const SizedBox(height: 12),

                    _MainOrangeButton(
                      label: "Ouvrir mes messages",
                      loading: false,
                      onTap: onOpenMessages,
                    ),

                    const SizedBox(height: 10),

                    _OutlineButton(
                      label: "Modifier mon profil",
                      onTap: () => setState(() {
                        // tu peux ouvrir une page “éditer profil”
                        // ou juste ré-afficher les champs ici.
                        profileCompletion = 0.66; // demo
                      }),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3) MES ANNONCES PUBLIÉES
            _PremiumCard(
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle("Mes annonces publiées"),
                  const SizedBox(height: 10),

                  _Dropdown(
                    hint: "Mes annonces",
                    value: selectedOffer ?? (myOffers.isNotEmpty ? myOffers.first : null),
                    items: myOffers,
                    onChanged: (v) => setState(() => selectedOffer = v),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Recherche menuisier pour\nréparation de porte",
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "MORNE À L’EAU • Bricolage / Travaux • 80 €",
                          style: TextStyle(fontSize: 12.8, color: textMuted),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _OutlineButton(
                          label: "Voir détail",
                          onTap: onViewOfferDetail,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DangerButton(
                          label: "Supprimer",
                          onTap: onDeleteOffer,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 4) FAVORIS / ALERTES
            _PremiumCard(
              radius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionTitle("Mes catégories favorites"),
                  const SizedBox(height: 6),
                  const Text(
                    "Sélectionne les catégories pour lesquelles tu veux être notifié quand une annonce est publiée.",
                    style: TextStyle(fontSize: 13.2, color: textMuted, height: 1.3),
                  ),
                  const SizedBox(height: 12),

                  _Dropdown(
                    hint: "Choisir des catégories",
                    value: favCategory,
                    items: const ["Bricolage / Travaux", "Services", "Événementiel", "Transport"],
                    onChanged: (v) => setState(() {
                      favCategory = v;
                      alertsDirty = true;
                    }),
                  ),
                  const SizedBox(height: 10),

                  _Dropdown(
                    hint: "Choisir des sous-catégories",
                    value: favSubCategory,
                    items: const ["Menuiserie", "Peinture", "Électricité", "Plomberie"],
                    onChanged: (v) => setState(() {
                      favSubCategory = v;
                      alertsDirty = true;
                    }),
                  ),

                  const SizedBox(height: 12),

                  // Bouton secondaire (bleu) -> pas orange pour respecter “1 action dominante”
                  _SecondaryBlueButton(
                    label: "Valider mes alertes",
                    enabled: alertsDirty,
                    onTap: alertsDirty ? onValidateAlerts : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 5) PRO (second plan)
            _SoftInfoCard(
              icon: Icons.work_outline,
              title: "Vous êtes une entreprise ?",
              body: "Créez un profil Pro pour publier plus facilement et accéder aux options Pro.",
              badge: "Bientôt disponible",
              buttonLabel: "Créer un compte Pro",
              onTap: onCreatePro,
            ),

            const SizedBox(height: 12),

            // 6) ADMIN (second plan)
            _SoftInfoCard(
              icon: Icons.admin_panel_settings_outlined,
              title: "Espace admin",
              body: "Outils d’administration et réglages Micro-IA.",
              badge: null,
              buttonLabel: "Ouvrir l’espace admin",
              onTap: onOpenAdmin,
            ),

            const SizedBox(height: 14),

            // 7) LOGOUT (minimal, pas agressif)
            _OutlineButton(
              label: "Se déconnecter",
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- UI Components (premium) ----------------

class _PremiumCard extends StatelessWidget {
  final Widget child;
  final double radius;
  const _PremiumCard({required this.child, this.radius = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: child,
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
      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String letter;
  const _AvatarCircle({required this.letter});

  @override
  Widget build(BuildContext context) {
    const prestoOrange = Color(0xFFFF6600);
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: prestoOrange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: prestoOrange,
          ),
        ),
      ),
    );
  }
}

class _CompletionChip extends StatelessWidget {
  final double progress;
  const _CompletionChip({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).round();
    final ok = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: ok ? Colors.green.withOpacity(0.12) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ok ? "100% ✅" : "$pct% complet",
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: ok ? Colors.green.shade700 : Colors.black87,
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType? keyboardType;

  const _Input({
    required this.hint,
    required this.controller,
    required this.enabled,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: Colors.black.withOpacity(0.22)),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  const _Dropdown({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.12)),
    );

    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: Colors.black.withOpacity(0.22)),
        ),
      ),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis)))
          .toList(),
    );
  }
}

class _MainOrangeButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _MainOrangeButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const prestoOrange = Color(0xFFFF6600);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: prestoOrange,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation(Colors.white)),
              )
            : Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
              ),
      ),
    );
  }
}

class _SecondaryBlueButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  const _SecondaryBlueButton({required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const prestoBlue = Color(0xFF1A73E8);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: enabled ? prestoBlue : prestoBlue.withOpacity(0.35),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 14.8, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const prestoOrange = Color(0xFFFF6600);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: prestoOrange.withOpacity(0.55)),
        ),
        alignment: Alignment.center,
        child: const Text(
          "",
          style: TextStyle(),
        ),
      ),
    ).buildWithLabel(label);
  }
}

extension _OutlineButtonExt on Widget {
  Widget buildWithLabel(String label) {
    // petit hack pour conserver le InkWell + label sans dupliquer le widget
    return Builder(builder: (context) {
      const prestoOrange = Color(0xFFFF6600);
      return InkWell(
        onTap: (this as InkWell).onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: prestoOrange.withOpacity(0.55)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: prestoOrange,
              fontWeight: FontWeight.w900,
              fontSize: 14.5,
            ),
          ),
        ),
      );
    });
  }
}

class _DangerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14.5),
        ),
      ),
    );
  }
}

class _SoftInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? badge;
  final String buttonLabel;
  final VoidCallback onTap;

  const _SoftInfoCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.badge,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const prestoOrange = Color(0xFFFF6600);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: prestoOrange.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: prestoOrange, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(fontSize: 13.4, color: Colors.grey.shade700, height: 1.25),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: prestoOrange.withOpacity(0.55)),
                    ),
                    child: Text(
                      buttonLabel,
                      style: const TextStyle(
                        color: prestoOrange,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/splash_screen.dart';
import '../pages/account/account_security_page.dart';
import '../pages/account/change_email_page.dart';
import '../pages/account/change_password_page.dart';
import '../pages/account/delete_account_page.dart';
import '../pages/account_page.dart';
import '../pages/admin/ad_placeholder_images_admin_page.dart';
import '../pages/admin_hero_slides_page.dart';
import '../pages/admin_photo_reviews_page.dart';
import '../pages/admin_space_loader.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/reset_password_success_page.dart';
import '../pages/auth/verify_email_page.dart';
import '../pages/consult_offers_page.dart';
import '../pages/entrepreneur_toolbox_page.dart';
import '../pages/home_page.dart';
import '../pages/legal_info_page.dart';
import '../pages/messages/conversation_thread_page.dart';
import '../pages/messages/conversations_list_page.dart';
import '../pages/messages/messages_page_v2.dart';
import '../pages/offers/offer_details_page.dart';
import '../pages/pro_profile_page.dart';
import '../pages/publish_offer_page.dart';
import '../pages/toolbox_hub_page.dart';
import '../pages/toolbox_je_me_lance_page.dart';
import '../pages/toolbox_page.dart';

enum PageStatus { active, inProgress, deprecated, devOnly }

class _GroupMeta {
  final String name;
  final IconData icon;
  const _GroupMeta(this.name, this.icon);
}

const List<_GroupMeta> _kGroups = [
  _GroupMeta('Navigation principale', Icons.home_rounded),
  _GroupMeta('Authentification', Icons.lock_rounded),
  _GroupMeta('Sous-pages Compte', Icons.manage_accounts_rounded),
  _GroupMeta('Offres & Annonces', Icons.campaign_rounded),
  _GroupMeta('Messagerie', Icons.chat_bubble_rounded),
  _GroupMeta('Profil public', Icons.person_rounded),
  _GroupMeta('Boîte à outils', Icons.construction_rounded),
  _GroupMeta('Légal', Icons.gavel_rounded),
  _GroupMeta('Admin', Icons.admin_panel_settings_rounded),
  _GroupMeta('Développement', Icons.bug_report_rounded),
];

class PageCaptureEntry {
  final int number;
  final String id;
  final String title;
  final String group;
  final String description;
  final PageStatus status;
  final WidgetBuilder builder;

  const PageCaptureEntry({
    required this.number,
    required this.id,
    required this.title,
    required this.group,
    required this.description,
    required this.status,
    required this.builder,
  });
}

class PageCaptureCatalogPage extends StatelessWidget {
  const PageCaptureCatalogPage({super.key});

  static final List<PageCaptureEntry> entries = <PageCaptureEntry>[
    // ── Navigation principale ────────────────────────────────────────────────
    PageCaptureEntry(
      number: 1,
      id: '01_splash_screen',
      title: 'SplashScreen',
      group: 'Navigation principale',
      description: 'Écran de démarrage de l\'application.',
      status: PageStatus.active,
      builder: (_) => const SplashScreen(),
    ),
    PageCaptureEntry(
      number: 2,
      id: '02_home_page',
      title: 'HomePage',
      group: 'Navigation principale',
      description: 'Accueil — slider hero, catégories, annonces récentes.',
      status: PageStatus.active,
      builder: (_) => const HomePage(),
    ),
    PageCaptureEntry(
      number: 3,
      id: '03_consult_offers_page',
      title: 'ConsultOffersPage',
      group: 'Navigation principale',
      description: 'Je consulte — marketplace, filtres, recherche.',
      status: PageStatus.active,
      builder: (_) => const ConsultOffersPage(),
    ),
    PageCaptureEntry(
      number: 4,
      id: '04_publish_offer_page',
      title: 'PublishOfferPage',
      group: 'Navigation principale',
      description: 'Je publie — formulaire, micro IA, photos.',
      status: PageStatus.active,
      builder: (_) => const PublishOfferPage(),
    ),
    PageCaptureEntry(
      number: 5,
      id: '05_messages_page',
      title: 'MessagesPage',
      group: 'Navigation principale',
      description:
          'Wrapper historique de la messagerie (remplacé par MessagesPageV2).',
      status: PageStatus.deprecated,
      builder: (_) => const MessagesPage(),
    ),
    PageCaptureEntry(
      number: 6,
      id: '06_messages_page_v2',
      title: 'MessagesPageV2',
      group: 'Navigation principale',
      description: 'Messagerie — point d\'entrée principal actuel.',
      status: PageStatus.active,
      builder: (_) => const MessagesPageV2(),
    ),
    PageCaptureEntry(
      number: 7,
      id: '07_account_page',
      title: 'AccountPage',
      group: 'Navigation principale',
      description: 'Mon compte — profil, alertes, annonces, paramètres.',
      status: PageStatus.active,
      builder: (_) => const AccountPage(),
    ),
    // ── Authentification ─────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 8,
      id: '08_login_page',
      title: 'LoginPage',
      group: 'Authentification',
      description: 'Connexion email / mot de passe.',
      status: PageStatus.active,
      builder: (_) => const LoginPage(),
    ),
    PageCaptureEntry(
      number: 9,
      id: '09_register_page',
      title: 'RegisterPage',
      group: 'Authentification',
      description: 'Inscription nouveau compte.',
      status: PageStatus.active,
      builder: (_) => const RegisterPage(),
    ),
    PageCaptureEntry(
      number: 10,
      id: '10_forgot_password_page',
      title: 'ForgotPasswordPage',
      group: 'Authentification',
      description: 'Demande de réinitialisation mot de passe.',
      status: PageStatus.active,
      builder: (_) => const ForgotPasswordPage(),
    ),
    PageCaptureEntry(
      number: 11,
      id: '11_reset_password_success_page',
      title: 'ResetPasswordSuccessPage',
      group: 'Authentification',
      description: 'Confirmation envoi email de réinitialisation.',
      status: PageStatus.active,
      builder: (_) =>
          const ResetPasswordSuccessPage(email: 'demo@ilipresto.fr'),
    ),
    PageCaptureEntry(
      number: 12,
      id: '12_verify_email_page',
      title: 'VerifyEmailPage',
      group: 'Authentification',
      description: 'Invitation à vérifier l\'email avant accès.',
      status: PageStatus.active,
      builder: (_) => const VerifyEmailPage(),
    ),
    // ── Sous-pages Compte ────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 13,
      id: '13_account_security_page',
      title: 'AccountSecurityPage',
      group: 'Sous-pages Compte',
      description: 'Sécurité — email vérifié, changement identifiants.',
      status: PageStatus.active,
      builder: (_) => const AccountSecurityPage(),
    ),
    PageCaptureEntry(
      number: 14,
      id: '14_change_email_page',
      title: 'ChangeEmailPage',
      group: 'Sous-pages Compte',
      description: 'Modification de l\'adresse email.',
      status: PageStatus.active,
      builder: (_) => const ChangeEmailPage(),
    ),
    PageCaptureEntry(
      number: 15,
      id: '15_change_password_page',
      title: 'ChangePasswordPage',
      group: 'Sous-pages Compte',
      description: 'Modification du mot de passe.',
      status: PageStatus.active,
      builder: (_) => const ChangePasswordPage(),
    ),
    PageCaptureEntry(
      number: 16,
      id: '16_delete_account_page',
      title: 'DeleteAccountPage',
      group: 'Sous-pages Compte',
      description: 'Suppression définitive du compte.',
      status: PageStatus.active,
      builder: (_) => const DeleteAccountPage(),
    ),
    // ── Offres & Annonces ────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 17,
      id: '17_offer_details_page',
      title: 'OfferDetailsPage',
      group: 'Offres & Annonces',
      description: 'Détail annonce — info, contact, paiement audio.',
      status: PageStatus.active,
      builder: (_) => OfferDetailsPage(
        offer: _sampleOfferData(),
        currentUserId: 'buyer-demo',
      ),
    ),
    PageCaptureEntry(
      number: 18,
      id: '18_offer_deep_link_page',
      title: 'OfferDeepLinkPage',
      group: 'Offres & Annonces',
      description: 'Résolution deep link sur identifiant de démonstration.',
      status: PageStatus.active,
      builder: (_) => const OfferDeepLinkPage(
        offerId: 'demo-offer',
        preferMarketplace: true,
      ),
    ),
    // ── Messagerie ───────────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 19,
      id: '19_conversations_list_page',
      title: 'ConversationsListPage',
      group: 'Messagerie',
      description: 'Liste de toutes les conversations.',
      status: PageStatus.active,
      builder: (_) => const ConversationsListPage(),
    ),
    PageCaptureEntry(
      number: 20,
      id: '20_conversation_thread_page',
      title: 'ConversationThreadPage',
      group: 'Messagerie',
      description: 'Fil de discussion sur données de démonstration.',
      status: PageStatus.active,
      builder: (_) => const ConversationThreadPage(
        conversationId: 'demo-conversation',
        offerTitle: 'Conversation de démonstration',
        currentUserId: 'demo-user',
        initialDraftText: 'Bonjour, je vous contacte pour cette annonce.',
      ),
    ),
    // ── Profil public ────────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 21,
      id: '21_user_public_profile_page',
      title: 'UserPublicProfilePage',
      group: 'Profil public',
      description:
          'Profil public utilisateur sur identifiant de démonstration.',
      status: PageStatus.active,
      builder: (_) => const UserPublicProfilePage(
        userId: 'demo-public-user',
        initialPseudo: 'Utilisateur Démo',
      ),
    ),
    PageCaptureEntry(
      number: 22,
      id: '22_pro_profile_page',
      title: 'ProProfilePage',
      group: 'Profil public',
      description: 'Création et édition du profil professionnel.',
      status: PageStatus.active,
      builder: (_) => const ProProfilePage(),
    ),
    // ── Boîte à outils ──────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 23,
      id: '23_toolbox_hub_page',
      title: 'ToolboxHubPage',
      group: 'Boîte à outils',
      description: 'Hub — sélection entre les outils entrepreneur.',
      status: PageStatus.active,
      builder: (_) => const ToolboxHubPage(),
    ),
    PageCaptureEntry(
      number: 24,
      id: '24_current_toolbox_page',
      title: 'CurrentToolboxPage',
      group: 'Boîte à outils',
      description: 'Parcours toolbox courant.',
      status: PageStatus.active,
      builder: (_) => const CurrentToolboxPage(),
    ),
    PageCaptureEntry(
      number: 25,
      id: '25_entrepreneur_calculator_page',
      title: 'EntrepreneurCalculatorPage',
      group: 'Boîte à outils',
      description: 'Calculatrice entrepreneur — prix de revient.',
      status: PageStatus.active,
      builder: (_) => const EntrepreneurCalculatorPage(),
    ),
    PageCaptureEntry(
      number: 26,
      id: '26_toolbox_je_me_lance_page',
      title: 'ToolboxJeMeLancePage',
      group: 'Boîte à outils',
      description: 'Parcours IA — création d\'entreprise guidée.',
      status: PageStatus.active,
      builder: (_) => const ToolboxJeMeLancePage(),
    ),
    PageCaptureEntry(
      number: 27,
      id: '27_toolbox_page',
      title: 'ToolboxPage',
      group: 'Boîte à outils',
      description:
          'Ancienne page toolbox standalone (remplacée par ToolboxHubPage).',
      status: PageStatus.deprecated,
      builder: (_) => const ToolboxPage(),
    ),
    PageCaptureEntry(
      number: 28,
      id: '28_entrepreneur_toolbox_page',
      title: 'EntrepreneurToolboxPage',
      group: 'Boîte à outils',
      description: 'Alias toolbox entrepreneur (remplacé par ToolboxHubPage).',
      status: PageStatus.deprecated,
      builder: (_) => const EntrepreneurToolboxPage(),
    ),
    // ── Légal ────────────────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 29,
      id: '29_legal_info_page',
      title: 'LegalInfoPage',
      group: 'Légal',
      description: 'CGU, politique de confidentialité, mentions légales.',
      status: PageStatus.active,
      builder: (_) => const LegalInfoPage(),
    ),
    // ── Admin ────────────────────────────────────────────────────────────────
    PageCaptureEntry(
      number: 30,
      id: '30_admin_space_page',
      title: 'AdminSpacePage',
      group: 'Admin',
      description: 'Espace admin — KPIs, config, outils.',
      status: PageStatus.active,
      builder: (_) => const AdminSpaceLoader(),
    ),
    PageCaptureEntry(
      number: 31,
      id: '31_admin_photo_reviews_page',
      title: 'AdminPhotoReviewsPage',
      group: 'Admin',
      description: 'Modération photos — swipe validation.',
      status: PageStatus.active,
      builder: (_) => const AdminPhotoReviewsPage(),
    ),
    PageCaptureEntry(
      number: 32,
      id: '32_admin_hero_slides_page',
      title: 'AdminHeroSlidesPage',
      group: 'Admin',
      description: 'Gestion Hero slider — images et vidéos.',
      status: PageStatus.active,
      builder: (_) => const AdminHeroSlidesPage(),
    ),
    PageCaptureEntry(
      number: 33,
      id: '33_ad_placeholder_images_admin_page',
      title: 'AdPlaceholderImagesAdminPage',
      group: 'Admin',
      description: 'Images placeholders bannières Je consulte.',
      status: PageStatus.active,
      builder: (_) => const AdPlaceholderImagesAdminPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pageId = kIsWeb ? Uri.base.queryParameters['page'] : null;
    final entry = _entryForId(pageId);
    if (entry != null) {
      return _PageCaptureViewer(entry: entry);
    }

    final grouped = <String, List<PageCaptureEntry>>{};
    for (final e in entries) {
      (grouped[e.group] ??= []).add(e);
    }

    final activeCount =
        entries.where((e) => e.status == PageStatus.active).length;
    final deprecatedCount =
        entries.where((e) => e.status == PageStatus.deprecated).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Catalogue des pages')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SummaryCard(
            total: entries.length,
            active: activeCount,
            deprecated: deprecatedCount,
          ),
          const SizedBox(height: 16),
          for (final meta in _kGroups)
            if (grouped.containsKey(meta.name)) ...[
              _GroupHeader(meta: meta),
              const SizedBox(height: 6),
              for (final item in grouped[meta.name]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EntryTile(item: item),
                ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  static PageCaptureEntry? _entryForId(String? pageId) {
    if (pageId == null || pageId.trim().isEmpty) return null;
    for (final entry in entries) {
      if (entry.id == pageId.trim()) return entry;
    }
    return null;
  }
}

// ─── Summary card ────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int total;
  final int active;
  final int deprecated;

  const _SummaryCard({
    required this.total,
    required this.active,
    required this.deprecated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_rounded, size: 20, color: Color(0xFF1A73E8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$total pages répertoriées · $active actives · $deprecated dépréciées',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Group header ─────────────────────────────────────────────────────────────

class _GroupHeader extends StatelessWidget {
  final _GroupMeta meta;
  const _GroupHeader({required this.meta});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
      child: Row(
        children: [
          Icon(meta.icon, size: 13, color: Colors.black38),
          const SizedBox(width: 6),
          Text(
            meta.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.black38,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Entry tile ───────────────────────────────────────────────────────────────

class _EntryTile extends StatelessWidget {
  final PageCaptureEntry item;
  const _EntryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              '${item.number.toString().padLeft(2, '0')}. ${item.title}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(status: item.status),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          item.description,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ),
      trailing: FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _PageCaptureViewer(entry: item),
          ),
        ),
        child: const Text('Ouvrir'),
      ),
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final PageStatus status;
  const _StatusBadge({required this.status});

  String get _label {
    switch (status) {
      case PageStatus.active:
        return 'Actif';
      case PageStatus.inProgress:
        return 'En cours';
      case PageStatus.deprecated:
        return 'Déprécié';
      case PageStatus.devOnly:
        return 'Dev';
    }
  }

  Color get _color {
    switch (status) {
      case PageStatus.active:
        return const Color(0xFF2E7D32);
      case PageStatus.inProgress:
        return const Color(0xFF1A73E8);
      case PageStatus.deprecated:
        return const Color(0xFF9E9E9E);
      case PageStatus.devOnly:
        return const Color(0xFFFF6600);
    }
  }

  Color get _bg {
    switch (status) {
      case PageStatus.active:
        return const Color(0xFFE8F5E9);
      case PageStatus.inProgress:
        return const Color(0xFFE3F2FD);
      case PageStatus.deprecated:
        return const Color(0xFFF5F5F5);
      case PageStatus.devOnly:
        return const Color(0xFFFFF3E0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: _color,
        ),
      ),
    );
  }
}

// ─── Page viewer ─────────────────────────────────────────────────────────────

class _PageCaptureViewer extends StatelessWidget {
  final PageCaptureEntry entry;

  const _PageCaptureViewer({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: entry.builder(context)),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 12,
            right: 12,
            child: Material(
              color: Colors.transparent,
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Catalogue'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Text(
                          '${entry.number.toString().padLeft(2, '0')} — ${entry.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
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

// ─── Sample data ─────────────────────────────────────────────────────────────

Map<String, dynamic> _sampleOfferData() {
  return <String, dynamic>{
    'id': 'demo-offer',
    'offerId': 'demo-offer',
    'listingId': 'demo-offer',
    'title': 'Livraison urgente de documents',
    'description': 'Besoin d un coursier pour livrer un dossier aujourd hui.',
    'budget': 45,
    'price': 45,
    'city': 'Les Abymes',
    'postalCode': '97139',
    'location': 'Les Abymes',
    'category': 'Transport / Livraison',
    'advertiserId': 'seller-demo',
    'advertiserName': 'Utilisateur Démo',
    'displayName': 'Utilisateur Démo',
    'userId': 'seller-demo',
    'ownerId': 'seller-demo',
    'uid': 'seller-demo',
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'status': 'active',
    'isMarketplace': true,
    'imageUrls': const <String>[],
    'photos': const <String>[],
    'visibility': 'public',
  };
}

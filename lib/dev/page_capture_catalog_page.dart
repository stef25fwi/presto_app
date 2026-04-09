import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../main.dart' as app;
import '../pages/admin_space_page.dart';
import '../pages/entrepreneur_toolbox_page.dart';
import '../pages/legal_info_page.dart';
import '../pages/messages/conversation_thread_page.dart';
import '../pages/messages/conversations_list_page.dart';
import '../pages/messages/messages_page_v2.dart';
import '../pages/offers/offer_details_page.dart';
import '../pages/pro_profile_page.dart';
import '../pages/toolbox_hub_page.dart';
import '../pages/toolbox_je_me_lance_page.dart';
import '../pages/toolbox_page.dart';

class PageCaptureCatalogPage extends StatelessWidget {
  const PageCaptureCatalogPage({super.key});

  static final List<PageCaptureEntry> entries = <PageCaptureEntry>[
    PageCaptureEntry(
      number: 1,
      id: '01_splash_screen',
      title: 'SplashScreen',
      builder: (_) => const app.SplashScreen(),
      note: 'Ecran de demarrage de l application.',
    ),
    PageCaptureEntry(
      number: 2,
      id: '02_home_page',
      title: 'HomePage',
      builder: (_) => const app.HomePage(),
      note: 'Accueil principal.',
    ),
    PageCaptureEntry(
      number: 3,
      id: '03_consult_offers_page',
      title: 'ConsultOffersPage',
      builder: (_) => const app.ConsultOffersPage(),
      note: 'Consultation des annonces.',
    ),
    PageCaptureEntry(
      number: 4,
      id: '04_publish_offer_page',
      title: 'PublishOfferPage',
      builder: (_) => const app.PublishOfferPage(),
      note: 'Publication active.',
    ),
    PageCaptureEntry(
      number: 5,
      id: '05_messages_page',
      title: 'MessagesPage',
      builder: (_) => const app.MessagesPage(),
      note: 'Wrapper historique de la messagerie.',
    ),
    PageCaptureEntry(
      number: 6,
      id: '06_messages_page_v2',
      title: 'MessagesPageV2',
      builder: (_) => const MessagesPageV2(),
      note: 'Entree principale actuelle de la messagerie.',
    ),
    PageCaptureEntry(
      number: 7,
      id: '07_conversations_list_page',
      title: 'ConversationsListPage',
      builder: (_) => const ConversationsListPage(),
      note: 'Liste des conversations.',
    ),
    PageCaptureEntry(
      number: 8,
      id: '08_conversation_thread_page',
      title: 'ConversationThreadPage',
      builder: (_) => const ConversationThreadPage(
        conversationId: 'demo-conversation',
        offerTitle: 'Conversation de demonstration',
        currentUserId: 'demo-user',
        initialDraftText: 'Bonjour, je vous contacte pour cette annonce.',
      ),
      note: 'Fil de discussion sur donnees de demonstration.',
    ),
    PageCaptureEntry(
      number: 9,
      id: '09_account_page',
      title: 'AccountPage',
      builder: (_) => const app.AccountPage(),
      note: 'Compte principal.',
    ),
    PageCaptureEntry(
      number: 10,
      id: '10_user_public_profile_page',
      title: 'UserPublicProfilePage',
      builder: (_) => const app.UserPublicProfilePage(
        userId: 'demo-public-user',
        initialPseudo: 'Stephane Demo',
      ),
      note: 'Profil public utilisateur sur identifiant de demonstration.',
    ),
    PageCaptureEntry(
      number: 11,
      id: '11_offer_details_page',
      title: 'OfferDetailsPage',
      builder: (_) => OfferDetailsPage(
        offer: _sampleOfferData(),
        currentUserId: 'buyer-demo',
      ),
      note: 'Detail annonce avec donnees injectees.',
    ),
    PageCaptureEntry(
      number: 12,
      id: '12_offer_deep_link_page',
      title: 'OfferDeepLinkPage',
      builder: (_) => const app.OfferDeepLinkPage(
        offerId: 'demo-offer',
        preferMarketplace: true,
      ),
      note: 'Resolution deep link sur identifiant de demonstration.',
    ),
    PageCaptureEntry(
      number: 13,
      id: '13_legal_info_page',
      title: 'LegalInfoPage',
      builder: (_) => const LegalInfoPage(),
      note: 'Informations legales.',
    ),
    PageCaptureEntry(
      number: 14,
      id: '14_toolbox_hub_page',
      title: 'ToolboxHubPage',
      builder: (_) => const ToolboxHubPage(),
      note: 'Hub outils entrepreneur.',
    ),
    PageCaptureEntry(
      number: 15,
      id: '15_current_toolbox_page',
      title: 'CurrentToolboxPage',
      builder: (_) => const CurrentToolboxPage(),
      note: 'Parcours toolbox courant.',
    ),
    PageCaptureEntry(
      number: 16,
      id: '16_entrepreneur_calculator_page',
      title: 'EntrepreneurCalculatorPage',
      builder: (_) => const EntrepreneurCalculatorPage(),
      note: 'Calculatrice entrepreneur.',
    ),
    PageCaptureEntry(
      number: 17,
      id: '17_toolbox_je_me_lance_page',
      title: 'ToolboxJeMeLancePage',
      builder: (_) => const ToolboxJeMeLancePage(),
      note: 'Parcours Je me lance.',
    ),
    PageCaptureEntry(
      number: 18,
      id: '18_toolbox_page',
      title: 'ToolboxPage',
      builder: (_) => const ToolboxPage(),
      note: 'Ancienne page toolbox standalone.',
    ),
    PageCaptureEntry(
      number: 19,
      id: '19_entrepreneur_toolbox_page',
      title: 'EntrepreneurToolboxPage',
      builder: (_) => const EntrepreneurToolboxPage(),
      note: 'Alias toolbox entrepreneur.',
    ),
    PageCaptureEntry(
      number: 20,
      id: '20_pro_profile_page',
      title: 'ProProfilePage',
      builder: (_) => const ProProfilePage(),
      note: 'Creation profil pro.',
    ),
    PageCaptureEntry(
      number: 21,
      id: '21_admin_space_page',
      title: 'AdminSpacePage',
      builder: (_) => const AdminSpacePage(),
      note: 'Surface admin conditionnelle.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pageId = kIsWeb ? Uri.base.queryParameters['page'] : null;
    final entry = _entryForId(pageId);
    if (entry != null) {
      return _PageCaptureViewer(entry: entry);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catalogue des pages a capturer'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final item = entries[index];
          final route = '/page-catalog?page=${item.id}';
          return ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            title: Text('${item.number.toString().padLeft(2, '0')}. ${item.title}'),
            subtitle: Text(item.note ?? route),
            trailing: FilledButton(
              onPressed: () {
                Navigator.of(context).pushNamed(route);
              },
              child: const Text('Ouvrir'),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: entries.length,
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

class PageCaptureEntry {
  final int number;
  final String id;
  final String title;
  final WidgetBuilder builder;
  final String? note;

  const PageCaptureEntry({
    required this.number,
    required this.id,
    required this.title,
    required this.builder,
    this.note,
  });
}

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
                    onPressed: () => Navigator.of(context).pushReplacementNamed('/page-catalog'),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Text(
                          '${entry.number.toString().padLeft(2, '0')} - ${entry.title}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
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
    'advertiserName': 'Stephane Demo',
    'displayName': 'Stephane Demo',
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
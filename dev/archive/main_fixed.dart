// ignore_for_file: uri_does_not_exist

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_functions/cloud_functions.dart';

import 'firebase_options.dart';
import 'app_core.dart';
import 'constants.dart';
import 'utils/crashlytics_context.dart';
import 'utils/friendly_snackbar.dart';
import 'utils/recording_path.dart';
import 'features/micro_ia/micro_ia_service.dart';
import 'features/micro_ia/web_audio_recorder_stub.dart'
    if (dart.library.html) 'features/micro_ia/web_audio_recorder.dart';
import 'features/messaging/conversation_service.dart';
import 'widgets/premium_ai_button.dart';
import 'widgets/ad_banner.dart';
import 'widgets/offer_card.dart';
import 'widgets/phone_input_field.dart';
import 'widgets/entrepreneur_toolbox_slide.dart';
import 'pages/toolbox_hub_page.dart';
import 'services/city_search.dart';
import 'services/ai_draft_service.dart';
import 'services/notification_service.dart';
import 'services/google_auth_service.dart';
import 'pages/pro_profile_page.dart';
import 'pages/legal_info_page.dart';
import 'pages/admin_space_page.dart';
import 'dev/seed_offers.dart';

import 'app/theme.dart';

const kPrestoOrange = Color(0xFFFF6600);
const kPrestoBlue = Color(0xFF1A73E8);

/// ✅ Fonction utilitaire pour récupérer le statut de présence d'utilisateurs
Future<Map<String, dynamic>> getUserPresenceStatus(List<String> userIds) async {
  if (userIds.isEmpty) return {};

  try {
    final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
    final callable = functions.httpsCallable(
      'getUserPresenceStatus',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 10)),
    );

    final result = await callable.call<Map<String, dynamic>>({
      'userIds': userIds,
    });

    return result.data['statuses'] as Map<String, dynamic>? ?? {};
  } catch (e) {
    debugPrint('[Presence] Error fetching user status: $e');
    return {};
  }
}

/// ✅ Widget pour afficher l'indicateur de statut utilisateur
class UserStatusIndicator extends StatelessWidget {
  final String status; // 'online', 'away', 'offline'
  final double size;

  const UserStatusIndicator({
    super.key,
    required this.status,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'online':
        color = Colors.green;
        break;
      case 'away':
        color = Colors.orange;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

SystemUiOverlayStyle prestoOverlayStyleFor(Color backgroundColor) {
  final estimated = ThemeData.estimateBrightnessForColor(backgroundColor);
  final isDarkBackground = estimated == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: backgroundColor,
    statusBarIconBrightness:
        isDarkBackground ? Brightness.light : Brightness.dark,
    // iOS: Brightness.dark => icônes claires
    statusBarBrightness: isDarkBackground ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: backgroundColor,
    systemNavigationBarDividerColor: backgroundColor,
    systemNavigationBarIconBrightness:
        isDarkBackground ? Brightness.light : Brightness.dark,
  );
}

/// Villes + codes postaux (exemples Guadeloupe / Martinique)
const Map<String, String> kCityPostalMap = {
  // Guadeloupe
  'Baie-Mahault': '97122',
  'Les Abymes': '97139',
  'Pointe-à-Pitre': '97110',
  'Le Gosier': '97190',
  'Sainte-Anne': '97180',
  'Saint-François': '97118',
  'Petit-Bourg': '97170',
  'Lamentin': '97129',
  'Capesterre-Belle-Eau': '97130',
  'Basse-Terre': '97100',
  'Goyave': '97128',
  'Morne-à-l\'Eau': '97111',
  'Sainte-Rose': '97115',
  'Le Moule': '97160',
  'Saint-Claude': '97120',
  'Bouillante': '97125',
  'Deshaies': '97126',
  'Trois-Rivières': '97114',
  'Vieux-Habitants': '97119',
  'Vieux-Fort': '97141',
  'Anse-Bertrand': '97121',
  'Port-Louis': '97117',
  'Petit-Canal': '97131',
  'La Désirade': '97127',
  'Terre-de-Bas': '97136',
  'Terre-de-Haut': '97137',
  'Marie-Galante': '97140',
  // Martinique
  'Fort-de-France': '97200',
  'Le Lamentin': '97232',
  'Schoelcher': '97233',
  'Le Robert': '97231',
  'Le François': '97240',
  'Le Marin': '97290',
  'Les Trois-Îlets': '97229',
  'Sainte-Luce': '97228',
  'Sainte-Anne (MQ)': '97227',
  'La Trinité': '97220',
  'Le Lorrain': '97214',
  'Le Carbet': '97221',
  'Le Diamant': '97223',
  'Saint-Esprit': '97270',
};

// [Reste de main.dart avant _OfferDetailPageState, lignes 1-4494]
// Ce fichier contient les imports, constantes et helpers.
// Les lignes 4495-4558 (malformées) ont été supprimées.
// Les lignes 4559-10895 (correctes) sont ajoutées ci-après.

// À copier depuis main.dart (lignes 1-4494) - tout jusqu'à juste avant la section malformée
// Puis ajouter le contenu suivant:

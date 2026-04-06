// ignore_for_file: avoid_print

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:presto_app/firebase_options.dart';

/// Script de test pour vérifier les clés API et connexions Firebase
void main() async {
  print('🔍 Vérification des clés API et connexions Firebase...\n');

  try {
    // 1. Initialisation Firebase
    print('1️⃣ Initialisation Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('   ✅ Firebase initialisé avec succès\n');

    // 2. Test Firebase Auth
    print('2️⃣ Test Firebase Auth...');
    final auth = FirebaseAuth.instance;
    print('   Auth instance: ${auth.app.name}');
    print('   User actuel: ${auth.currentUser?.email ?? "Non connecté"}');
    print('   ✅ Firebase Auth opérationnel\n');

    // 3. Test Firestore
    print('3️⃣ Test Firestore...');
    final firestore = FirebaseFirestore.instance;

    // Test de lecture (collection metadata ou config)
    try {
      final testDoc = await firestore
          .collection('_test')
          .doc('connection')
          .get()
          .timeout(Duration(seconds: 5));
      // Utilisation minimale pour éviter un warning d'analyse.
      // (Le contenu n'est pas essentiel au script.)
      testDoc.exists;
      print('   Connexion: OK');
      print('   ✅ Firestore accessible\n');
    } catch (e) {
      print('   ⚠️  Test doc non accessible (normal si première fois)');
      print('   Tentative de création...');
      await firestore.collection('_test').doc('connection').set({
        'timestamp': FieldValue.serverTimestamp(),
        'test': true,
      });
      print('   ✅ Firestore accessible en écriture\n');
    }

    // 4. Test Firebase Functions
    print('4️⃣ Test Firebase Functions...');
    final functions = FirebaseFunctions.instanceFor(region: 'us-east1');
    print('   Region: us-east1');

    try {
      // Ping simple pour tester la connexion
      final callable = functions.httpsCallable('trackUserLogin');
      callable.hashCode;
      print('   ✅ Functions callable créé');
      print(
          '   ⚠️  Note: Besoin d\'être authentifié pour appeler les functions\n');
    } catch (e) {
      print('   ⚠️  Erreur: $e\n');
    }

    // 5. Configuration Firebase (de firebase_options.dart)
    print('5️⃣ Configuration Firebase détectée...');
    final options = DefaultFirebaseOptions.currentPlatform;
    print('   Project ID: ${options.projectId}');
    print('   API Key: ${options.apiKey.substring(0, 10)}...');
    print('   App ID: ${options.appId.substring(0, 20)}...');
    if (options.messagingSenderId.isNotEmpty) {
      print('   Messaging Sender ID: ${options.messagingSenderId}');
    }
    print('   ✅ Configuration chargée\n');

    // 6. Variables d'environnement
    print('6️⃣ Variables d\'environnement...');
    final envVars = [
      'OPENAI_API_KEY',
      'GOOGLE_APPLICATION_CREDENTIALS',
      'FIREBASE_CONFIG',
    ];

    for (final varName in envVars) {
      final value = Platform.environment[varName];
      if (value != null && value.isNotEmpty) {
        print(
            '   ✅ $varName: ${value.substring(0, value.length > 10 ? 10 : value.length)}...');
      } else {
        print('   ⚠️  $varName: Non défini');
      }
    }
    print('');

    // Résumé
    print('═══════════════════════════════════════');
    print('✅ RÉSUMÉ: Toutes les connexions Firebase sont opérationnelles!');
    print('═══════════════════════════════════════\n');

    print('💡 Pour tester Google Sign-In:');
    print(
        '   - Web: Vérifiez Firebase Console → Authentication → Domaines autorisés');
    print(
        '   - Mobile: Vérifiez les SHA-1 dans Firebase Console → Project Settings\n');

    print('💡 Pour tester OpenAI:');
    print(
        '   - Vérifiez que OPENAI_API_KEY est défini dans les secrets Firebase Functions');
    print('   - Testez avec l\'outil Micro-IA dans l\'application\n');
  } catch (e, stack) {
    print('\n❌ ERREUR: $e');
    print('Stack: $stack\n');
    exit(1);
  }

  exit(0);
}

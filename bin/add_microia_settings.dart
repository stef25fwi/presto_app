import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  try {
    print('Creating document: settings/microia...');
    
    await FirebaseFirestore.instance
        .collection('settings')
        .doc('microia')
        .set({
          'mode': 'HYBRID',
          'fallbackEnabled': true,
          'qualityThreshold': 0.62,
          'languageCode': 'fr-FR',
        });
    
    print('✓ Document created successfully!');
  } catch (e) {
    print('✗ Error: $e');
    rethrow;
  }
}

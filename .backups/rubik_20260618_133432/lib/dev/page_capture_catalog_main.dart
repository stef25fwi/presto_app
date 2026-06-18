import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../firebase_init.dart';
import 'page_capture_catalog_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensureFirebaseInitialized(source: 'page_capture_catalog');
  runApp(const _PageCaptureCatalogApp());
}

class _PageCaptureCatalogApp extends StatelessWidget {
  const _PageCaptureCatalogApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Page Capture Catalog',
      debugShowCheckedModeBanner: false,
      theme: buildPrestoTheme(),
      routes: {
        '/page-catalog': (_) => const PageCaptureCatalogPage(),
      },
      home: const PageCaptureCatalogPage(),
    );
  }
}
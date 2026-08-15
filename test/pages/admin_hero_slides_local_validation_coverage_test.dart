// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_storage_platform_interface/firebase_storage_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_hero_slides_page.dart';

class _HeroValidationFilePickerPlatform extends FilePickerPlatform {
  FilePickerResult? nextResult;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    return nextResult;
  }
}

class _HeroValidationStoragePlatform extends FirebaseStoragePlatform {
  _HeroValidationStoragePlatform() : super(bucket: 'presto-test.appspot.com');

  @override
  FirebaseStoragePlatform delegateFor({
    required FirebaseApp app,
    required String bucket,
  }) => this;

  @override
  int get maxDownloadRetryTime => 0;

  @override
  int get maxOperationRetryTime => 0;

  @override
  int get maxUploadRetryTime => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FilePickerPlatform originalFilePickerPlatform;
  late FirebaseStoragePlatform originalStoragePlatform;
  late _HeroValidationFilePickerPlatform filePickerPlatform;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          appId: '1:1234567890:web:admin-hero-local-validation',
          messagingSenderId: '1234567890',
          projectId: 'presto-test',
          storageBucket: 'presto-test.appspot.com',
        ),
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
    originalFilePickerPlatform = FilePickerPlatform.instance;
    originalStoragePlatform = FirebaseStoragePlatform.instance;
  });

  setUp(() {
    filePickerPlatform = _HeroValidationFilePickerPlatform();
    FilePickerPlatform.instance = filePickerPlatform;
    FirebaseStoragePlatform.instance = _HeroValidationStoragePlatform();
  });

  tearDown(() {
    FilePickerPlatform.instance = originalFilePickerPlatform;
    FirebaseStoragePlatform.instance = originalStoragePlatform;
  });

  Future<void> pumpAdminHero(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: AdminHeroSlidesPage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> openEditor(WidgetTester tester) async {
    final add = find.byTooltip('Ajouter un slide');
    expect(add, findsOneWidget);
    await tester.tap(add);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Ajouter un slide Hero'), findsOneWidget);
  }

  Future<void> chooseMedia(WidgetTester tester) async {
    final choose = find.text('Choisir une image ou une vidéo');
    expect(choose, findsOneWidget);
    await tester.ensureVisible(choose);
    await tester.tap(choose);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('rejette localement un fichier image vide', (tester) async {
    await pumpAdminHero(tester);
    await openEditor(tester);

    filePickerPlatform.nextResult = FilePickerResult(<PlatformFile>[
      PlatformFile(
        name: 'hero-vide.png',
        size: 0,
        bytes: Uint8List(0),
      ),
    ]);

    await chooseMedia(tester);

    expect(
      find.text('Le fichier sélectionné est vide. Choisissez un autre média.'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('rejette localement un format HEIC non supporté', (tester) async {
    await pumpAdminHero(tester);
    await openEditor(tester);

    filePickerPlatform.nextResult = FilePickerResult(<PlatformFile>[
      PlatformFile(
        name: 'photo-iphone.heic',
        size: 3,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
      ),
    ]);

    await chooseMedia(tester);

    expect(find.textContaining('Format non supporté'), findsWidgets);
    expect(find.textContaining('HEIC/HEIF'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'image valide couvre durée ordre et réglages locaux avant backend',
      (tester) async {
    await pumpAdminHero(tester);
    await openEditor(tester);

    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Y9Z0gAAAABJRU5ErkJggg==',
    );
    filePickerPlatform.nextResult = FilePickerResult(<PlatformFile>[
      PlatformFile(
        name: 'hero-validation.png',
        size: pngBytes.length,
        bytes: pngBytes,
      ),
    ]);

    await chooseMedia(tester);
    expect(find.text('hero-validation.png'), findsWidgets);

    final duration = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Durée (secondes)',
    );
    final order = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Ordre',
    );
    final save = find.text('Enregistrer le slide');

    expect(duration, findsOneWidget);
    expect(order, findsOneWidget);
    expect(save, findsOneWidget);

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(2));
    tester.widget<SwitchListTile>(switches.at(0)).onChanged?.call(false);
    tester.widget<SwitchListTile>(switches.at(1)).onChanged?.call(true);
    await tester.pump();

    await tester.enterText(duration, '2');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(
      find.text('La durée doit être comprise entre 3 et 60 secondes.'),
      findsOneWidget,
    );

    await tester.enterText(duration, '5');
    await tester.enterText(order, '-1');
    await tester.tap(save);
    await tester.pump();
    expect(find.text("L'ordre doit être positif."), findsOneWidget);

    await tester.enterText(order, '0');
    expect(tester.takeException(), isNull);
  });
}

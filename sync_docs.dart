import 'dart:io';

void main() async {
  final buildWebDir = Directory('build/web');
  final docsDir = Directory('docs');

  // Supprimer docs/ et le recréer
  if (docsDir.existsSync()) {
    docsDir.deleteSync(recursive: true);
    print('✅ Répertoire docs/ supprimé');
  }

  docsDir.createSync(recursive: true);
  print('✅ Répertoire docs/ créé');

  // Copier tous les fichiers de build/web vers docs/
  await _copyDirectory(buildWebDir, docsDir);
  print('✅ Fichiers copiés de build/web vers docs/');

  // Lister les fichiers
  print('\n📁 Fichiers dans docs/:');
  final files = docsDir.listSync(recursive: true);
  for (var file in files.take(20)) {
    if (file is File) {
      print('  - ${file.path}');
    }
  }
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await for (var entity in source.list(recursive: false, followLinks: false)) {
    final basename = entity.path.split(Platform.pathSeparator).last;
    final targetPath = '${destination.path}/$basename';
    if (entity is Directory) {
      await Directory(targetPath).create(recursive: true);
      await _copyDirectory(entity, Directory(targetPath));
    } else if (entity is File) {
      await entity.copy(targetPath);
    }
  }
}

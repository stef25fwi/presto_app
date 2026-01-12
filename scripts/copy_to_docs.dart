import 'dart:io';

void main() async {
  final sourceDir = Directory('/workspaces/presto_app/build/web');
  final destDir = Directory('/workspaces/presto_app/docs');

  // Créer le répertoire docs s'il n'existe pas
  if (!destDir.existsSync()) {
    destDir.createSync(recursive: true);
  }

  // Fichiers individuels à copier
  final filesToCopy = ['main.dart.js', 'manifest.json', 'version.json'];

  for (final fileName in filesToCopy) {
    final sourceFile = File('${sourceDir.path}/$fileName');
    final destFile = File('${destDir.path}/$fileName');

    if (sourceFile.existsSync()) {
      stdout.writeln('Copie: $fileName');
      sourceFile.copySync(destFile.path);
    } else {
      stdout.writeln('⚠️  Fichier non trouvé: ${sourceFile.path}');
    }
  }

  // Répertoires à copier
  final dirsToCopy = ['icons', 'assets'];

  for (final dirName in dirsToCopy) {
    final sourceSubDir = Directory('${sourceDir.path}/$dirName');
    final destSubDir = Directory('${destDir.path}/$dirName');

    if (sourceSubDir.existsSync()) {
      stdout.writeln('Copie du répertoire: $dirName');
      if (destSubDir.existsSync()) {
        destSubDir.deleteSync(recursive: true);
      }
      _copyDirectory(sourceSubDir, destSubDir);
    } else {
      stdout.writeln('⚠️  Répertoire non trouvé: ${sourceSubDir.path}');
    }
  }

  // Créer .nojekyll
  final noJekyllFile = File('${destDir.path}/.nojekyll');
  stdout.writeln('Création: .nojekyll');
  noJekyllFile.writeAsStringSync('');

  // Créer 404.html pour GitHub Pages
  final html404Content = '''<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Presto App</title>
    <script>
        var pathparts = location.pathname.split('/');
        var i = pathparts.length - 1;
        while (i >= 0) {
            if (pathparts[i] !== '') {
                pathparts.splice(i + 1, pathparts.length - i - 1);
                location.replace(pathparts.join('/') + '/?p=' + location.pathname.slice(1).replace(/\\//g, '~') + location.search);
                return;
            }
            i--;
        }
    </script>
</head>
<body></body>
</html>
''';

  final file404 = File('${destDir.path}/404.html');
  stdout.writeln('Création: 404.html');
  file404.writeAsStringSync(html404Content);

  stdout.writeln('\n✅ Copie terminée!');
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);

  source.listSync(recursive: false).forEach((entity) {
    final isDir = entity is Directory;
    final basename = entity.path.split('/').last;
    final targetPath = '${destination.path}/$basename';

    if (isDir) {
      _copyDirectory(Directory(entity.path), Directory(targetPath));
    } else {
      File(entity.path).copySync(targetPath);
    }
  });
}

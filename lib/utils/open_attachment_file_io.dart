import 'package:open_filex/open_filex.dart';

Future<bool> openAttachmentFile(String path) async {
  try {
    await OpenFilex.open(path);
    return true;
  } catch (_) {
    return false;
  }
}

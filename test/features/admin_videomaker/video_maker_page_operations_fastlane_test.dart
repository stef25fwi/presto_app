import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/features/admin_videomaker/video_maker_page_operations.dart';

void main() {
  test('selected image preserves bytes, name and MIME type', () {
    final bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final image = VideoMakerSelectedImage(
      bytes: bytes,
      name: 'reference.webp',
      mimeType: 'image/webp',
    );

    expect(image.bytes, same(bytes));
    expect(image.bytes, <int>[1, 2, 3, 4]);
    expect(image.name, 'reference.webp');
    expect(image.mimeType, 'image/webp');
  });
}

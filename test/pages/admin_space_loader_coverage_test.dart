import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:presto_app/pages/admin_space_loader.dart';

void main() {
  test('construit le point d entrée stable de l espace admin', () {
    final key = UniqueKey();
    final loader = AdminSpaceLoader(key: key);

    expect(loader.key, same(key));
    expect(loader.createElement(), isA<StatelessElement>());
  });
}

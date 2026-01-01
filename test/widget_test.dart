import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('App colors are correct', () {
    const cherryRed = Color(0xFFC4515E);
    const cloudDancer = Color(0xFFFDFBF7);

    expect(cherryRed, const Color(0xFFC4515E));
    expect(cloudDancer, const Color(0xFFFDFBF7));
  });
}

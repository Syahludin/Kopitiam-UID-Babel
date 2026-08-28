import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Apps Script request posts once then fetches ContentService with GET', () {
    final source = File('lib/services/api_service.dart').readAsStringSync();
    expect(source, contains("http.Request('POST', initialUri)"));
    expect(source, contains("http.Request('GET', contentUri)"));
    expect(source, contains("contentUri.host != _contentHost"));
    expect(source, isNot(contains("http.Request('POST', current)")));
  });

  test('credentials are not copied into the ContentService GET request', () {
    final source = File('lib/services/api_service.dart').readAsStringSync();
    final getStart = source.indexOf("final contentRequest = http.Request('GET'");
    final getEnd = source.indexOf('final contentStream', getStart);
    expect(getStart, greaterThanOrEqualTo(0));
    expect(getEnd, greaterThan(getStart));
    final getBlock = source.substring(getStart, getEnd);
    expect(getBlock, isNot(contains('payload')));
    expect(getBlock, isNot(contains('body =')));
    expect(getBlock, isNot(contains('Authorization')));
  });
}

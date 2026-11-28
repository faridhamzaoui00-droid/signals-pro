import 'package:flutter_test/flutter_test.dart';
import 'package:signals_pro/ind/custom_runner.dart';

void main() {
  test('المشغّل الحي يُترجم، وحالته الابتدائية فارغة ولا يعمل قبل load()', () {
    expect(CustomRunner.I.list, isEmpty);
    expect(CustomRunner.I.status, isEmpty);
  });
}

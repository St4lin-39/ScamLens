import 'package:flutter_test/flutter_test.dart';
import 'package:scamlens/shared/brand_impersonation/domain/services/levenshtein_calculator.dart';

void main() {
  const calculator = LevenshteinCalculator();

  group('LevenshteinCalculator', () {
    test('returns 0 for identical strings ignoring case', () {
      expect(calculator.distance('bancolombia', 'bancolombia'), 0);
      expect(calculator.distance('Bancolombia.COM', 'bancolombia.com'), 0);
      expect(calculator.distance('', ''), 0);
    });

    test('handles empty strings and symmetry', () {
      expect(calculator.distance('', 'nequi'), 5);
      expect(calculator.distance('nequi', ''), 5);
      expect(
        calculator.distance('banc0-bogota', 'bancodebogota'),
        calculator.distance('bancodebogota', 'banc0-bogota'),
      );
    });

    test('computes exact edit distances for common typosquatting patterns', () {
      // 1 sustitucion: o -> 0
      expect(calculator.distance('bancol0mbia', 'bancolombia'), 1);
      // 2 sustituciones: o -> 0, o -> 0
      expect(calculator.distance('g00gle', 'google'), 2);
      // 3 ediciones: o -> 0, d -> -, eliminar e
      expect(calculator.distance('banc0-bogota', 'bancodebogota'), 3);
      // 1 eliminacion (omision de letra)
      expect(calculator.distance('davivinda', 'davivienda'), 1);
      // 1 insercion (doble letra)
      expect(calculator.distance('servientregaa', 'servientrega'), 1);
    });

    test('counts Unicode runes properly instead of UTF-16 code units', () {
      expect(calculator.distance('bogotá', 'bogota'), 1);
      expect(calculator.distance('🔒seguro', 'seguro'), 1);
    });
  });
}

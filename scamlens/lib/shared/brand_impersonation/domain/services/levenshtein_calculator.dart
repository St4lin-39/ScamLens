import 'dart:math' as math;

class LevenshteinCalculator {
  const LevenshteinCalculator();

  int distance(String source, String target) {
    final a = source.toLowerCase();
    final b = target.toLowerCase();
    if (a == b) return 0;
    if (a.isEmpty) return b.runes.length;
    if (b.isEmpty) return a.runes.length;

    var sRunes = a.runes.toList(growable: false);
    var tRunes = b.runes.toList(growable: false);

    if (sRunes.length > tRunes.length) {
      final temp = sRunes;
      sRunes = tRunes;
      tRunes = temp;
    }

    final m = sRunes.length;
    final n = tRunes.length;

    var previousRow = List<int>.generate(m + 1, (i) => i, growable: false);
    var currentRow = List<int>.filled(m + 1, 0, growable: false);

    for (var j = 1; j <= n; j++) {
      currentRow[0] = j;
      for (var i = 1; i <= m; i++) {
        final substitutionCost = sRunes[i - 1] == tRunes[j - 1] ? 0 : 1;
        final deletion = previousRow[i] + 1;
        final insertion = currentRow[i - 1] + 1;
        final substitution = previousRow[i - 1] + substitutionCost;

        currentRow[i] = math.min(deletion, math.min(insertion, substitution));
      }
      final swap = previousRow;
      previousRow = currentRow;
      currentRow = swap;
    }

    return previousRow[m];
  }
}

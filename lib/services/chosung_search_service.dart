/// Korean Hangul Chosung (Initial Consonant) & Multi-field Smart Search Service
/// Allows instant search by:
/// 1) Korean Chosung: 'ㅇㄷㅎ' -> '이도현', 'ㅂㅁㅈ' -> '박민지'
/// 2) Partial Name: '도현' -> '이도현'
/// 3) Phone trailing digits: '9012' -> '01055219012'
/// 4) Group tag or English: 'pt', 'math' -> 'PT 화목반'
class ChosungSearchService {
  ChosungSearchService._();

  static const List<String> _chosungList = [
    'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
    'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'
  ];

  /// Extracts Korean initial consonants from given string
  /// e.g. "이도현 (중2 수학반)" -> "ㅇㄷㅎ (ㅈ2 ㅅㅎㅂ)"
  static String extractChosung(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Hangul syllable range: 0xAC00 (가) ~ 0xD7A3 (힣)
      if (code >= 0xAC00 && code <= 0xD7A3) {
        final chosungIndex = (code - 0xAC00) ~/ (21 * 28);
        buffer.write(_chosungList[chosungIndex]);
      } else {
        buffer.writeCharCode(code);
      }
    }
    return buffer.toString();
  }

  /// Determines if a character is a single Hangul Chosung (ㄱ ~ ㅎ)
  static bool isChosungOnly(String query) {
    if (query.isEmpty) return false;
    for (int i = 0; i < query.length; i++) {
      final code = query.codeUnitAt(i);
      // Hangul Compatibility Jamo Chosung range: 0x3131 (ㄱ) ~ 0x314E (ㅎ)
      final isJamo = (code >= 0x3131 && code <= 0x314E);
      final isSpace = (code == 0x0020);
      if (!isJamo && !isSpace) return false;
    }
    return true;
  }

  /// Checks if [target] matches the search [query].
  /// Matches via:
  /// - Direct substring (case-insensitive)
  /// - Chosung substring (e.g. query "ㅇㄷㅎ" matches "이도현")
  /// - Normalized phone match (e.g. query "9012" matches "010-5521-9012")
  static bool matches(String target, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return true;

    final cleanTarget = target.toLowerCase();

    // 1. Exact substring match
    if (cleanTarget.contains(cleanQuery)) {
      return true;
    }

    // 2. Normalized phone/number match (stripping spaces, hyphens)
    final digitsOnlyTarget = cleanTarget.replaceAll(RegExp(r'\D'), '');
    final digitsOnlyQuery = cleanQuery.replaceAll(RegExp(r'\D'), '');
    if (digitsOnlyQuery.isNotEmpty && digitsOnlyTarget.contains(digitsOnlyQuery)) {
      return true;
    }

    // 3. Chosung match
    final targetChosung = extractChosung(cleanTarget);
    if (targetChosung.contains(cleanQuery)) {
      return true;
    }

    return false;
  }

  /// Checks if any of the candidate fields match the query
  static bool matchesAny(List<String?> fields, String query) {
    if (query.trim().isEmpty) return true;
    for (final field in fields) {
      if (field != null && matches(field, query)) {
        return true;
      }
    }
    return false;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:zeropass/services/chosung_search_service.dart';
import 'package:zeropass/services/starter_preset_service.dart';

void main() {
  group('ChosungSearchService Tests', () {
    test('extractChosung accurately extracts initial consonants from Hangul syllables', () {
      expect(ChosungSearchService.extractChosung('이도현'), equals('ㅇㄷㅎ'));
      expect(ChosungSearchService.extractChosung('박민지'), equals('ㅂㅁㅈ'));
      expect(ChosungSearchService.extractChosung('기구 필라테스'), equals('ㄱㄱ ㅍㄹㅌㅅ'));
      expect(ChosungSearchService.extractChosung('1:1 VIP PT'), equals('1:1 VIP PT'));
    });

    test('isChosungOnly checks if string consists solely of Hangul compatibility jamo and spaces', () {
      expect(ChosungSearchService.isChosungOnly('ㅇㄷㅎ'), isTrue);
      expect(ChosungSearchService.isChosungOnly('ㅂㅁㅈ ㄱㄱ'), isTrue);
      expect(ChosungSearchService.isChosungOnly('이도현'), isFalse);
      expect(ChosungSearchService.isChosungOnly('pt'), isFalse);
    });

    test('matches correctly matches by exact substring, chosung, and trailing phone digits', () {
      // 1. Exact substring
      expect(ChosungSearchService.matches('이도현 (중2 수학반)', '도현'), isTrue);
      expect(ChosungSearchService.matches('이도현 (중2 수학반)', '수학'), isTrue);

      // 2. Chosung match
      expect(ChosungSearchService.matches('이도현 (중2 수학반)', 'ㅇㄷㅎ'), isTrue);
      expect(ChosungSearchService.matches('박민지 (1:1 필라테스)', 'ㅂㅁㅈ'), isTrue);
      expect(ChosungSearchService.matches('박민지 (1:1 필라테스)', 'ㅍㄹㅌㅅ'), isTrue);

      // 3. Trailing phone match
      expect(ChosungSearchService.matches('01055219012', '9012'), isTrue);
      expect(ChosungSearchService.matches('010-5521-9012', '9012'), isTrue);

      // 4. Negative cases
      expect(ChosungSearchService.matches('이도현', 'ㄱㄷㅎ'), isFalse);
      expect(ChosungSearchService.matches('01055219012', '8888'), isFalse);
    });

    test('matchesAny checks multiple fields (name, phone, group, payer, memo)', () {
      final fields = ['이도현 (학생)', '01055219012', '중등수학 정규반', '이진호(학부모)', '오답노트 관리'];

      // Match via name chosung
      expect(ChosungSearchService.matchesAny(fields, 'ㅇㄷㅎ'), isTrue);
      // Match via phone tail
      expect(ChosungSearchService.matchesAny(fields, '9012'), isTrue);
      // Match via group
      expect(ChosungSearchService.matchesAny(fields, '중등수학'), isTrue);
      // Match via payer
      expect(ChosungSearchService.matchesAny(fields, '이진호'), isTrue);
      // Match via memo
      expect(ChosungSearchService.matchesAny(fields, '오답'), isTrue);
      // No match
      expect(ChosungSearchService.matchesAny(fields, '필라테스'), isFalse);
    });
  });

  group('StarterPresetService Enum Tests', () {
    test('Verifies all 5 core industry presets exist with authentic metadata', () {
      expect(IndustryPreset.values.length, equals(5));
      expect(IndustryPreset.academy.category, equals('입시 / 보습학원'));
      expect(IndustryPreset.fitness.category, equals('피트니스 / PT'));
      expect(IndustryPreset.pilates.category, equals('필라테스 / 요가'));
      expect(IndustryPreset.taekwondo.category, equals('태권도 / 무술'));
      expect(IndustryPreset.artMusic.category, equals('음악 / 피아노'));
    });
  });
}

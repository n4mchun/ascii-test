/// 보이스피싱 탐지 서비스
/// 키워드 기반으로 보이스피싱 의심 여부를 판단합니다.
class PhishingDetectionService {
  static final PhishingDetectionService instance = PhishingDetectionService._init();

  PhishingDetectionService._init();

  // 보이스피싱 의심 키워드 목록
  final List<String> _phishingKeywords = [
    // 공공기관
    '금융감독원', '검찰청', '경찰청', '국세청', '대검찰청',
    '금감원', '국세청 직원', '경찰관',

    // 금융 관련
    '보안카드', '계좌번호', '비밀번호', '인증번호', 'OTP',
    '송금', '이체', '출금', '입금', '현금',
    '안전계좌', '보호계좌', '보안계좌', '대포통장',
    '대출', '저금리', '한도', '승인', '대출금',

    // 수사/범죄 관련
    '수사', '조사', '혐의', '범죄', '사건',
    '피해자', '가해자', '명의도용', '체포', '구속',
    '영장', '소환', '출두',

    // 세금 관련
    '환불', '세금', '환급', '체납', '국세',

    // 가족 사칭
    '가족', '자녀', '아들', '딸', '엄마', '아빠',
    '납치', '사고', '교통사고', '병원', '응급실',

    // 통신/결제
    '휴대폰', '소액결제', '결제내역', '요금',
    '개통', '명의', '가입',

    // 기타 의심 키워드
    '대포폰', '메신저', '텔레그램', '위챗',
    '비대면', '원격', '화면공유', '앱 설치',
  ];

  // 보이스피싱 탐지 임계값
  final int _phishingThreshold = 3;

  /// 텍스트에서 보이스피싱 키워드 분석
  ///
  /// Returns: 발견된 키워드 개수
  int detectKeywords(String text) {
    if (text.isEmpty) return 0;

    int keywordCount = 0;
    String lowerText = text.toLowerCase();

    for (String keyword in _phishingKeywords) {
      // 키워드가 텍스트에 포함된 횟수를 카운트
      keywordCount += keyword.toLowerCase().allMatches(lowerText).length;
    }

    return keywordCount;
  }

  /// 보이스피싱 의심 여부 판단
  ///
  /// Returns: true if phishing suspected, false otherwise
  bool isPhishingSuspected(int keywordCount) {
    return keywordCount >= _phishingThreshold;
  }

  /// 텍스트 분석 및 의심 여부 판단 (원스톱 메서드)
  ///
  /// Returns: Map with 'keywordCount' and 'isPhishing'
  Map<String, dynamic> analyzeText(String text) {
    final keywordCount = detectKeywords(text);
    final isPhishing = isPhishingSuspected(keywordCount);

    return {
      'keywordCount': keywordCount,
      'isPhishing': isPhishing,
    };
  }

  /// 발견된 키워드 목록 반환 (디버깅/상세 정보용)
  List<String> getDetectedKeywords(String text) {
    if (text.isEmpty) return [];

    List<String> detectedKeywords = [];
    String lowerText = text.toLowerCase();

    for (String keyword in _phishingKeywords) {
      if (lowerText.contains(keyword.toLowerCase())) {
        detectedKeywords.add(keyword);
      }
    }

    return detectedKeywords;
  }

  /// 전체 키워드 목록 반환 (설정 화면 등에서 사용)
  List<String> getAllKeywords() {
    return List.unmodifiable(_phishingKeywords);
  }

  /// 임계값 반환
  int getThreshold() {
    return _phishingThreshold;
  }
}

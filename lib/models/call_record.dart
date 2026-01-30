// 통화 기록 모델
class CallRecord {
  final int? id;
  final String phoneNumber;
  final String fileName;
  final String filePath;
  final DateTime analyzedAt;
  final String? transcriptionText;
  final String riskLevel; // 'safe', 'warning', 'danger'
  final int keywordCount;
  final bool isPhishing; // true면 보이스피싱 의심

  CallRecord({
    this.id,
    required this.phoneNumber,
    required this.fileName,
    required this.filePath,
    required this.analyzedAt,
    this.transcriptionText,
    required this.riskLevel,
    required this.keywordCount,
    required this.isPhishing,
  });

  // DB에서 불러올 때 사용
  factory CallRecord.fromMap(Map<String, dynamic> map) {
    return CallRecord(
      id: map['id'] as int?,
      phoneNumber: map['phone_number'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      analyzedAt: DateTime.parse(map['analyzed_at'] as String),
      transcriptionText: map['transcription_text'] as String?,
      riskLevel: map['risk_level'] as String,
      keywordCount: map['keyword_count'] as int,
      isPhishing: (map['is_phishing'] as int) == 1,
    );
  }

  // DB에 저장할 때 사용
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'file_name': fileName,
      'file_path': filePath,
      'analyzed_at': analyzedAt.toIso8601String(),
      'transcription_text': transcriptionText,
      'risk_level': riskLevel,
      'keyword_count': keywordCount,
      'is_phishing': isPhishing ? 1 : 0,
    };
  }

  // 복사본 생성 (수정 시 사용)
  CallRecord copyWith({
    int? id,
    String? phoneNumber,
    String? fileName,
    String? filePath,
    DateTime? analyzedAt,
    String? transcriptionText,
    String? riskLevel,
    int? keywordCount,
    bool? isPhishing,
  }) {
    return CallRecord(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      transcriptionText: transcriptionText ?? this.transcriptionText,
      riskLevel: riskLevel ?? this.riskLevel,
      keywordCount: keywordCount ?? this.keywordCount,
      isPhishing: isPhishing ?? this.isPhishing,
    );
  }
}

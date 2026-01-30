/// SMS 메시지 레코드 모델
class SmsRecord {
  final int? id;
  final String phoneNumber;
  final String fileName;
  final String filePath;
  final DateTime analyzedAt;
  final String messageContent;
  final String riskLevel; // 'safe', 'warning', 'danger'
  final int keywordCount;
  final bool isPhishing;

  SmsRecord({
    this.id,
    required this.phoneNumber,
    required this.fileName,
    required this.filePath,
    required this.analyzedAt,
    required this.messageContent,
    required this.riskLevel,
    required this.keywordCount,
    required this.isPhishing,
  });

  /// Database에서 가져온 Map을 SmsRecord 객체로 변환
  factory SmsRecord.fromMap(Map<String, dynamic> map) {
    return SmsRecord(
      id: map['id'] as int?,
      phoneNumber: map['phone_number'] as String,
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String,
      analyzedAt: DateTime.parse(map['analyzed_at'] as String),
      messageContent: map['message_content'] as String,
      riskLevel: map['risk_level'] as String,
      keywordCount: map['keyword_count'] as int,
      isPhishing: (map['is_phishing'] as int) == 1,
    );
  }

  /// SmsRecord 객체를 Database에 저장할 Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'file_name': fileName,
      'file_path': filePath,
      'analyzed_at': analyzedAt.toIso8601String(),
      'message_content': messageContent,
      'risk_level': riskLevel,
      'keyword_count': keywordCount,
      'is_phishing': isPhishing ? 1 : 0,
    };
  }

  /// 복사본 생성 (필드 일부를 변경할 때 사용)
  SmsRecord copyWith({
    int? id,
    String? phoneNumber,
    String? fileName,
    String? filePath,
    DateTime? analyzedAt,
    String? messageContent,
    String? riskLevel,
    int? keywordCount,
    bool? isPhishing,
  }) {
    return SmsRecord(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      messageContent: messageContent ?? this.messageContent,
      riskLevel: riskLevel ?? this.riskLevel,
      keywordCount: keywordCount ?? this.keywordCount,
      isPhishing: isPhishing ?? this.isPhishing,
    );
  }
}

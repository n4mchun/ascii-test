import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/call_record.dart';

class RecordDetailScreen extends StatelessWidget {
  final CallRecord record;

  const RecordDetailScreen({
    super.key,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm:ss');
    final isPhishing = record.isPhishing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('통화 분석 상세'),
        backgroundColor: isPhishing ? Colors.red.shade700 : Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 헤더
            _buildStatusHeader(context, isPhishing),

            // 기본 정보
            _buildSection(
              '📞 기본 정보',
              [
                _buildInfoRow('전화번호', record.phoneNumber, Icons.phone),
                _buildInfoRow('분석 일시', dateFormat.format(record.analyzedAt), Icons.calendar_today),
                _buildInfoRow('파일명', record.fileName, Icons.insert_drive_file),
                _buildInfoRow('위험도', isPhishing ? '위험' : '안전',
                  isPhishing ? Icons.warning : Icons.check_circle,
                  valueColor: isPhishing ? Colors.red : Colors.green),
                if (isPhishing)
                  _buildInfoRow('발견된 키워드', '${record.keywordCount}개', Icons.error_outline,
                    valueColor: Colors.red),
              ],
            ),

            // 통화 내용
            _buildSection(
              '📝 통화 내용',
              [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    record.transcriptionText ?? '변환된 텍스트가 없습니다.',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),

            // 보이스피싱 의심 시 대처 방법
            if (isPhishing) ...[
              _buildSection(
                '🚨 즉시 조치하세요!',
                [
                  _buildWarningCard(
                    '1. 경찰청 통합신고센터 신고',
                    '112번으로 즉시 신고하세요',
                    Icons.local_police,
                    Colors.red,
                  ),
                  const SizedBox(height: 8),
                  _buildWarningCard(
                    '2. 금융감독원 신고',
                    '1332번으로 금융 피해 차단을 요청하세요',
                    Icons.account_balance,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  _buildWarningCard(
                    '3. 악성 앱 확인',
                    '휴대폰에서 의심스러운 앱을 삭제하세요',
                    Icons.phone_android,
                    Colors.amber,
                  ),
                ],
              ),
            ],

            // 안전한 통화 안내
            if (!isPhishing) ...[
              _buildSection(
                '✅ 안전한 통화',
                [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade700, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '이 통화는 안전합니다',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '보이스피싱 의심 키워드가 발견되지 않았습니다.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, bool isPhishing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isPhishing ? Colors.red.shade50 : Colors.green.shade50,
        border: Border(
          bottom: BorderSide(
            color: isPhishing ? Colors.red.shade300 : Colors.green.shade300,
            width: 2,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            isPhishing ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 60,
            color: isPhishing ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(height: 12),
          Text(
            isPhishing ? '⚠️ 보이스피싱 의심' : '✅ 안전한 통화',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isPhishing ? Colors.red.shade900 : Colors.green.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPhishing
                ? '의심스러운 키워드가 발견되었습니다'
                : '위험 요소가 발견되지 않았습니다',
            style: TextStyle(
              fontSize: 14,
              color: isPhishing ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

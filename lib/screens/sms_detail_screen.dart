import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/sms_record.dart';

class SmsDetailScreen extends StatelessWidget {
  final SmsRecord record;

  const SmsDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy년 MM월 dd일 HH:mm');
    final isPhishing = record.isPhishing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS 상세 정보'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 위험도 배지
            _buildRiskBadge(isPhishing),
            const SizedBox(height: 24),

            // 기본 정보 카드
            _buildInfoCard(
              title: '기본 정보',
              children: [
                _buildInfoRow('발신번호', record.phoneNumber),
                const Divider(height: 24),
                _buildInfoRow('분석 일시', dateFormat.format(record.analyzedAt)),
                const Divider(height: 24),
                _buildInfoRow('파일명', record.fileName),
              ],
            ),
            const SizedBox(height: 16),

            // 분석 결과 카드
            _buildInfoCard(
              title: '분석 결과',
              children: [
                _buildInfoRow(
                  '위험도',
                  isPhishing ? '위험' : '안전',
                  valueColor: isPhishing ? Colors.red : Colors.green,
                  isBold: true,
                ),
                const Divider(height: 24),
                _buildInfoRow(
                  '의심 키워드',
                  '${record.keywordCount}개 발견',
                  valueColor: record.keywordCount > 0 ? Colors.red : Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 메시지 내용 카드
            _buildMessageCard(),
            const SizedBox(height: 24),

            // 대처 방법 (위험한 경우만)
            if (isPhishing) ...[
              _buildResponseGuideCard(),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRiskBadge(bool isPhishing) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPhishing ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPhishing ? Colors.red.shade300 : Colors.green.shade300,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isPhishing ? Icons.warning_amber_rounded : Icons.check_circle,
            color: isPhishing ? Colors.red.shade700 : Colors.green.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Text(
            isPhishing ? '보이스피싱 의심 SMS' : '안전한 SMS',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPhishing ? Colors.red.shade900 : Colors.green.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '메시지 내용',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              record.messageContent,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text(
                '대처 방법',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildGuideItem('1. 절대 링크를 클릭하거나 회신하지 마세요'),
          const SizedBox(height: 8),
          _buildGuideItem('2. 의심되는 경우 해당 기관에 직접 전화하여 확인하세요'),
          const SizedBox(height: 8),
          _buildGuideItem('3. 개인정보나 금융정보를 절대 제공하지 마세요'),
          const SizedBox(height: 8),
          _buildGuideItem('4. 스미싱 신고: 1332 (금융감독원)'),
        ],
      ),
    );
  }

  Widget _buildGuideItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.arrow_right, size: 20, color: Colors.orange.shade700),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/call_record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Map<String, int> _statistics = {'total': 0, 'phishing': 0, 'safe': 0};
  List<CallRecord> _recentPhishingCalls = [];
  DateTime? _lastAnalyzedTime;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // 대시보드 데이터 로드
  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await _db.getStatistics();
      final recentCalls = await _db.getRecentPhishingCalls(limit: 3);
      final lastTime = await _db.getLastAnalyzedTime();

      setState(() {
        _statistics = stats;
        _recentPhishingCalls = recentCalls;
        _lastAnalyzedTime = lastTime;
        _isLoading = false;
      });
    } catch (e) {
      print('대시보드 데이터 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  // 새로고침
  Future<void> _refreshData() async {
    await _loadDashboardData();
  }

  // 안전 상태 판단
  bool get _isSafe => _recentPhishingCalls.isEmpty;

  // 마지막 분석 시간 포맷
  String get _formattedLastTime {
    if (_lastAnalyzedTime == null) return '분석 기록 없음';

    final now = DateTime.now();
    final difference = now.difference(_lastAnalyzedTime!);

    if (difference.inMinutes < 1) {
      return '방금 전';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}시간 전';
    } else {
      return '${difference.inDays}일 전';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보이스피싱 감시'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 안전 상태 카드
                    _buildSafetyStatusCard(),
                    const SizedBox(height: 24),

                    // 통계 섹션
                    _buildStatisticsSection(),
                    const SizedBox(height: 24),

                    // 최근 위험 감지 (있는 경우만)
                    if (_recentPhishingCalls.isNotEmpty) ...[
                      _buildRecentPhishingSection(),
                      const SizedBox(height: 24),
                    ],

                    // 예방 팁
                    _buildPreventionTipsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  // 안전 상태 카드
  Widget _buildSafetyStatusCard() {
    final isSafe = _isSafe;
    final backgroundColor = isSafe ? Colors.green.shade50 : Colors.red.shade50;
    final borderColor = isSafe ? Colors.green.shade300 : Colors.red.shade300;
    final iconColor = isSafe ? Colors.green.shade700 : Colors.red.shade700;
    final textColor = isSafe ? Colors.green.shade900 : Colors.red.shade900;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Column(
        children: [
          Icon(
            isSafe ? Icons.shield_outlined : Icons.warning_amber_rounded,
            size: 80,
            color: iconColor,
          ),
          const SizedBox(height: 16),
          Text(
            isSafe ? '현재 안전합니다' : '위험 감지됨!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSafe
                ? '최근 보이스피싱 의심 통화가 없습니다'
                : '보이스피싱 의심 통화가 감지되었습니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                '마지막 분석: $_formattedLastTime',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 통계 섹션
  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📊 분석 통계',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '총 분석',
                _statistics['total']!,
                Colors.blue,
                Icons.analytics,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '위험 감지',
                _statistics['phishing']!,
                Colors.red,
                Icons.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                '안전',
                _statistics['safe']!,
                Colors.green,
                Icons.check_circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 통계 카드
  Widget _buildStatCard(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            '$count건',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // 최근 위험 감지 섹션
  Widget _buildRecentPhishingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚠️ 최근 위험 감지',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._recentPhishingCalls.map((record) => _buildPhishingCallCard(record)),
      ],
    );
  }

  // 위험 통화 카드
  Widget _buildPhishingCallCard(CallRecord record) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.phone_in_talk, color: Colors.red.shade700, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.phoneNumber,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(record.analyzedAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '키워드 ${record.keywordCount}개 발견',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  // 예방 팁 섹션
  Widget _buildPreventionTipsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🛡️ 보이스피싱 예방 팁',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTipItem('공공기관은 전화로 계좌번호나 비밀번호를 요구하지 않습니다.'),
              const SizedBox(height: 8),
              _buildTipItem('안전계좌, 보호계좌 같은 것은 존재하지 않습니다.'),
              const SizedBox(height: 8),
              _buildTipItem('의심스러운 전화는 끊고 해당 기관에 직접 전화하세요.'),
            ],
          ),
        ),
      ],
    );
  }

  // 팁 아이템
  Widget _buildTipItem(String tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tip,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
      ],
    );
  }
}

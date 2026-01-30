import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/records_screen.dart';
import 'services/file_monitoring_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '보이스피싱 감지',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}

// 메인 네비게이션 페이지 (하단 탭 바)
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  int _selectedIndex = 0;

  // 페이지 목록
  final List<Widget> _pages = [
    const HomeScreen(), // 홈 대시보드
    const RecordsScreen(), // 기록 (통화 분석 기록)
    const SettingsPlaceholderPage(), // 설정 (임시)
  ];

  @override
  void initState() {
    super.initState();
    // 파일 모니터링 서비스 초기화
    _initFileMonitoring();
  }

  // 파일 모니터링 서비스 시작
  Future<void> _initFileMonitoring() async {
    await FileMonitoringService.instance.initialize(
      onPhishingDetectedCallback: (transcriptionText) {
        // 보이스피싱 알림 클릭 시 대처 방법 페이지로 이동
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PhishingResponseGuidePage(
                transcriptionText: transcriptionText,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    FileMonitoringService.instance.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: '기록',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// 임시 설정 페이지
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Text('설정 페이지 (준비 중)'),
      ),
    );
  }
}

// 보이스피싱 대처 방법 안내 페이지
class PhishingResponseGuidePage extends StatelessWidget {
  final String transcriptionText;

  const PhishingResponseGuidePage({
    super.key,
    required this.transcriptionText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('보이스피싱 대처 방법'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 경고 헤더
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade300, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '보이스피싱 의심 통화 감지',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '방금 전 통화에서 의심스러운 키워드가 발견되었습니다.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 즉시 조치 사항
            _buildSectionTitle('⚡ 즉시 취해야 할 조치'),
            _buildActionCard(
              '1',
              '송금/이체를 중단하세요',
              '아직 송금하지 않았다면 절대 송금하지 마세요. 이미 송금했다면 즉시 은행에 연락하세요.',
              Colors.red,
            ),
            _buildActionCard(
              '2',
              '112 (경찰) 또는 금융회사에 신고',
              '경찰청 사이버안전국(국번없이 182) 또는 금융감독원(국번없이 1332)에 즉시 신고하세요.',
              Colors.orange,
            ),
            _buildActionCard(
              '3',
              '계좌 지급정지 요청',
              '피해 계좌에 대한 지급정지를 요청하여 추가 피해를 막으세요.',
              Colors.amber,
            ),
            const SizedBox(height: 24),

            // 긴급 연락처
            _buildSectionTitle('📞 긴급 연락처'),
            _buildContactCard('경찰청 사이버안전국', '182', Icons.local_police),
            _buildContactCard('금융감독원', '1332', Icons.account_balance),
            _buildContactCard('경찰청 (긴급)', '112', Icons.emergency),
            const SizedBox(height: 24),

            // 통화 내용
            _buildSectionTitle('📝 통화 내용 (참고용)'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                transcriptionText,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),

            // 보이스피싱 예방 수칙
            _buildSectionTitle('🛡️ 보이스피싱 예방 수칙'),
            _buildPreventionTip('공공기관은 전화로 계좌번호나 비밀번호를 요구하지 않습니다.'),
            _buildPreventionTip('안전계좌, 보호계좌 같은 것은 존재하지 않습니다.'),
            _buildPreventionTip('가족이나 지인을 사칭한 경우 직접 통화로 확인하세요.'),
            _buildPreventionTip('의심스러운 전화는 끊고 해당 기관에 직접 전화하세요.'),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionCard(String number, String title, String description, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
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

  Widget _buildContactCard(String name, String number, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            number,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreventionTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

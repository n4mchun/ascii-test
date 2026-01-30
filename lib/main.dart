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
                          '신속한 대처가 피해를 최소화합니다!',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 황금시간 - 즉시 신고
            _buildSectionTitle('🚨 황금시간 - 즉시 신고하세요!'),
            _buildActionCard(
              '1',
              '경찰청 전기통신금융사기 신고',
              '경찰청 통합신고대응센터 112번으로 즉시 신고하세요. 빠른 신고가 피해 회복의 핵심입니다.',
              Colors.red,
            ),
            _buildActionCard(
              '2',
              '금융회사 및 금융감독원 신고',
              '금융감독원 1332번 또는 거래 은행 고객센터로 연락해 금융 피해 차단을 요청하세요.',
              Colors.orange,
            ),
            _buildActionCard(
              '3',
              '악성 앱 설치 의심 시 인터넷 차단',
              '휴대폰에 악성 앱이 설치되었을 수 있다면 즉시 인터넷(Wi-Fi, 데이터)을 끄세요.',
              Colors.amber,
            ),
            const SizedBox(height: 24),

            // 긴급 연락처
            _buildSectionTitle('📞 긴급 연락처'),
            _buildContactCard('경찰청 (긴급 신고)', '112', Icons.local_police),
            _buildContactCard('경찰청 사이버안전국', '182', Icons.shield),
            _buildContactCard('금융감독원', '1332', Icons.account_balance),
            const SizedBox(height: 24),

            // 2차 피해 방지
            _buildSectionTitle('🛡️ 2차 피해 방지'),
            _buildPreventionStep('1. 증거 확보', '통화 녹음, 문자, 카카오톡 대화 내역을 캡쳐하여 보관하세요.'),
            _buildPreventionStep('2. 거래 내역 정리', '피해 금액과 계좌 정보를 정리하세요 (경찰 신고 시 필요).'),
            _buildPreventionStep('3. 악성 앱 완전 삭제', '휴대폰에서 의심스러운 앱을 모두 삭제하고, 필요시 초기화하세요.'),
            const SizedBox(height: 24),

            // 개인정보 유출 시 10단계 조치
            _buildSectionTitle('🔒 개인정보 유출 시 10단계 조치'),
            _buildInfoProtectionSection(),
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
            _buildSectionTitle('💡 보이스피싱 예방 수칙'),
            _buildPreventionTip('공공기관은 전화로 계좌번호나 비밀번호를 절대 요구하지 않습니다.'),
            _buildPreventionTip('안전계좌, 보호계좌는 존재하지 않습니다. 모두 사기입니다.'),
            _buildPreventionTip('가족이나 지인을 사칭한 경우 반드시 직접 통화로 확인하세요.'),
            _buildPreventionTip('의심스러운 전화는 즉시 끊고 해당 기관에 직접 전화하세요.'),
            _buildPreventionTip('출처가 불분명한 앱은 절대 설치하지 마세요.'),
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

  Widget _buildPreventionStep(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoProtectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '긴급 대응 (피해 직후)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoProtectionItem('1', '금융사기 예방 시스템 등록'),
          _buildInfoProtectionItem('2', '명의도용 계좌·카드·대출 조회 (어카운트인포)'),
          _buildInfoProtectionItem('3', '명의도용 방지 서비스 신청 (엠세이퍼 등)'),
          _buildInfoProtectionItem('4', '토스 앱 차단 요청 (1599-4905)'),
          _buildInfoProtectionItem('5', '여신거래 안심차단 서비스 신청'),
          _buildInfoProtectionItem('6', '소액결제·콘텐츠 이용료 차단 (통신사 114)'),
          const SizedBox(height: 16),
          Text(
            '사후 조치 (신고 후)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoProtectionItem('7', '신분증 재발급 (주민등록증, 운전면허증, 여권)'),
          _buildInfoProtectionItem('8', '공동/금융인증서 폐기 후 재발급'),
          _buildInfoProtectionItem('9', '본인확인 내역 조회 (개인정보 보호 포털)'),
          _buildInfoProtectionItem('10', '명의도용 조회 재확인'),
        ],
      ),
    );
  }

  Widget _buildInfoProtectionItem(String number, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

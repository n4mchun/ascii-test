import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 알림 패키지
import 'config.dart'; // API 키 설정 파일

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Watcher & Notifier',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const FileListPage(),
    );
  }
}

class FileListPage extends StatefulWidget {
  const FileListPage({super.key});

  @override
  State<FileListPage> createState() => _FileListPageState();
}

class _FileListPageState extends State<FileListPage> {
  List<FileSystemEntity> _files = [];
  final String _targetPath = '/storage/emulated/0/Download';
  final String _apiKey = ApiConfig.openaiApiKey; // config.dart에서 API 키 로드

  // 파일 감지 리스너
  StreamSubscription<FileSystemEvent>? _dirWatcher;

  // 알림 플러그인 인스턴스
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // 보이스피싱 의심 키워드 목록
  final List<String> _phishingKeywords = [
    '금융감독원', '검찰청', '경찰청', '국세청', '대검찰청',
    '보안카드', '계좌번호', '비밀번호', '인증번호', 'OTP',
    '송금', '이체', '출금', '입금',
    '수사', '조사', '혐의', '범죄', '사건',
    '피해자', '가해자', '명의도용',
    '안전계좌', '보호계좌', '보안계좌',
    '대출', '저금리', '한도', '승인',
    '환불', '세금', '환급', '체납',
    '가족', '자녀', '아들', '딸', '납치', '사고',
    '휴대폰', '소액결제', '결제내역',
  ];

  // 보이스피싱 탐지 임계값 (키워드가 이 횟수 이상 나오면 의심)
  final int _phishingThreshold = 3;

  @override
  void initState() {
    super.initState();
    _initNotification(); // 알림 초기화
    _checkPermissionAndInit(); // 권한 체크 및 감시 시작
  }

  @override
  void dispose() {
    _dirWatcher?.cancel();
    super.dispose();
  }

  // [수정됨] 1. 알림 플러그인 초기화 설정 (const 제거 및 타입 명시)
  Future<void> _initNotification() async {
    // 안드로이드 초기화 설정
    var androidInitializationSettings =
    const AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정
    var iosInitializationSettings = const DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    var initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    // initialize 함수 실행
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // 알림 클릭 시 실행될 콜백
        print('알림 클릭됨: ${response.payload}');

        // 보이스피싱 알림을 클릭한 경우 대처 방법 페이지로 이동
        if (response.payload != null && response.payload!.startsWith('phishing_detected:')) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhishingResponseGuidePage(
                  transcriptionText: response.payload!.replaceFirst('phishing_detected:', ''),
                ),
              ),
            );
          }
        }
      },
    );
  }

  // 2. 권한 요청 및 초기화
  Future<void> _checkPermissionAndInit() async {
    // Android 13 이상 알림 권한 요청
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // 파일 접근 권한 요청
    bool storageGranted = false;
    if (await Permission.manageExternalStorage.request().isGranted) {
      storageGranted = true;
    } else if (await Permission.storage.request().isGranted) {
      storageGranted = true;
    }

    if (storageGranted) {
      _listFiles();
      _startWatching();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일 접근 권한이 필요합니다.')),
        );
      }
    }
  }

  // 3. 파일 목록 조회
  void _listFiles() {
    final dir = Directory(_targetPath);
    if (dir.existsSync()) {
      setState(() {
        _files = dir.listSync(recursive: false).toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      });
    }
  }

  // 4. 폴더 감시 (Background Event Listening)
  void _startWatching() {
    final dir = Directory(_targetPath);
    if (!dir.existsSync()) return;

    // 11자리 전화번호 + 지원하는 오디오/비디오 확장자
    // 지원 형식: mp3, mp4, mpeg, mpga, m4a, wav, webm
    final targetPattern = RegExp(r'^\d{11}\.(mp3|mp4|mpeg|mpga|m4a|wav|webm)$', caseSensitive: false);

    _dirWatcher = dir.watch(events: FileSystemEvent.create).listen((event) async {
      if (event.type == FileSystemEvent.create) {
        final fileName = event.path.split('/').last;

        if (targetPattern.hasMatch(fileName)) {
          print('★ 타겟 파일 감지됨: $fileName');

          // [핵심] 상단 알림 발송
          await _showNotification(fileName);

          // Whisper API 호출
          final file = File(event.path);
          await _transcribeAudio(file);
        }
      }

      if (mounted) _listFiles();
    });
  }

  // [수정됨] 5. 상단 알림 띄우기 함수 (const 제거 및 최신 파라미터 적용)
  Future<void> _showNotification(String fileName) async {
    // 안드로이드 알림 상세 설정
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'channel_id_1', // 채널 ID
      '녹음 파일 감지', // 채널 이름 (사용자에게 보임)
      channelDescription: '녹음 파일이 감지되었을 때 알림을 보냅니다.', // 설명
      importance: Importance.max, // 상단 알림을 위해 max 필요
      priority: Priority.high,    // 상단 알림을 위해 high 필요
      ticker: 'ticker', // 접근성용 텍스트
    );

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(), // iOS 상세 설정 추가
    );

    await flutterLocalNotificationsPlugin.show(
      id: 0, // 알림 ID (0이면 계속 덮어씌움, 다르게 주면 쌓임)
      title: '새로운 녹음 파일 감지!', // 제목
      body: '$fileName 파일이 분석을 시작합니다.', // 본문
      notificationDetails: platformChannelSpecifics,
      payload: fileName, // 알림 클릭 시 전달할 데이터
    );
  }

  // 6. 변환 결과 알림 띄우기 (앱이 백그라운드에 있어도 작동)
  Future<void> _showTranscriptionNotification(String transcriptionText) async {
    // 안드로이드 알림 상세 설정
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'channel_id_2', // 변환 결과용 별도 채널 ID
      '변환 결과', // 채널 이름
      channelDescription: '음성 파일 변환 결과를 알려줍니다.', // 설명
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''), // 긴 텍스트 지원
    );

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(),
    );

    await flutterLocalNotificationsPlugin.show(
      id: 1, // 변환 결과 알림용 ID (파일 감지 알림과 구분)
      title: '음성 변환 완료', // 제목
      body: transcriptionText, // 변환된 텍스트
      notificationDetails: platformChannelSpecifics,
      payload: transcriptionText,
    );
  }

  // 7. 보이스피싱 키워드 분석
  int _detectPhishingKeywords(String text) {
    int keywordCount = 0;
    String lowerText = text.toLowerCase();

    for (String keyword in _phishingKeywords) {
      // 키워드가 텍스트에 포함된 횟수를 카운트
      keywordCount += keyword.allMatches(lowerText).length;
    }

    print('보이스피싱 키워드 발견 횟수: $keywordCount');
    return keywordCount;
  }

  // 8. 보이스피싱 의심 알림 (위험도 높음)
  Future<void> _showPhishingWarningNotification(String transcriptionText) async {
    var androidPlatformChannelSpecifics = const AndroidNotificationDetails(
      'channel_id_phishing', // 보이스피싱 전용 채널
      '보이스피싱 경고', // 채널 이름
      channelDescription: '보이스피싱이 의심되는 통화를 감지했을 때 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.max, // 최대 우선순위
      ticker: 'phishing_alert',
      color: Color(0xFFFF0000), // 빨간색
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        '방금 전 통화에서 보이스피싱 의심 키워드가 다수 발견되었습니다. 탭하여 대처 방법을 확인하세요.',
        contentTitle: '방금 하셨던 통화, 보이스피싱 피해가 의심돼요!',
      ),
    );

    var platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await flutterLocalNotificationsPlugin.show(
      id: 999, // 보이스피싱 알림 전용 ID
      title: '⚠️ 방금 하셨던 통화, 보이스피싱 피해가 의심돼요!',
      body: '의심 키워드가 발견되었습니다. 탭하여 대처 방법을 확인하세요.',
      notificationDetails: platformChannelSpecifics,
      payload: 'phishing_detected:$transcriptionText', // 페이로드로 보이스피싱 플래그 전달
    );
  }

  // 9. OpenAI Whisper API 호출 및 보이스피싱 분석
  Future<void> _transcribeAudio(File audioFile) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'ko';

      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      print('서버 전송 시작...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final text = jsonResponse['text'];
        print('변환 결과: $text');

        // 보이스피싱 키워드 분석
        int phishingKeywordCount = _detectPhishingKeywords(text);

        if (phishingKeywordCount >= _phishingThreshold) {
          // 보이스피싱 의심! 경고 알림 표시
          print('⚠️ 보이스피싱 의심! 키워드 $phishingKeywordCount개 발견');
          await _showPhishingWarningNotification(text);
        } else {
          // 정상 통화 - 일반 변환 결과 알림
          await _showTranscriptionNotification(text);
        }
      } else {
        print('변환 실패: ${response.body}');
        await _showTranscriptionNotification('변환 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('네트워크 오류: $e');
      await _showTranscriptionNotification('네트워크 오류 발생');
    }
  }

  // 테스트용: 가짜 파일 생성 버튼 (실제 테스트 시에는 삭제 가능)
  Future<void> _createTargetFile() async {
    final randomNum = '010${(10000000 + DateTime.now().millisecondsSinceEpoch % 90000000).toString().substring(0, 8)}';

    // 지원하는 확장자 목록
    final extensions = ['mp3', 'mp4', 'mpeg', 'mpga', 'm4a', 'wav', 'webm'];

    // 랜덤으로 확장자 선택 (테스트용)
    final randomExtension = extensions[DateTime.now().millisecond % extensions.length];

    final fileName = '$randomNum.$randomExtension';
    final newFile = File('$_targetPath/$fileName');

    try {
      // 주의: 텍스트 내용의 가짜 오디오/비디오 파일은 Whisper API에서 실패할 수 있음.
      // 알림 테스트용으로만 사용하세요.
      await newFile.writeAsString('fake content');
      print('테스트 파일 생성됨: $fileName');
    } catch (e) {
      print('생성 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('녹음 파일 감지기'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _files.isEmpty
          ? const Center(child: Text('파일 대기 중...'))
          : ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final fileName = file.path.split('/').last;
          return ListTile(
            leading: const Icon(Icons.audiotrack, color: Colors.blue),
            title: Text(fileName),
            subtitle: Text(file.path),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTargetFile,
        child: const Icon(Icons.add_alert),
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
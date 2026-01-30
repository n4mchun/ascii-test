import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // 알림 패키지

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
  final String _apiKey = 'sk-proj-YOUR_OPENAI_API_KEY_HERE'; // API 키 확인 필요

  // 파일 감지 리스너
  StreamSubscription<FileSystemEvent>? _dirWatcher;

  // 알림 플러그인 인스턴스
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

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
    // @mipmap/ic_launcher가 없으면 에러가 날 수 있으므로 확인 필요
    // 기본적으로 Flutter 프로젝트 생성 시 존재함.
    var androidInitializationSettings =
    const AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정 (혹시 모를 에러 방지용 추가)
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
        // 알림 클릭 시 실행될 콜백 (필요 시 구현)
        print('알림 클릭됨: ${response.payload}');
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

    final targetPattern = RegExp(r'^\d{11}\.mp3$');

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

  // 6. OpenAI Whisper API 호출
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

        // 변환 결과를 시스템 알림으로 표시 (앱이 백그라운드/포그라운드 상관없이 작동)
        await _showTranscriptionNotification(text);
      } else {
        print('변환 실패: ${response.body}');
        // 실패 알림도 시스템 알림으로 표시
        await _showTranscriptionNotification('변환 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('네트워크 오류: $e');
      // 오류 알림도 시스템 알림으로 표시
      await _showTranscriptionNotification('네트워크 오류 발생');
    }
  }

  // 테스트용: 가짜 파일 생성 버튼 (실제 테스트 시에는 삭제 가능)
  Future<void> _createTargetFile() async {
    final randomNum = '010${(10000000 + DateTime.now().millisecondsSinceEpoch % 90000000).toString().substring(0, 8)}';
    final fileName = '$randomNum.mp3';
    final newFile = File('$_targetPath/$fileName');

    try {
      // 주의: 텍스트 내용의 가짜 MP3는 Whisper API에서 실패할 수 있음.
      // 알림 테스트용으로만 사용하세요.
      await newFile.writeAsString('fake content');
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
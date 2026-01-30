import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../database/database_helper.dart';
import '../models/call_record.dart';

/// 파일 모니터링 서비스
/// 앱이 실행되는 동안 Download 폴더를 감시하고 새로운 녹음 파일을 자동으로 분석합니다.
class FileMonitoringService {
  static final FileMonitoringService instance = FileMonitoringService._init();

  FileMonitoringService._init();

  final String _targetPath = '/storage/emulated/0/Download';
  final String _apiKey = ApiConfig.openaiApiKey;

  StreamSubscription<FileSystemEvent>? _dirWatcher;

  // 알림 플러그인
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
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

  final int _phishingThreshold = 3;

  // 알림 클릭 콜백을 저장할 변수
  Function(String)? onPhishingDetected;

  /// 서비스 초기화 및 시작
  Future<void> initialize({Function(String)? onPhishingDetectedCallback}) async {
    onPhishingDetected = onPhishingDetectedCallback;

    await _initNotification();
    await _checkPermissionAndStartMonitoring();
  }

  /// 알림 플러그인 초기화
  Future<void> _initNotification() async {
    const androidInitializationSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosInitializationSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print('알림 클릭됨: ${response.payload}');

        // 보이스피싱 알림 클릭 시 콜백 호출
        if (response.payload != null &&
            response.payload!.startsWith('phishing_detected:')) {
          final text = response.payload!.replaceFirst('phishing_detected:', '');
          onPhishingDetected?.call(text);
        }
      },
    );
  }

  /// 권한 확인 및 모니터링 시작
  Future<void> _checkPermissionAndStartMonitoring() async {
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
      _startWatching();
      print('✓ 파일 모니터링 서비스 시작됨');
    } else {
      print('✗ 파일 접근 권한이 거부되었습니다.');
    }
  }

  /// 폴더 감시 시작
  void _startWatching() {
    final dir = Directory(_targetPath);
    if (!dir.existsSync()) {
      print('✗ Download 폴더가 존재하지 않습니다: $_targetPath');
      return;
    }

    // 11자리 전화번호 + 지원하는 오디오/비디오 확장자
    final targetPattern = RegExp(
      r'^\d{11}\.(mp3|mp4|mpeg|mpga|m4a|wav|webm)$',
      caseSensitive: false,
    );

    _dirWatcher = dir.watch(events: FileSystemEvent.create).listen((event) async {
      if (event.type == FileSystemEvent.create) {
        final fileName = event.path.split('/').last;

        if (targetPattern.hasMatch(fileName)) {
          print('★ 타겟 파일 감지됨: $fileName');

          // 파일 감지 알림
          await _showNotification(fileName);

          // Whisper API 호출 및 분석
          final file = File(event.path);
          await _transcribeAudio(file);
        }
      }
    });
  }

  /// 파일 감지 알림
  Future<void> _showNotification(String fileName) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id_1',
      '녹음 파일 감지',
      channelDescription: '녹음 파일이 감지되었을 때 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 0,
      title: '새로운 녹음 파일 감지!',
      body: '$fileName 파일이 분석을 시작합니다.',
      notificationDetails: details,
      payload: fileName,
    );
  }

  /// 변환 결과 알림
  Future<void> _showTranscriptionNotification(String transcriptionText) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id_2',
      '변환 결과',
      channelDescription: '음성 파일 변환 결과를 알려줍니다.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: 1,
      title: '음성 변환 완료',
      body: transcriptionText,
      notificationDetails: details,
      payload: transcriptionText,
    );
  }

  /// 보이스피싱 키워드 탐지
  int _detectPhishingKeywords(String text) {
    int keywordCount = 0;
    String lowerText = text.toLowerCase();

    for (String keyword in _phishingKeywords) {
      keywordCount += keyword.allMatches(lowerText).length;
    }

    print('보이스피싱 키워드 발견 횟수: $keywordCount');
    return keywordCount;
  }

  /// 보이스피싱 경고 알림
  Future<void> _showPhishingWarningNotification(String transcriptionText) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_id_phishing',
      '보이스피싱 경고',
      channelDescription: '보이스피싱이 의심되는 통화를 감지했을 때 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'phishing_alert',
      color: Color(0xFFFF0000),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        '방금 전 통화에서 보이스피싱 의심 키워드가 다수 발견되었습니다. 탭하여 대처 방법을 확인하세요.',
        contentTitle: '방금 하셨던 통화, 보이스피싱 피해가 의심돼요!',
      ),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _notificationsPlugin.show(
      id: 999,
      title: '⚠️ 방금 하셨던 통화, 보이스피싱 피해가 의심돼요!',
      body: '의심 키워드가 발견되었습니다. 탭하여 대처 방법을 확인하세요.',
      notificationDetails: details,
      payload: 'phishing_detected:$transcriptionText',
    );
  }

  /// Whisper API 호출 및 분석
  Future<void> _transcribeAudio(File audioFile) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final fileName = audioFile.path.split('/').last;
    final phoneNumber = fileName.split('.').first;

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
        bool isPhishing = phishingKeywordCount >= _phishingThreshold;

        // 데이터베이스에 저장
        final record = CallRecord(
          phoneNumber: phoneNumber,
          fileName: fileName,
          filePath: audioFile.path,
          analyzedAt: DateTime.now(),
          transcriptionText: text,
          riskLevel: isPhishing ? 'danger' : 'safe',
          keywordCount: phishingKeywordCount,
          isPhishing: isPhishing,
        );

        await DatabaseHelper.instance.createCallRecord(record);
        print('데이터베이스에 저장 완료');

        if (isPhishing) {
          print('⚠️ 보이스피싱 의심! 키워드 $phishingKeywordCount개 발견');
          await _showPhishingWarningNotification(text);
        } else {
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

  /// 서비스 종료
  void dispose() {
    _dirWatcher?.cancel();
    print('✓ 파일 모니터링 서비스 종료됨');
  }
}

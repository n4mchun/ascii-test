import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../config.dart';
import '../database/database_helper.dart';
import '../models/call_record.dart';
import 'phishing_detection_service.dart';
import 'notification_service.dart';

/// 오디오 파일 모니터링 서비스
/// Download 폴더의 오디오 파일을 감시하고 자동으로 분석합니다.
class AudioMonitoringService {
  static final AudioMonitoringService instance = AudioMonitoringService._init();

  AudioMonitoringService._init();

  final String _targetPath = '/storage/emulated/0/Download';
  final String _apiKey = ApiConfig.openaiApiKey;

  StreamSubscription<FileSystemEvent>? _dirWatcher;

  final PhishingDetectionService _phishingDetector = PhishingDetectionService.instance;
  final NotificationService _notifications = NotificationService.instance;

  /// 서비스 초기화 및 시작
  Future<void> initialize() async {
    await _checkPermissionAndStartMonitoring();
  }

  /// 권한 확인 및 모니터링 시작
  Future<void> _checkPermissionAndStartMonitoring() async {
    // 파일 접근 권한 요청
    bool storageGranted = false;
    if (await Permission.manageExternalStorage.request().isGranted) {
      storageGranted = true;
    } else if (await Permission.storage.request().isGranted) {
      storageGranted = true;
    }

    if (storageGranted) {
      _startWatching();
      print('✓ 오디오 파일 모니터링 서비스 시작됨');
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
          print('★ 오디오 파일 감지됨: $fileName');

          // 파일 감지 알림
          await _notifications.showFileDetectedNotification(
            fileName: fileName,
            fileType: 'audio',
          );

          // Whisper API 호출 및 분석
          final file = File(event.path);
          await _transcribeAndAnalyze(file);
        }
      }
    });
  }

  /// Whisper API 호출 및 보이스피싱 분석
  Future<void> _transcribeAndAnalyze(File audioFile) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final fileName = audioFile.path.split('/').last;
    final phoneNumber = fileName.split('.').first;

    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'ko';

      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      print('오디오 변환 시작...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final text = jsonResponse['text'] as String;
        print('변환 완료: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');

        // 보이스피싱 분석
        final analysis = _phishingDetector.analyzeText(text);
        final keywordCount = analysis['keywordCount'] as int;
        final isPhishing = analysis['isPhishing'] as bool;

        // 데이터베이스에 저장
        final record = CallRecord(
          phoneNumber: phoneNumber,
          fileName: fileName,
          filePath: audioFile.path,
          analyzedAt: DateTime.now(),
          transcriptionText: text,
          riskLevel: isPhishing ? 'danger' : 'safe',
          keywordCount: keywordCount,
          isPhishing: isPhishing,
        );

        await DatabaseHelper.instance.createCallRecord(record);
        print('데이터베이스에 저장 완료');

        // 결과 알림
        if (isPhishing) {
          print('⚠️ 보이스피싱 의심! 키워드 $keywordCount개 발견');
          await _notifications.showPhishingWarningNotification(
            content: text,
            type: 'call',
          );
        } else {
          await _notifications.showAnalysisCompleteNotification(
            content: '안전한 통화로 분석되었습니다.',
          );
        }
      } else {
        print('변환 실패: ${response.statusCode} - ${response.body}');
        await _notifications.showErrorNotification(
          message: '음성 변환 실패: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('오류 발생: $e');
      await _notifications.showErrorNotification(
        message: '처리 중 오류 발생',
      );
    }
  }

  /// 서비스 종료
  void dispose() {
    _dirWatcher?.cancel();
    print('✓ 오디오 파일 모니터링 서비스 종료됨');
  }
}

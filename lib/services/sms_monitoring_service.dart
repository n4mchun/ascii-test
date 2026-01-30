import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../database/database_helper.dart';
import '../models/sms_record.dart';
import 'phishing_detection_service.dart';
import 'notification_service.dart';

/// SMS 메시지 파일 모니터링 서비스
/// Download 폴더의 .txt 파일을 감시하고 자동으로 분석합니다.
class SmsMonitoringService {
  static final SmsMonitoringService instance = SmsMonitoringService._init();

  SmsMonitoringService._init();

  final String _targetPath = '/storage/emulated/0/Download';

  StreamSubscription<FileSystemEvent>? _dirWatcher;
  Timer? _pollingTimer;
  final Set<String> _processedFiles = {};

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
      print('✓ SMS 파일 모니터링 서비스 시작됨');
    } else {
      print('✗ 파일 접근 권한이 거부되었습니다.');
    }
  }

  /// 폴더 감시 시작 (폴링 방식)
  void _startWatching() {
    final dir = Directory(_targetPath);
    if (!dir.existsSync()) {
      print('✗ Download 폴더가 존재하지 않습니다: $_targetPath');
      return;
    }

    // 11자리 전화번호 + .txt 확장자
    final targetPattern = RegExp(
      r'^\d{11}\.txt$',
      caseSensitive: false,
    );

    // 기존 파일 확인
    _checkExistingFiles(dir, targetPattern);

    // 폴링 방식으로 새 파일 감지 (2초마다 확인)
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final files = dir.listSync();

        for (var entity in files) {
          if (entity is File) {
            final fileName = entity.path.split('/').last;

            if (targetPattern.hasMatch(fileName) && !_processedFiles.contains(fileName)) {
              print('★ 새로운 SMS 파일 감지됨: $fileName');

              // 처리됨으로 표시
              _processedFiles.add(fileName);

              // 파일 감지 알림
              await _notifications.showFileDetectedNotification(
                fileName: fileName,
                fileType: 'sms',
              );

              // SMS 내용 분석
              await _analyzeMessage(entity);
            }
          }
        }
      } catch (e) {
        print('폴링 중 오류: $e');
      }
    });
  }

  /// 기존 파일 확인 (테스트용)
  void _checkExistingFiles(Directory dir, RegExp pattern) {
    try {
      final files = dir.listSync();
      print('📂 Download 폴더 파일 개수: ${files.length}');

      for (var entity in files) {
        if (entity is File) {
          final fileName = entity.path.split('/').last;
          if (pattern.hasMatch(fileName)) {
            print('📄 기존 SMS 파일 발견: $fileName');
            // 기존 파일은 자동 분석하지 않음 (무한 반복 방지)
          }
        }
      }
    } catch (e) {
      print('파일 목록 확인 중 오류: $e');
    }
  }

  /// SMS 메시지 내용 분석
  Future<void> _analyzeMessage(File smsFile) async {
    final fileName = smsFile.path.split('/').last;
    final phoneNumber = fileName.split('.').first;

    try {
      // 파일이 완전히 기록될 때까지 짧은 대기
      await Future.delayed(const Duration(milliseconds: 500));

      // 파일 내용 읽기
      final messageContent = await smsFile.readAsString();

      if (messageContent.isEmpty) {
        print('파일 내용이 비어있습니다: $fileName');
        await _notifications.showErrorNotification(
          message: 'SMS 파일이 비어있습니다',
        );
        return;
      }

      print('SMS 내용 읽기 완료: ${messageContent.substring(0, messageContent.length > 50 ? 50 : messageContent.length)}...');

      // 보이스피싱 분석
      final analysis = _phishingDetector.analyzeText(messageContent);
      final keywordCount = analysis['keywordCount'] as int;
      final isPhishing = analysis['isPhishing'] as bool;

      // 데이터베이스에 저장
      final record = SmsRecord(
        phoneNumber: phoneNumber,
        fileName: fileName,
        filePath: smsFile.path,
        analyzedAt: DateTime.now(),
        messageContent: messageContent,
        riskLevel: isPhishing ? 'danger' : 'safe',
        keywordCount: keywordCount,
        isPhishing: isPhishing,
      );

      await DatabaseHelper.instance.createSmsRecord(record);
      print('데이터베이스에 저장 완료');

      // 결과 알림
      if (isPhishing) {
        print('⚠️ 보이스피싱 의심 SMS! 키워드 $keywordCount개 발견');
        await _notifications.showPhishingWarningNotification(
          content: messageContent,
          type: 'sms',
        );
      } else {
        await _notifications.showAnalysisCompleteNotification(
          content: '안전한 메시지로 분석되었습니다.',
        );
      }
    } catch (e) {
      print('SMS 분석 오류 발생: $e');
      await _notifications.showErrorNotification(
        message: 'SMS 분석 중 오류 발생',
      );
    }
  }

  /// 서비스 종료
  void dispose() {
    _dirWatcher?.cancel();
    print('✓ SMS 파일 모니터링 서비스 종료됨');
  }
}

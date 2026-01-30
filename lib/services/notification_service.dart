import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 알림 서비스
/// 시스템 알림을 관리하고 전송합니다.
class NotificationService {
  static final NotificationService instance = NotificationService._init();

  NotificationService._init();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  /// 알림 서비스 초기화
  ///
  /// [onNotificationTap]: 알림 클릭 시 실행될 콜백
  Future<void> initialize({
    required Function(String payload) onNotificationTap,
  }) async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.payload != null) {
          onNotificationTap(response.payload!);
        }
      },
    );
  }

  /// 파일 감지 알림
  Future<void> showFileDetectedNotification({
    required String fileName,
    required String fileType, // 'audio' or 'sms'
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_file_detection',
      '파일 감지',
      channelDescription: '새로운 파일이 감지되었을 때 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    // 파일명에서 전화번호 추출
    final phoneNumber = fileName.split('.').first;

    String title;
    String body;

    if (fileType == 'audio') {
      title = '새로운 녹음 파일 감지!';
      body = '$fileName 파일이 분석을 시작합니다.';
    } else {
      title = '새로운 문자 메시지 감지!';
      body = '$phoneNumber으로부터 온 문자 메시지를 분석합니다.';
    }

    await _plugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: details,
      payload: 'file_detected:$fileName',
    );
  }

  /// 분석 완료 알림 (안전)
  Future<void> showAnalysisCompleteNotification({
    required String content,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_analysis_result',
      '분석 결과',
      channelDescription: '파일 분석 결과를 알려줍니다.',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: 1,
      title: '분석 완료',
      body: content,
      notificationDetails: details,
      payload: 'analysis_complete:$content',
    );
  }

  /// 보이스피싱 경고 알림
  Future<void> showPhishingWarningNotification({
    required String content,
    required String type, // 'call' or 'sms'
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_phishing_warning',
      '보이스피싱 경고',
      channelDescription: '보이스피싱이 의심되는 경우 알림을 보냅니다.',
      importance: Importance.max,
      priority: Priority.max,
      ticker: 'phishing_alert',
      color: Color(0xFFFF0000),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(
        '의심스러운 키워드가 다수 발견되었습니다. 탭하여 대처 방법을 확인하세요.',
        contentTitle: '보이스피싱 피해가 의심돼요!',
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

    final typeText = type == 'call' ? '통화' : '문자 메시지';

    await _plugin.show(
      id: 999,
      title: '⚠️ $typeText에서 보이스피싱 의심!',
      body: '의심 키워드가 발견되었습니다. 탭하여 대처 방법을 확인하세요.',
      notificationDetails: details,
      payload: 'phishing_detected:$content',
    );
  }

  /// 에러 알림
  Future<void> showErrorNotification({
    required String message,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'channel_error',
      '오류',
      channelDescription: '처리 중 발생한 오류를 알려줍니다.',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: 2,
      title: '처리 오류',
      body: message,
      notificationDetails: details,
      payload: 'error:$message',
    );
  }

  /// 모든 알림 취소
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 특정 ID의 알림 취소
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }
}

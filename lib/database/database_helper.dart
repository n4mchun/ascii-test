import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/call_record.dart';
import '../models/sms_record.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('phishing_detector.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 통화 기록 테이블
    await db.execute('''
      CREATE TABLE IF NOT EXISTS call_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_number TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        analyzed_at TEXT NOT NULL,
        transcription_text TEXT,
        risk_level TEXT NOT NULL,
        keyword_count INTEGER DEFAULT 0,
        is_phishing INTEGER DEFAULT 0
      )
    ''');

    // SMS 기록 테이블
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sms_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone_number TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        analyzed_at TEXT NOT NULL,
        message_content TEXT,
        risk_level TEXT NOT NULL,
        keyword_count INTEGER DEFAULT 0,
        is_phishing INTEGER DEFAULT 0
      )
    ''');

    print('데이터베이스 테이블 생성 완료');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // SMS 기록 테이블 추가 (이미 존재하면 무시)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sms_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          phone_number TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_path TEXT NOT NULL,
          analyzed_at TEXT NOT NULL,
          message_content TEXT,
          risk_level TEXT NOT NULL,
          keyword_count INTEGER DEFAULT 0,
          is_phishing INTEGER DEFAULT 0
        )
      ''');
      print('SMS 테이블 추가 완료');
    }
  }

  // 통화 기록 추가
  Future<CallRecord> createCallRecord(CallRecord record) async {
    final db = await database;
    final id = await db.insert('call_records', record.toMap());
    print('통화 기록 저장됨: ID $id, ${record.phoneNumber}');
    return record.copyWith(id: id);
  }

  // 모든 통화 기록 조회 (최신순)
  Future<List<CallRecord>> getAllCallRecords() async {
    final db = await database;
    final result = await db.query(
      'call_records',
      orderBy: 'analyzed_at DESC',
    );
    return result.map((map) => CallRecord.fromMap(map)).toList();
  }

  // 보이스피싱 의심 통화만 조회
  Future<List<CallRecord>> getPhishingCallRecords() async {
    final db = await database;
    final result = await db.query(
      'call_records',
      where: 'is_phishing = ?',
      whereArgs: [1],
      orderBy: 'analyzed_at DESC',
    );
    return result.map((map) => CallRecord.fromMap(map)).toList();
  }

  // 안전한 통화만 조회
  Future<List<CallRecord>> getSafeCallRecords() async {
    final db = await database;
    final result = await db.query(
      'call_records',
      where: 'is_phishing = ?',
      whereArgs: [0],
      orderBy: 'analyzed_at DESC',
    );
    return result.map((map) => CallRecord.fromMap(map)).toList();
  }

  // 특정 ID 기록 조회
  Future<CallRecord?> getCallRecord(int id) async {
    final db = await database;
    final maps = await db.query(
      'call_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return CallRecord.fromMap(maps.first);
    }
    return null;
  }

  // 통계 조회
  Future<Map<String, int>> getStatistics() async {
    final db = await database;

    // 총 분석 횟수
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM call_records');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    // 위험 감지 횟수
    final phishingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM call_records WHERE is_phishing = 1'
    );
    final phishing = Sqflite.firstIntValue(phishingResult) ?? 0;

    // 안전 통화 횟수
    final safe = total - phishing;

    return {
      'total': total,
      'phishing': phishing,
      'safe': safe,
    };
  }

  // 최근 위험 감지 통화 (최대 3개)
  Future<List<CallRecord>> getRecentPhishingCalls({int limit = 3}) async {
    final db = await database;
    final result = await db.query(
      'call_records',
      where: 'is_phishing = ?',
      whereArgs: [1],
      orderBy: 'analyzed_at DESC',
      limit: limit,
    );
    return result.map((map) => CallRecord.fromMap(map)).toList();
  }

  // 마지막 분석 시간 조회
  Future<DateTime?> getLastAnalyzedTime() async {
    final db = await database;
    final result = await db.query(
      'call_records',
      orderBy: 'analyzed_at DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return DateTime.parse(result.first['analyzed_at'] as String);
    }
    return null;
  }

  // 기록 삭제
  Future<int> deleteCallRecord(int id) async {
    final db = await database;
    return await db.delete(
      'call_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 모든 기록 삭제
  Future<void> deleteAllCallRecords() async {
    final db = await database;
    await db.delete('call_records');
  }

  // SMS 기록 추가
  Future<SmsRecord> createSmsRecord(SmsRecord record) async {
    final db = await database;
    final id = await db.insert('sms_records', record.toMap());
    print('SMS 기록 저장됨: ID $id, ${record.phoneNumber}');
    return record.copyWith(id: id);
  }

  // 모든 SMS 기록 조회 (최신순)
  Future<List<SmsRecord>> getAllSmsRecords() async {
    final db = await database;
    final result = await db.query(
      'sms_records',
      orderBy: 'analyzed_at DESC',
    );
    return result.map((map) => SmsRecord.fromMap(map)).toList();
  }

  // 보이스피싱 의심 SMS만 조회
  Future<List<SmsRecord>> getPhishingSmsRecords() async {
    final db = await database;
    final result = await db.query(
      'sms_records',
      where: 'is_phishing = ?',
      whereArgs: [1],
      orderBy: 'analyzed_at DESC',
    );
    return result.map((map) => SmsRecord.fromMap(map)).toList();
  }

  // 안전한 SMS만 조회
  Future<List<SmsRecord>> getSafeSmsRecords() async {
    final db = await database;
    final result = await db.query(
      'sms_records',
      where: 'is_phishing = ?',
      whereArgs: [0],
      orderBy: 'analyzed_at DESC',
    );
    return result.map((map) => SmsRecord.fromMap(map)).toList();
  }

  // 특정 ID SMS 기록 조회
  Future<SmsRecord?> getSmsRecord(int id) async {
    final db = await database;
    final maps = await db.query(
      'sms_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SmsRecord.fromMap(maps.first);
    }
    return null;
  }

  // SMS 통계 조회
  Future<Map<String, int>> getSmsStatistics() async {
    final db = await database;

    // 총 분석 횟수
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM sms_records');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    // 위험 감지 횟수
    final phishingResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM sms_records WHERE is_phishing = 1'
    );
    final phishing = Sqflite.firstIntValue(phishingResult) ?? 0;

    // 안전 SMS 횟수
    final safe = total - phishing;

    return {
      'total': total,
      'phishing': phishing,
      'safe': safe,
    };
  }

  // 최근 위험 감지 SMS (최대 3개)
  Future<List<SmsRecord>> getRecentPhishingSms({int limit = 3}) async {
    final db = await database;
    final result = await db.query(
      'sms_records',
      where: 'is_phishing = ?',
      whereArgs: [1],
      orderBy: 'analyzed_at DESC',
      limit: limit,
    );
    return result.map((map) => SmsRecord.fromMap(map)).toList();
  }

  // SMS 기록 삭제
  Future<int> deleteSmsRecord(int id) async {
    final db = await database;
    return await db.delete(
      'sms_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 모든 SMS 기록 삭제
  Future<void> deleteAllSmsRecords() async {
    final db = await database;
    await db.delete('sms_records');
  }

  // 데이터베이스 닫기
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

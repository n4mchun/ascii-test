import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/call_record.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 통화 기록 테이블
    await db.execute('''
      CREATE TABLE call_records (
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

    print('데이터베이스 테이블 생성 완료');
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

  // 데이터베이스 닫기
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

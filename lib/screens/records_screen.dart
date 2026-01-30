import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/call_record.dart';
import 'record_detail_screen.dart';

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<CallRecord> _allRecords = [];
  List<CallRecord> _filteredRecords = [];
  String _currentFilter = 'all'; // 'all', 'danger', 'safe'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  // 기록 로드
  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);

    try {
      final records = await _db.getAllCallRecords();
      setState(() {
        _allRecords = records;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      print('기록 로드 실패: $e');
      setState(() => _isLoading = false);
    }
  }

  // 필터 적용
  void _applyFilter() {
    switch (_currentFilter) {
      case 'danger':
        _filteredRecords = _allRecords.where((r) => r.isPhishing).toList();
        break;
      case 'safe':
        _filteredRecords = _allRecords.where((r) => !r.isPhishing).toList();
        break;
      case 'all':
      default:
        _filteredRecords = _allRecords;
        break;
    }
  }

  // 필터 변경
  void _changeFilter(String filter) {
    setState(() {
      _currentFilter = filter;
      _applyFilter();
    });
  }

  // 새로고침
  Future<void> _refreshRecords() async {
    await _loadRecords();
  }

  // 통계 계산
  Map<String, int> get _stats {
    return {
      'all': _allRecords.length,
      'danger': _allRecords.where((r) => r.isPhishing).length,
      'safe': _allRecords.where((r) => !r.isPhishing).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통화 분석 기록'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshRecords,
            tooltip: '새로고침',
          ),
        ],
      ),
      body: Column(
        children: [
          // 필터 버튼
          _buildFilterButtons(),

          // 기록 리스트
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecords.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshRecords,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredRecords.length,
                          itemBuilder: (context, index) {
                            return _buildRecordCard(_filteredRecords[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // 필터 버튼
  Widget _buildFilterButtons() {
    final stats = _stats;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              label: '전체',
              count: stats['all']!,
              filterValue: 'all',
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: '위험',
              count: stats['danger']!,
              filterValue: 'danger',
              color: Colors.red,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildFilterChip(
              label: '안전',
              count: stats['safe']!,
              filterValue: 'safe',
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // 필터 칩
  Widget _buildFilterChip({
    required String label,
    required int count,
    required String filterValue,
    required Color color,
  }) {
    final isSelected = _currentFilter == filterValue;

    return GestureDetector(
      onTap: () => _changeFilter(filterValue),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 빈 상태
  Widget _buildEmptyState() {
    String message;
    IconData icon;

    switch (_currentFilter) {
      case 'danger':
        message = '위험으로 분류된 통화가 없습니다.\n안전하게 통화하고 계시네요! 👍';
        icon = Icons.shield_outlined;
        break;
      case 'safe':
        message = '안전한 통화 기록이 없습니다.';
        icon = Icons.phone_disabled;
        break;
      default:
        message = '아직 분석된 통화가 없습니다.\n녹음 파일이 생성되면 자동으로 분석됩니다.';
        icon = Icons.phone_missed;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 기록 카드
  Widget _buildRecordCard(CallRecord record) {
    final dateFormat = DateFormat('yyyy년 MM월 dd일');
    final timeFormat = DateFormat('HH:mm:ss');
    final isPhishing = record.isPhishing;

    // 상태에 따른 색상
    final cardColor = isPhishing ? Colors.red.shade50 : Colors.green.shade50;
    final borderColor = isPhishing ? Colors.red.shade300 : Colors.green.shade300;
    final iconColor = isPhishing ? Colors.red.shade700 : Colors.green.shade700;
    final statusIcon = isPhishing ? Icons.warning_amber_rounded : Icons.check_circle_outline;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Icon(
            statusIcon,
            color: iconColor,
            size: 28,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record.phoneNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isPhishing)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '위험',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  dateFormat.format(record.analyzedAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  timeFormat.format(record.analyzedAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.insert_drive_file, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.fileName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (isPhishing) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: Colors.red.shade700),
                  const SizedBox(width: 4),
                  Text(
                    '위험 키워드 ${record.keywordCount}개 발견',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey.shade400,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecordDetailScreen(record: record),
            ),
          );
        },
      ),
    );
  }
}

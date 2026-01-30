import 'dart:async'; // StreamSubscription을 위해 필요
import 'dart:convert'; // jsonDecode용
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http; // http 패키지 추가

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Lister & Watcher',
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

  // 파일 시스템 변경 감지를 위한 구독 객체
  StreamSubscription<FileSystemEvent>? _dirWatcher;

  final String _apiKey = 'sk-proj-YOUR_OPENAI_API_KEY_HERE';

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  @override
  void dispose() {
    // 앱이 종료되거나 화면이 바뀔 때 감시를 중단해야 메모리 누수가 없습니다.
    _dirWatcher?.cancel();
    super.dispose();
  }

  Future<void> _checkPermissionAndInit() async {
    // Android 11 이상 관리 권한
    if (await Permission.manageExternalStorage.request().isGranted) {
      _listFiles();
      _startWatching(); // 권한이 있으면 감시 시작
    } else if (await Permission.storage.request().isGranted) {
      _listFiles();
      _startWatching();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('권한이 필요합니다.')),
        );
      }
    }
  }

  void _listFiles() {
    final dir = Directory(_targetPath);
    if (dir.existsSync()) {
      setState(() {
        // 최신순으로 정렬해서 보여주기 (선택사항)
        _files = dir.listSync(recursive: false).toList()
          ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      });
    }
  }

  void _startWatching() {
    final dir = Directory(_targetPath);
    if (!dir.existsSync()) return;

    final targetPattern = RegExp(r'^\d{11}\.mp3$');

    _dirWatcher = dir.watch(events: FileSystemEvent.create).listen((event) async {
      final fileName = event.path.split('/').last;

      if (event.type == FileSystemEvent.create) {
        if (targetPattern.hasMatch(fileName)) {
          print('★ 타겟 파일 감지됨: $fileName');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('변환 중입니다... 잠시만 기다려주세요.')),
            );
          }

          // [추가됨] 텍스트 변환 요청
          final file = File(event.path);
          await _transcribeAudio(file);

        }
      }
      if (mounted) _listFiles();
    });
  }

  // [핵심 기능] OpenAI Whisper API 호출 함수
  Future<void> _transcribeAudio(File audioFile) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

    try {
      // Multipart Request 생성
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = 'whisper-1' // 사용할 모델
        ..fields['language'] = 'ko';    // 한국어 지정 (선택사항)

      // 파일 첨부
      request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      print('서버로 전송 중...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 성공 시 응답 파싱
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final text = jsonResponse['text'];

        print('▼▼▼ 변환된 텍스트 ▼▼▼');
        print(text);
        print('▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲');

        if (mounted) {
          // 다이얼로그로 결과 보여주기
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('변환 성공'),
              content: SingleChildScrollView(child: Text(text)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기')
                ),
              ],
            ),
          );
        }
      } else {
        print('에러 발생: ${response.statusCode} / ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('변환 실패: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('네트워크 오류: $e');
    }
  }

  // [수정됨] 테스트를 위해 '01012345678.mp3' 형식의 파일 생성
  Future<void> _createTargetFile() async {
    // 임의의 11자리 전화번호 생성 (예: 01012345678)
    final randomNum = '010${(10000000 + DateTime.now().millisecondsSinceEpoch % 90000000).toString().substring(0, 8)}';
    final fileName = '$randomNum.mp3';
    final newFile = File('$_targetPath/$fileName');

    try {
      await newFile.writeAsString('가짜 음성 파일 내용입니다.');
      // 파일이 생성되면 위 _startWatching에서 자동으로 감지합니다.
    } catch (e) {
      print('생성 실패: $e');
    }
  }

  Future<void> _createTestFile() async {
    final fileName = 'test_${DateTime.now().millisecondsSinceEpoch}.txt';
    final newFile = File('$_targetPath/$fileName');

    try {
      await newFile.writeAsString('이것은 테스트 파일입니다.\n생성 시간: ${DateTime.now()}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 생성 완료')),
        );
      }
      // watch()가 작동 중이므로 여기서 _listFiles()를 호출하지 않아도
      // 자동으로 리스트가 갱신되어야 합니다.
    } catch (e) {
      print('파일 생성 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일 생성 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time File Watcher'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _files.isEmpty
          ? const Center(child: Text('파일이 없습니다.'))
          : ListView.builder(
        itemCount: _files.length,
        itemBuilder: (context, index) {
          final file = _files[index];
          final fileName = file.path.split('/').last;
          final stat = file.statSync(); // 파일 정보 가져오기

          return ListTile(
            leading: const Icon(Icons.description),
            title: Text(fileName),
            subtitle: Text('크기: ${stat.size} bytes\n수정: ${stat.modified}'),
            isThreeLine: true,
            onTap: () {
              print(file.path);
            },
          );
        },
      ),
      // 버튼을 누르면 테스트 파일 생성
      floatingActionButton: FloatingActionButton(
        onPressed: _createTargetFile,
        tooltip: '테스트 파일 생성',
        child: const Icon(Icons.add),
      ),
    );
  }
}
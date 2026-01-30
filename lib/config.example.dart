// API 키 설정 파일 예제
// 사용 방법:
// 1. 이 파일을 'config.dart'로 복사하세요
// 2. config.dart 파일을 열고 실제 API 키를 입력하세요
// 3. config.dart는 .gitignore에 의해 GitHub에 업로드되지 않습니다

class ApiConfig {
  // OpenAI API 키를 여기에 입력하세요
  // https://platform.openai.com/api-keys 에서 발급받을 수 있습니다
  static const String openaiApiKey = 'sk-proj-YOUR_OPENAI_API_KEY_HERE';

  // 다른 API 키가 필요한 경우 여기에 추가하세요
  // static const String anotherApiKey = 'YOUR_API_KEY';
}

/// App-wide constants.
///
/// [apiBaseUrl] is read from a compile-time define so the same build can be
/// pointed at different backends without code changes:
///
///   flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api
///   flutter build web --dart-define=API_BASE_URL=https://api.yourdomain.com/api
///
/// If it's not supplied, requests fall back to the local Flask dev server —
/// and every data repository falls back further still to bundled
/// placeholder content when the API can't be reached at all (see
/// lib/data/api_repository.dart), so the site is always presentable even
/// before a backend is deployed.
class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000/api',
  );

  static const String siteName = 'Ali Juma';
  static const String siteTagline = 'AI · Machine Learning · Cybersecurity Research';

  static const String githubUrl = 'https://github.com/your-handle';
  static const String linkedinUrl = 'https://www.linkedin.com/in/your-handle';
  static const String contactEmail = 'ajchemengu@gmail.com';
}

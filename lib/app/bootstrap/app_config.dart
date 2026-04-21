enum AppBackendMode { fake, supabase }

const kAuthRedirectScheme = 'ceocommunicationtrainer';
const kAuthRedirectHost = 'auth-callback';
const kDefaultSupabaseUrl = 'https://cirbtiruwefyhqthbcyc.supabase.co';
const kDefaultSupabasePublishableKey =
    'sb_publishable_y7kJZxrpoBBmBSesZv1xpQ_OhqcPvpV';

class AppConfig {
  const AppConfig({
    required this.backendMode,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  final AppBackendMode backendMode;
  final String? supabaseUrl;
  final String? supabaseAnonKey;

  bool get useFakeBackend => backendMode == AppBackendMode.fake;
  String get authRedirectUrl => '$kAuthRedirectScheme://$kAuthRedirectHost';

  factory AppConfig.fromEnvironment() {
    const useFakeBackend = String.fromEnvironment(
      'APP_USE_FAKE_BACKEND',
      defaultValue: '',
    );
    const supabaseUrl = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: kDefaultSupabaseUrl,
    );
    const supabaseAnonKey = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    );
    const supabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue: kDefaultSupabasePublishableKey,
    );
    const nextPublicSupabaseUrl = String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_URL',
      defaultValue: kDefaultSupabaseUrl,
    );
    const nextPublicSupabasePublishableKey = String.fromEnvironment(
      'NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
      defaultValue: kDefaultSupabasePublishableKey,
    );

    final resolvedUrl = supabaseUrl.isNotEmpty
        ? supabaseUrl
        : nextPublicSupabaseUrl;
    final resolvedKey = supabaseAnonKey.isNotEmpty
        ? supabaseAnonKey
        : (supabasePublishableKey.isNotEmpty
              ? supabasePublishableKey
              : nextPublicSupabasePublishableKey);
    final forceFakeBackend = useFakeBackend.toLowerCase() == 'true';

    final mode =
        !forceFakeBackend &&
            resolvedUrl.isNotEmpty &&
            resolvedKey.isNotEmpty
        ? AppBackendMode.supabase
        : AppBackendMode.fake;

    return AppConfig(
      backendMode: mode,
      supabaseUrl: resolvedUrl.isEmpty ? null : resolvedUrl,
      supabaseAnonKey: resolvedKey.isEmpty ? null : resolvedKey,
    );
  }
}

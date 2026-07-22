class AppEnvironment {
  /// Default managed Supabase URL. Can be overridden at build time via --dart-define.
  static const String defaultSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://cxrlptsngvrqxyahahyd.supabase.co',
  );

  /// Default managed Supabase Anon Key. Can be overridden at build time via --dart-define.
  static const String defaultSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_6MZMaFJ4oVr7Dt3xQE8MOQ_H0BbuZ5Q',
  );
}

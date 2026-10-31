class AppRoutes {
  AppRoutes._();

  static const String welcome = '/';
  static const String setup = '/setup';
  static const String dashboard = '/dashboard';
  static const String notes = '/notes';
  static const String newNote = '/notes/new';
  static const String search = '/search';
  static const String settings = '/settings';

  static String note(String id) => '/notes/$id';
  static String record(String id) => '/notes/$id/record';
  static String transcript(String id) => '/notes/$id/transcript';
  static String structured(String id) => '/notes/$id/structured';
}

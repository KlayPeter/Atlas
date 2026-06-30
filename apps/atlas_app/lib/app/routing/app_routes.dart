class AppRoutes {
  const AppRoutes._();

  static const library = '/library';
  static const reader = '/reader/:documentId';
  static const htmlPreview = '/html-preview/:exportId';
  static const settings = '/settings';

  static String readerPath(String documentId) => '/reader/$documentId';

  static String htmlPreviewPath(String exportId) => '/html-preview/$exportId';
}

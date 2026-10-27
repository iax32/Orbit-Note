bool protectedUniversityPath(String path) {
  final clean = path.replaceAll('\\', '/').toLowerCase();
  return clean == 'pom.xml' ||
      clean.startsWith('.gitlab/') ||
      clean.startsWith('src/test/') ||
      clean.startsWith('src/main/resources/');
}

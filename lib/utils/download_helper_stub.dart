/// Stub implementation for non-web platforms.
void downloadCsvFile(String csvContent, String fileName) {
  // No-op on mobile/desktop — CSV export is web-only.
  throw UnsupportedError('CSV download is only supported on web.');
}

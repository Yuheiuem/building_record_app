part of '../building_detail_page.dart';

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '日時不明';
  }
  final DateTime local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

String _locationSourceLabel(String source) {
  return switch (source) {
    'gps' => 'GPS',
    'manual' => '手動指定',
    'building_fallback' => '建物代表位置',
    'test' => 'テスト位置',
    _ => source,
  };
}

part of '../record_page.dart';

String _formatElapsed(Duration duration) {
  return _formatMilliseconds(duration.inMilliseconds);
}

String _formatClockDuration(Duration duration) {
  final int totalSeconds = math.max(0, duration.inSeconds);
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String secondsText = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final String minutesText = minutes.toString().padLeft(2, '0');
    return '$hours:$minutesText:$secondsText';
  }
  return '$minutes:$secondsText';
}

String _formatMilliseconds(int milliseconds) {
  if (milliseconds < 1000) {
    return '$milliseconds ms';
  }
  return '${(milliseconds / 1000).toStringAsFixed(1)}秒';
}

String _authenticationModeLabel(String mode) {
  return switch (mode) {
    'cache' => 'キャッシュ',
    'tokeninfo' => 'tokeninfo',
    _ => mode,
  };
}

String _formatBytes(int byteSize) {
  if (byteSize < 1024) {
    return '$byteSize B';
  }

  final double kilobytes = byteSize / 1024;
  if (kilobytes < 1024) {
    return '${kilobytes.toStringAsFixed(1)} KB';
  }

  final double megabytes = kilobytes / 1024;
  return '${megabytes.toStringAsFixed(1)} MB';
}

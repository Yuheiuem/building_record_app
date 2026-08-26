part of '../record_page.dart';

class _UploadPerformanceDetails extends StatelessWidget {
  const _UploadPerformanceDetails({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final List<({RecordDraftPhoto photo, RecordUploadPerformance performance})>
    entries =
        <({RecordDraftPhoto photo, RecordUploadPerformance performance})>[];

    for (final RecordDraftPhoto photo in controller.photos) {
      final RecordUploadPerformance? performance = controller
          .photoUploadResult(photo.photoId)
          ?.performance;
      if (performance != null) {
        entries.add((photo: photo, performance: performance));
      }
    }

    final List<String> phaseDetails = _submissionPhaseDetails(controller);
    final RecordPhasePerformance? beginPerformance =
        controller.beginRecordPerformance;
    final RecordPhasePerformance? finalizePerformance =
        controller.finalizeRecordPerformance;
    if (entries.isEmpty &&
        phaseDetails.isEmpty &&
        beginPerformance == null &&
        finalizePerformance == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          key: const Key('record-upload-performance'),
          title: const Text('送信時間の内訳'),
          subtitle: const Text('準備・写真送信・確定・Drive保存の詳細を確認できます。'),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            if (phaseDetails.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Text(
                      '保存処理全体',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(phaseDetails.join(' / ')),
                  ],
                ),
              ),
            if (beginPerformance != null)
              _RecordPhasePerformanceSection(
                key: const Key('record-begin-performance'),
                title: '準備通信のサーバー内訳',
                details: _beginRecordPerformanceDetails(beginPerformance),
              ),
            if (finalizePerformance != null)
              _RecordPhasePerformanceSection(
                key: const Key('record-finalize-performance'),
                title: '確定通信のサーバー内訳',
                details: _finalizeRecordPerformanceDetails(finalizePerformance),
              ),
            ...entries.map((entry) {
              final RecordUploadPerformance performance = entry.performance;
              final List<String> clientDetails = <String>[
                if (performance.clientOriginalBase64Ms > 0)
                  '元画像Base64 '
                      '${_formatMilliseconds(performance.clientOriginalBase64Ms)}',
                if (performance.clientThumbnailCreateMs > 0)
                  'サムネ作成 '
                      '${_formatMilliseconds(performance.clientThumbnailCreateMs)}',
                if (performance.clientThumbnailBase64Ms > 0)
                  'サムネBase64 '
                      '${_formatMilliseconds(performance.clientThumbnailBase64Ms)}',
              ];
              final List<String> serverDetails = <String>[
                if (performance.authenticationMode != null)
                  '認証 '
                      '${_authenticationModeLabel(performance.authenticationMode!)}',
                if (performance.authenticationMs != null)
                  '認証処理 '
                      '${_formatMilliseconds(performance.authenticationMs!)}',
                if (performance.base64DecodeMs != null)
                  '元画像復号 '
                      '${_formatMilliseconds(performance.base64DecodeMs!)}',
                if (performance.thumbnailBase64DecodeMs != null &&
                    performance.thumbnailBase64DecodeMs! > 0)
                  'サムネ復号 '
                      '${_formatMilliseconds(performance.thumbnailBase64DecodeMs!)}',
                if (performance.spreadsheetOpenMs != null &&
                    performance.spreadsheetOpenMs! > 0)
                  'Spreadsheet接続 '
                      '${_formatMilliseconds(performance.spreadsheetOpenMs!)}',
                if (performance.lockWaitMs != null &&
                    performance.lockWaitMs! > 0)
                  'ロック待ち '
                      '${_formatMilliseconds(performance.lockWaitMs!)}',
                if (performance.draftPreparationMs != null &&
                    performance.draftPreparationMs! > 0)
                  '準備 '
                      '${_formatMilliseconds(performance.draftPreparationMs!)}',
                if (performance.lookupMs != null)
                  '検索 ${_formatMilliseconds(performance.lookupMs!)}',
                if (performance.driveSaveMs != null)
                  '元画像Drive '
                      '${_formatMilliseconds(performance.driveSaveMs!)}',
                if (performance.thumbnailDriveSaveMs != null &&
                    performance.thumbnailDriveSaveMs! > 0)
                  'サムネDrive '
                      '${_formatMilliseconds(performance.thumbnailDriveSaveMs!)}',
                if (performance.sheetWriteMs != null)
                  'Sheets ${_formatMilliseconds(performance.sheetWriteMs!)}',
                if (performance.responseCacheMs != null &&
                    performance.responseCacheMs! > 0)
                  '結果キャッシュ '
                      '${_formatMilliseconds(performance.responseCacheMs!)}',
                if (performance.finalizeMs != null &&
                    performance.finalizeMs! > 0)
                  '確定 ${_formatMilliseconds(performance.finalizeMs!)}',
                if (performance.handlerTotalMs != null)
                  'サーバー合計 '
                      '${_formatMilliseconds(performance.handlerTotalMs!)}',
              ];

              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      entry.photo.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ブラウザ準備 '
                      '${_formatMilliseconds(performance.clientEncodeMs)} / '
                      '通信全体 '
                      '${_formatMilliseconds(performance.clientRequestMs)}',
                    ),
                    if (clientDetails.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(clientDetails.join(' / ')),
                    ],
                    if (serverDetails.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(serverDetails.join(' / ')),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _RecordPhasePerformanceSection extends StatelessWidget {
  const _RecordPhasePerformanceSection({
    required this.title,
    required this.details,
    super.key,
  });

  final String title;
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    if (details.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(details.join(' / ')),
        ],
      ),
    );
  }
}

List<String> _beginRecordPerformanceDetails(
  RecordPhasePerformance performance,
) {
  return <String>[
    ..._recordPhaseCommonDetails(performance),
    if (performance.requestLookupMs != null)
      'Requests検索 ${_formatMilliseconds(performance.requestLookupMs!)}',
    if (performance.tagValidationMs != null)
      'タグ検証 ${_formatMilliseconds(performance.tagValidationMs!)}',
    if (performance.buildingEnsureMs != null)
      '建物処理 ${_formatMilliseconds(performance.buildingEnsureMs!)}',
    if (performance.visitEnsureMs != null)
      'Visit処理 ${_formatMilliseconds(performance.visitEnsureMs!)}',
    if (performance.uploadContextCacheMs != null)
      '写真送信用キャッシュ '
          '${_formatMilliseconds(performance.uploadContextCacheMs!)}',
    if (performance.requestLogWriteMs != null)
      'Requests書込 ${_formatMilliseconds(performance.requestLogWriteMs!)}',
    if (performance.unclassifiedMs != null)
      '未分類 ${_formatMilliseconds(performance.unclassifiedMs!)}',
    if (performance.handlerTotalMs != null)
      'サーバー合計 ${_formatMilliseconds(performance.handlerTotalMs!)}',
  ];
}

List<String> _finalizeRecordPerformanceDetails(
  RecordPhasePerformance performance,
) {
  return <String>[
    ..._recordPhaseCommonDetails(performance),
    if (performance.requestLookupMs != null)
      'Requests検索 ${_formatMilliseconds(performance.requestLookupMs!)}',
    if (performance.buildingLookupMs != null)
      'Buildings検索 ${_formatMilliseconds(performance.buildingLookupMs!)}',
    if (performance.visitLookupMs != null)
      'Visits検索 ${_formatMilliseconds(performance.visitLookupMs!)}',
    if (performance.photosLookupMs != null)
      'Photos検索 ${_formatMilliseconds(performance.photosLookupMs!)}',
    if (performance.visitUpdateMs != null)
      'Visit更新 ${_formatMilliseconds(performance.visitUpdateMs!)}',
    if (performance.buildingUpdateMs != null)
      'Building更新 ${_formatMilliseconds(performance.buildingUpdateMs!)}',
    if (performance.requestLogWriteMs != null)
      'Requests書込 ${_formatMilliseconds(performance.requestLogWriteMs!)}',
    if (performance.unclassifiedMs != null)
      '未分類 ${_formatMilliseconds(performance.unclassifiedMs!)}',
    if (performance.handlerTotalMs != null)
      'サーバー合計 ${_formatMilliseconds(performance.handlerTotalMs!)}',
  ];
}

List<String> _recordPhaseCommonDetails(RecordPhasePerformance performance) {
  return <String>[
    if (performance.authenticationMode != null)
      '認証 ${_authenticationModeLabel(performance.authenticationMode!)}',
    if (performance.authenticationMs != null)
      '認証処理 ${_formatMilliseconds(performance.authenticationMs!)}',
    if (performance.normalizeMs != null)
      '正規化 ${_formatMilliseconds(performance.normalizeMs!)}',
    if (performance.spreadsheetOpenMs != null)
      'Spreadsheet接続 '
          '${_formatMilliseconds(performance.spreadsheetOpenMs!)}',
    if (performance.lockWaitMs != null)
      'ロック待ち ${_formatMilliseconds(performance.lockWaitMs!)}',
  ];
}

List<String> _submissionPhaseDetails(RecordDraftController controller) {
  final List<String> result = <String>[];
  final Duration? combined = controller.lastCombinedSaveDuration;
  if (combined != null) {
    result.add('一括保存通信 ${_formatElapsed(combined)}');
  } else {
    final Duration? preparation = controller.lastPreparationDuration;
    final Duration? photoUpload = controller.lastPhotoUploadDuration;
    final Duration? finalize = controller.lastFinalizeDuration;
    if (preparation != null) {
      result.add('準備通信 ${_formatElapsed(preparation)}');
    }
    if (photoUpload != null) {
      result.add('写真送信区間 ${_formatElapsed(photoUpload)}');
    }
    if (finalize != null) {
      result.add('確定通信 ${_formatElapsed(finalize)}');
    }
  }

  final Duration? total = controller.lastSubmissionDuration;
  if (total != null) {
    final int measuredMs =
        <Duration?>[
          combined,
          controller.lastPreparationDuration,
          controller.lastPhotoUploadDuration,
          controller.lastFinalizeDuration,
        ].whereType<Duration>().fold<int>(
          0,
          (int sum, Duration duration) => sum + duration.inMilliseconds,
        );
    final int otherMs = total.inMilliseconds - measuredMs;
    if (otherMs > 0) {
      result.add('画面側その他 ${_formatMilliseconds(otherMs)}');
    }
  }
  return result;
}

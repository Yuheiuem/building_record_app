part of '../record_page.dart';

class _RecordSaveSection extends StatelessWidget {
  const _RecordSaveSection({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool showPhotoProgress =
        controller.isDraftLocked && controller.photos.isNotEmpty;
    final String submitButtonLabel;
    if (controller.submissionPhase == RecordSubmissionPhase.failed) {
      submitButtonLabel = controller.failedPhotoCount > 0
          ? '失敗した写真を再送'
          : '保存を再試行';
    } else if (controller.isSubmitting) {
      submitButtonLabel = '保存しています';
    } else {
      submitButtonLabel = '記録を保存';
    }

    return Card(
      key: const Key('record-save-section'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_upload_outlined,
                  color: colors.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '記録を保存',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('建物と訪問を準備し、写真をまとめて非公開Driveへ保存します。'),
            const SizedBox(height: 16),
            _SubmissionStatusPanel(controller: controller),
            if (controller.isSubmitting &&
                controller.submissionStartedAt != null) ...<Widget>[
              const SizedBox(height: 10),
              _LiveSubmissionElapsed(
                startedAt: controller.submissionStartedAt!,
              ),
            ],
            if (showPhotoProgress) ...<Widget>[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value:
                    controller.submissionPhase ==
                            RecordSubmissionPhase.starting ||
                        controller.submissionPhase ==
                            RecordSubmissionPhase.finalizing
                    ? null
                    : controller.submissionProgress,
              ),
              const SizedBox(height: 8),
              Text(
                '写真 ${controller.uploadedPhotoCount}/${controller.photoCount}枚を送信済み',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              _PhotoTransferSummary(controller: controller),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.7,
                ),
                child: ListView.builder(
                  key: const Key('record-photo-upload-progress-scroll'),
                  primary: false,
                  shrinkWrap: true,
                  itemCount: controller.photos.length,
                  itemBuilder: (BuildContext context, int index) {
                    final RecordDraftPhoto photo = controller.photos[index];
                    return _PhotoUploadProgressRow(
                      photo: photo,
                      status: controller.photoUploadStatus(photo.photoId),
                      performance: controller
                          .photoUploadResult(photo.photoId)
                          ?.performance,
                    );
                  },
                ),
              ),
            ],
            if (controller.lastSubmissionDuration != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '今回の保存処理：${_formatElapsed(controller.lastSubmissionDuration!)}',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            _UploadPerformanceDetails(controller: controller),
            if (controller.submissionErrorMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(Icons.error_outline, color: colors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            controller.submissionErrorMessage!,
                            style: TextStyle(
                              color: colors.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (controller.submissionErrorDetail != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        controller.submissionErrorDetail!,
                        style: TextStyle(color: colors.onErrorContainer),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (controller.submissionNoticeMessage != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.check_circle_outline, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.submissionNoticeMessage!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (controller.submissionSucceeded)
              FilledButton.icon(
                key: const Key('start-new-record'),
                onPressed: controller.startNewRecord,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('新しい記録を始める'),
              )
            else
              FilledButton.icon(
                key: const Key('submit-record'),
                onPressed: controller.canSubmitRecord
                    ? controller.submitRecord
                    : null,
                icon: controller.isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        controller.submissionPhase ==
                                RecordSubmissionPhase.failed
                            ? Icons.refresh_outlined
                            : Icons.cloud_upload_outlined,
                      ),
                label: Text(submitButtonLabel),
              ),
            if (controller.isDraftLocked && !controller.submissionSucceeded)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '送信開始後は下書きを変更せず、同じボタンから再送してください。',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmissionStatusPanel extends StatelessWidget {
  const _SubmissionStatusPanel({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, String label}) phaseDetails =
        switch (controller.submissionPhase) {
          RecordSubmissionPhase.idle => (
            icon: Icons.edit_note_outlined,
            label: '下書きの入力内容を確認してください。',
          ),
          RecordSubmissionPhase.starting => (
            icon: Icons.inventory_2_outlined,
            label: '建物と訪問の保存準備をしています。',
          ),
          RecordSubmissionPhase.uploading => (
            icon: Icons.photo_library_outlined,
            label: '写真をまとめて送信しています。',
          ),
          RecordSubmissionPhase.finalizing => (
            icon: Icons.fact_check_outlined,
            label: '保存枚数を確認して記録を確定しています。',
          ),
          RecordSubmissionPhase.failed => (
            icon: Icons.sync_problem_outlined,
            label: '入力内容と送信済み写真を保持しています。',
          ),
          RecordSubmissionPhase.succeeded => (
            icon: Icons.task_alt_outlined,
            label: '記録の保存が完了しました。',
          ),
        };
    final ({IconData icon, String label}) details = (
      icon: phaseDetails.icon,
      label: controller.submissionOperationMessage ?? phaseDetails.label,
    );

    return Container(
      key: const Key('record-operation-status'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Icon(details.icon),
          const SizedBox(width: 10),
          Expanded(child: Text(details.label)),
        ],
      ),
    );
  }
}

class _PhotoTransferSummary extends StatelessWidget {
  const _PhotoTransferSummary({required this.controller});

  final RecordDraftController controller;

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = <Widget>[
      _TransferCount(label: '完了', count: controller.uploadedPhotoCount),
      _TransferCount(label: '送信中', count: controller.uploadingPhotoCount),
      _TransferCount(label: '待機', count: controller.pendingPhotoCount),
      if (controller.failedPhotoCount > 0)
        _TransferCount(label: '再送待ち', count: controller.failedPhotoCount),
    ];

    return Wrap(
      key: const Key('record-transfer-summary'),
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: items,
    );
  }
}

class _TransferCount extends StatelessWidget {
  const _TransferCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label $count枚'),
    );
  }
}

class _LiveSubmissionElapsed extends StatefulWidget {
  const _LiveSubmissionElapsed({required this.startedAt});

  final DateTime startedAt;

  @override
  State<_LiveSubmissionElapsed> createState() => _LiveSubmissionElapsedState();
}

class _LiveSubmissionElapsedState extends State<_LiveSubmissionElapsed> {
  Timer? _timer;
  late Duration _elapsed;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.startedAt);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _elapsed = DateTime.now().difference(widget.startedAt);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _LiveSubmissionElapsed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startedAt != widget.startedAt) {
      _elapsed = DateTime.now().difference(widget.startedAt);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      key: const Key('record-live-submission-elapsed'),
      '経過 ${_formatClockDuration(_elapsed)}',
      textAlign: TextAlign.center,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

class _PhotoUploadProgressRow extends StatelessWidget {
  const _PhotoUploadProgressRow({
    required this.photo,
    required this.status,
    required this.performance,
  });

  final RecordDraftPhoto photo;
  final RecordPhotoUploadStatus status;
  final RecordUploadPerformance? performance;

  @override
  Widget build(BuildContext context) {
    final ({IconData icon, String label}) details = switch (status) {
      RecordPhotoUploadStatus.pending => (
        icon: Icons.schedule_outlined,
        label: '未送信',
      ),
      RecordPhotoUploadStatus.uploading => (
        icon: Icons.sync_outlined,
        label: '送信中',
      ),
      RecordPhotoUploadStatus.uploaded => (
        icon: Icons.check_circle_outline,
        label: '送信済み',
      ),
      RecordPhotoUploadStatus.failed => (
        icon: Icons.error_outline,
        label: '再送待ち',
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Icon(details.icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              photo.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status == RecordPhotoUploadStatus.uploaded && performance != null
                ? '${details.label} ${_formatElapsed(performance!.clientTotalDuration)}'
                : details.label,
          ),
        ],
      ),
    );
  }
}

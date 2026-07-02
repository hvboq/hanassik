import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'hanassik_store.dart';
import 'models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<HanassikStore> _storeFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = HanassikStore.load();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HanassikStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SafeArea(
            bottom: false,
            child: Scaffold(
              body: LoadErrorState(),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SafeArea(
            bottom: false,
            child: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return AnimatedBuilder(
          animation: snapshot.data!,
          builder: (context, _) => HanassikHome(store: snapshot.data!),
        );
      },
    );
  }
}

class LoadErrorState extends StatelessWidget {
  const LoadErrorState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.error_outline,
      title: '데이터를 불러오지 못했습니다',
      message: '브라우저 저장소를 확인한 뒤 앱을 다시 열어주세요.',
    );
  }
}

class HanassikHome extends StatelessWidget {
  const HanassikHome({super.key, required this.store});

  final HanassikStore store;

  @override
  Widget build(BuildContext context) {
    final activeCount = store.runs.where((run) => !run.isDone).length;

    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);

          return AnimatedBuilder(
            animation: tabController,
            builder: (context, _) {
              final isTemplatesTab = tabController.index == 1;
              final canShowCreateButton = isTemplatesTab || store.runs.isEmpty;

              return SafeArea(
                bottom: false,
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('하나씩'),
                    bottom: const TabBar(
                      tabs: [
                        Tab(text: '진행 업무'),
                        Tab(text: '템플릿'),
                      ],
                    ),
                  ),
                  floatingActionButton: canShowCreateButton
                      ? FloatingActionButton.extended(
                          onPressed: () => _showTemplateSheet(context),
                          icon: const Icon(Icons.add),
                          label: const Text('템플릿 만들기'),
                        )
                      : null,
                  body: Column(
                    children: [
                      if (store.recoveredFromStorage)
                        MaterialBanner(
                          content: const Text(
                            '일부 저장 데이터가 손상되어 사용할 수 있는 항목만 복구했습니다.',
                          ),
                          leading: const Icon(Icons.info_outline),
                          actions: [
                            TextButton(
                              onPressed: store.dismissRecoveryNotice,
                              child: const Text('확인'),
                            ),
                          ],
                        ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            RunsView(store: store, activeCount: activeCount),
                            TemplatesView(store: store),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showTemplateSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddTemplateSheet(store: store),
    );
  }
}

class RunsView extends StatelessWidget {
  const RunsView({
    super.key,
    required this.store,
    required this.activeCount,
  });

  final HanassikStore store;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    if (store.runs.isEmpty) {
      return const EmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        title: '진행 중인 업무가 없습니다',
        message: '템플릿 탭에서 반복 업무를 시작하면 체크리스트가 만들어집니다.',
        actionLabel: '템플릿 보기',
      );
    }

    final activeRuns = store.runs.where((run) => !run.isDone).toList();
    final doneRuns = store.runs.where((run) => run.isDone).toList();
    final totalStepCount = store.runs.fold<int>(
      0,
      (total, run) => total + run.steps.length,
    );
    final completedStepCount = store.runs.fold<int>(
      0,
      (total, run) => total + run.completedCount,
    );
    final remainingStepCount = activeRuns.fold<int>(
      0,
      (total, run) => total + run.remainingCount,
    );
    final overallProgress =
        totalStepCount == 0 ? 0.0 : completedStepCount / totalStepCount;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        RunsSummary(
          activeCount: activeCount,
          completedCount: doneRuns.length,
          remainingStepCount: remainingStepCount,
          progress: overallProgress,
        ),
        const SizedBox(height: 20),
        Text(
          '진행 중 $activeCount개',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final run in activeRuns)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('dismiss_run_${run.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.only(right: 20),
                alignment: Alignment.centerRight,
                child: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.onError),
              ),
              confirmDismiss: (_) => _confirmDelete(
                context,
                title: '진행 업무 삭제',
                message: '"${run.title}" 진행 기록을 삭제할까요?',
              ),
              onDismissed: (_) async {
                try {
                  await store.deleteRun(run.id);
                } on Object {
                  if (context.mounted) {
                    _showError(context, '진행 업무를 삭제하지 못했습니다.');
                  }
                }
              },
              child: RunCard(
                run: run,
                onToggle: (index, value) =>
                    _toggleRunStep(context, run, index, value),
                onEditDetails: () => _editRunDetails(context, run),
                onAddAttachments: () => _addAttachments(context, run),
                onRemoveAttachment: (attachment) =>
                    _removeAttachment(context, run, attachment),
              ),
            ),
          ),
        if (doneRuns.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '완료된 업무 ${doneRuns.length}개',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => _deleteCompletedRuns(context, doneRuns.length),
                icon: const Icon(Icons.delete_sweep_outlined),
                label: const Text('완료 기록 정리'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final run in doneRuns)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Dismissible(
                key: ValueKey('dismiss_run_${run.id}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.only(right: 20),
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.delete,
                      color: Theme.of(context).colorScheme.onError),
                ),
                confirmDismiss: (_) => _confirmDelete(
                  context,
                  title: '진행 업무 삭제',
                  message: '"${run.title}" 진행 기록을 삭제할까요?',
                ),
                onDismissed: (_) async {
                  try {
                    await store.deleteRun(run.id);
                  } on Object {
                    if (context.mounted) {
                      _showError(context, '진행 업무를 삭제하지 못했습니다.');
                    }
                  }
                },
                child: RunCard(
                  run: run,
                  onToggle: (index, value) =>
                      _toggleRunStep(context, run, index, value),
                  onAddAttachments: () => _addAttachments(context, run),
                  onRemoveAttachment: (attachment) =>
                      _removeAttachment(context, run, attachment),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _editRunDetails(BuildContext context, WorkRun run) async {
    final updatedRun = await showModalBottomSheet<_RunDetailsResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => EditRunDetailsSheet(
        store: store,
        run: run,
      ),
    );
    if (updatedRun == null || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('"${updatedRun.title}" 업무 정보를 수정했습니다.')),
      );
  }

  Future<void> _toggleRunStep(
    BuildContext context,
    WorkRun run,
    int index,
    bool value,
  ) async {
    try {
      await store.toggleStep(run.id, index, value);
    } on Object {
      if (context.mounted) {
        _showError(context, '체크 상태를 저장하지 못했습니다.');
      }
    }
  }

  Future<void> _deleteCompletedRuns(
    BuildContext context,
    int completedCount,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      title: '완료된 업무 삭제',
      message: '완료된 업무 $completedCount개를 삭제할까요?',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      final deletedCount = await store.deleteCompletedRuns();
      if (!context.mounted || deletedCount == 0) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('완료된 업무 $deletedCount개를 삭제했습니다.')),
      );
    } on Object {
      if (context.mounted) {
        _showError(context, '완료된 업무를 삭제하지 못했습니다.');
      }
    }
  }

  Future<void> _addAttachments(BuildContext context, WorkRun run) async {
    final remainingSlots =
        HanassikStore.maxAttachmentsPerRun - run.attachments.length;
    if (remainingSlots <= 0) {
      _showError(context,
          '첨부파일은 업무당 최대 ${HanassikStore.maxAttachmentsPerRun}개까지 가능합니다.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final attachments = <WorkAttachment>[];
      var skippedCount = 0;
      for (final file in result.files.take(remainingSlots)) {
        final bytes = file.bytes;
        if (bytes == null ||
            bytes.isEmpty ||
            bytes.lengthInBytes > HanassikStore.maxAttachmentBytes) {
          skippedCount++;
          continue;
        }

        attachments.add(
          WorkAttachment(
            id: _newAttachmentId(),
            name: file.name,
            dataBase64: base64Encode(bytes),
            mimeType: _guessMimeType(file.name),
          ),
        );
      }

      if (result.files.length > remainingSlots) {
        skippedCount += result.files.length - remainingSlots;
      }

      final saved = await store.addAttachments(run.id, attachments);
      if (!context.mounted) {
        return;
      }
      if (!saved) {
        _showError(context, '첨부파일을 저장하지 못했습니다.');
        return;
      }

      final message = skippedCount == 0
          ? '첨부파일 ${attachments.length}개를 추가했습니다.'
          : '첨부파일 ${attachments.length}개를 추가하고 $skippedCount개는 제외했습니다.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on Object {
      if (context.mounted) {
        _showError(context, '첨부파일을 선택하지 못했습니다.');
      }
    }
  }

  Future<void> _removeAttachment(
    BuildContext context,
    WorkRun run,
    WorkAttachment attachment,
  ) async {
    try {
      final removed = await store.removeAttachment(run.id, attachment.id);
      if (context.mounted && !removed) {
        _showError(context, '첨부파일을 삭제하지 못했습니다.');
      }
    } on Object {
      if (context.mounted) {
        _showError(context, '첨부파일을 삭제하지 못했습니다.');
      }
    }
  }
}

class RunsSummary extends StatelessWidget {
  const RunsSummary({
    super.key,
    required this.activeCount,
    required this.completedCount,
    required this.remainingStepCount,
    required this.progress,
  });

  final int activeCount;
  final int completedCount;
  final int remainingStepCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 진행 상황',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SummaryMetric(
                icon: Icons.play_circle_outline,
                label: '진행',
                value: '$activeCount개',
              ),
              _SummaryMetric(
                icon: Icons.radio_button_unchecked,
                label: '남은 항목',
                value: '$remainingStepCount개',
              ),
              _SummaryMetric(
                icon: Icons.check_circle_outline,
                label: '완료',
                value: '$completedCount개',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text('$label $value'),
        ],
      ),
    );
  }
}

class RunCard extends StatelessWidget {
  const RunCard({
    super.key,
    required this.run,
    required this.onToggle,
    required this.onAddAttachments,
    required this.onRemoveAttachment,
    this.onEditDetails,
  });

  final WorkRun run;
  final Future<void> Function(int index, bool value) onToggle;
  final Future<void> Function() onAddAttachments;
  final Future<void> Function(WorkAttachment attachment) onRemoveAttachment;
  final Future<void> Function()? onEditDetails;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nextUncheckedIndex = run.nextUncheckedIndex;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        run.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '템플릿: ${run.templateTitle}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRunTimes(run),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (onEditDetails != null)
                  IconButton(
                    tooltip: '업무 정보 수정',
                    onPressed: onEditDetails,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                if (run.isDone)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle, color: colorScheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: run.progress),
            const SizedBox(height: 8),
            Text('${run.completedCount}/${run.steps.length} 완료'),
            if (run.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                run.note,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (nextUncheckedIndex != null) ...[
              const SizedBox(height: 12),
              NextStepPanel(
                step: run.steps[nextUncheckedIndex],
                onComplete: () => onToggle(nextUncheckedIndex, true),
              ),
            ],
            const SizedBox(height: 12),
            AttachmentsSection(
              attachments: run.attachments,
              onAdd: onAddAttachments,
              onRemove: onRemoveAttachment,
            ),
            const Divider(height: 24),
            for (var index = 0; index < run.steps.length; index++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: run.checked[index],
                onChanged: (value) => onToggle(index, value ?? false),
                title: Text(run.steps[index]),
                controlAffinity: ListTileControlAffinity.leading,
              ),
          ],
        ),
      ),
    );
  }
}

class AttachmentsSection extends StatelessWidget {
  const AttachmentsSection({
    super.key,
    required this.attachments,
    required this.onAdd,
    required this.onRemove,
  });

  final List<WorkAttachment> attachments;
  final Future<void> Function() onAdd;
  final Future<void> Function(WorkAttachment attachment) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAdd = attachments.length < HanassikStore.maxAttachmentsPerRun;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '첨부파일 ${attachments.length}/${HanassikStore.maxAttachmentsPerRun}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            TextButton.icon(
              onPressed: canAdd ? onAdd : null,
              icon: const Icon(Icons.attach_file),
              label: const Text('첨부'),
            ),
          ],
        ),
        if (attachments.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final attachment in attachments)
                AttachmentTile(
                  attachment: attachment,
                  onRemove: () => onRemove(attachment),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class AttachmentTile extends StatelessWidget {
  const AttachmentTile({
    super.key,
    required this.attachment,
    required this.onRemove,
  });

  final WorkAttachment attachment;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 132,
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 86,
            width: double.infinity,
            child: attachment.isImage
                ? Image.memory(
                    attachment.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (context, _, __) =>
                        const Icon(Icons.broken_image_outlined),
                  )
                : ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: Icon(Icons.insert_drive_file_outlined),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  tooltip: '첨부파일 삭제',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                  iconSize: 18,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NextStepPanel extends StatelessWidget {
  const NextStepPanel({
    super.key,
    required this.step,
    required this.onComplete,
  });

  final String step;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_outlined,
                size: 18,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                '다음 할 일',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            step,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.done),
              label: const Text('다음 항목 완료'),
            ),
          ),
        ],
      ),
    );
  }
}

class TemplatesView extends StatelessWidget {
  const TemplatesView({super.key, required this.store});

  final HanassikStore store;

  @override
  Widget build(BuildContext context) {
    if (store.templates.isEmpty) {
      return const EmptyState(
        icon: Icons.library_add_outlined,
        title: '저장된 템플릿이 없습니다',
        message: '반복되는 업무 순서를 템플릿으로 먼저 저장하세요.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: store.templates.length,
      itemBuilder: (context, index) {
        final template = store.templates[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Dismissible(
            key: ValueKey('dismiss_template_${template.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.only(right: 20),
              alignment: Alignment.centerRight,
              child: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.onError),
            ),
            confirmDismiss: (_) => _confirmDelete(
              context,
              title: '템플릿 삭제',
              message: '"${template.title}" 템플릿을 삭제할까요?',
            ),
            onDismissed: (_) async {
              try {
                await store.deleteTemplate(template.id);
              } on Object {
                if (context.mounted) {
                  _showError(context, '템플릿을 삭제하지 못했습니다.');
                }
              }
            },
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: '수정',
                          onPressed: () => _editTemplate(context, template),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var stepIndex = 0;
                        stepIndex < template.steps.length;
                        stepIndex++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                            '${stepIndex + 1}. ${template.steps[stepIndex]}'),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _startRun(context, template),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('이 템플릿으로 시작'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startRun(BuildContext context, WorkTemplate template) async {
    final startedRun = await showModalBottomSheet<_RunDetailsResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StartRunSheet(
        store: store,
        template: template,
      ),
    );
    if (startedRun == null || !context.mounted) {
      return;
    }

    DefaultTabController.of(context).animateTo(0);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${startedRun.title}" 업무를 시작했습니다.')),
    );
  }

  Future<void> _editTemplate(
    BuildContext context,
    WorkTemplate template,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddTemplateSheet(
        store: store,
        template: template,
      ),
    );
  }
}

class StartRunSheet extends StatelessWidget {
  const StartRunSheet({
    super.key,
    required this.store,
    required this.template,
  });

  final HanassikStore store;
  final WorkTemplate template;

  @override
  Widget build(BuildContext context) {
    return RunDetailsSheet(
      title: '진행 업무 시작',
      initialTitle: template.title,
      initialNote: '',
      actionLabel: '시작',
      savingLabel: '시작 중...',
      actionIcon: Icons.play_arrow,
      errorMessage: '진행 업무를 시작하지 못했습니다.',
      onSave: (title, note) async {
        await store.startRun(template, title: title, note: note);
        return true;
      },
    );
  }
}

class EditRunDetailsSheet extends StatelessWidget {
  const EditRunDetailsSheet({
    super.key,
    required this.store,
    required this.run,
  });

  final HanassikStore store;
  final WorkRun run;

  @override
  Widget build(BuildContext context) {
    return RunDetailsSheet(
      title: '진행 업무 수정',
      initialTitle: run.title,
      initialNote: run.note,
      actionLabel: '저장',
      savingLabel: '저장 중...',
      actionIcon: Icons.edit_outlined,
      errorMessage: '업무 정보를 수정하지 못했습니다.',
      onSave: (title, note) => store.updateRunDetails(
        run.id,
        title: title,
        note: note,
      ),
    );
  }
}

class RunDetailsSheet extends StatefulWidget {
  const RunDetailsSheet({
    super.key,
    required this.title,
    required this.initialTitle,
    required this.initialNote,
    required this.actionLabel,
    required this.savingLabel,
    required this.actionIcon,
    required this.errorMessage,
    required this.onSave,
  });

  final String title;
  final String initialTitle;
  final String initialNote;
  final String actionLabel;
  final String savingLabel;
  final IconData actionIcon;
  final String errorMessage;
  final Future<bool> Function(String title, String note) onSave;

  @override
  State<RunDetailsSheet> createState() => _RunDetailsSheetState();
}

class _RunDetailsSheetState extends State<RunDetailsSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _noteController = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '업무 제목'),
                maxLength: HanassikStore.maxTitleLength,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return '업무 제목을 입력하세요.';
                  }
                  if (text.length > HanassikStore.maxTitleLength) {
                    return '업무 제목은 ${HanassikStore.maxTitleLength}자까지 입력할 수 있습니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: '메모'),
                maxLength: HanassikStore.maxRunNoteLength,
                maxLines: 5,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.length > HanassikStore.maxRunNoteLength) {
                    return '메모는 ${HanassikStore.maxRunNoteLength}자까지 입력할 수 있습니다.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: Icon(widget.actionIcon),
                  label: Text(
                    _isSaving ? widget.savingLabel : widget.actionLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final note = _noteController.text.trim();
    try {
      final saved = await widget.onSave(title, note);
      if (mounted && saved) {
        Navigator.of(context).pop(_RunDetailsResult(title));
      } else if (mounted) {
        _showError(context, widget.errorMessage);
      }
    } on Object {
      if (mounted) {
        _showError(context, widget.errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class _RunDetailsResult {
  const _RunDetailsResult(this.title);

  final String title;
}

class AddTemplateSheet extends StatefulWidget {
  const AddTemplateSheet({
    super.key,
    required this.store,
    this.template,
  });

  final HanassikStore store;
  final WorkTemplate? template;

  @override
  State<AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends State<AddTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final List<TextEditingController> _stepControllers;
  bool _isSaving = false;
  String? _stepsError;

  bool get _isEditing => widget.template != null;

  @override
  void initState() {
    super.initState();
    final template = widget.template;
    _titleController = TextEditingController(text: template?.title ?? '');
    _stepControllers = [
      for (final step in template?.steps ?? const <String>[])
        TextEditingController(text: step),
    ];

    if (_stepControllers.isEmpty) {
      _stepControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (final controller in _stepControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Form(
          key: _formKey,
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final item = _stepControllers.removeAt(oldIndex);
                _stepControllers.insert(newIndex, item);
              });
            },
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? '업무 템플릿 수정' : '업무 템플릿 만들기',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '템플릿 이름'),
                  maxLength: HanassikStore.maxTitleLength,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return '템플릿 이름을 입력하세요.';
                    }
                    if (text.length > HanassikStore.maxTitleLength) {
                      return '템플릿 이름은 ${HanassikStore.maxTitleLength}자까지 입력할 수 있습니다.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_stepsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _stepsError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                TextButton.icon(
                  onPressed: _stepControllers.length >=
                          HanassikStore.maxStepsPerTemplate
                      ? null
                      : _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text('항목 추가'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    child: Text(_saveButtonLabel),
                  ),
                ),
              ],
            ),
            children: [
              for (var index = 0; index < _stepControllers.length; index++)
                Padding(
                  key: ObjectKey(_stepControllers[index]),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(top: 16, right: 8),
                          child: Icon(Icons.drag_indicator, color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _stepControllers[index],
                          decoration: InputDecoration(
                            labelText: '체크 항목 ${index + 1}',
                          ),
                          maxLength: HanassikStore.maxStepLength,
                          onChanged: (_) => _clearStepsErrorIfNeeded(),
                          textInputAction: index == _stepControllers.length - 1
                              ? TextInputAction.done
                              : TextInputAction.next,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.length > HanassikStore.maxStepLength) {
                              return '체크 항목은 ${HanassikStore.maxStepLength}자까지 입력할 수 있습니다.';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (_stepControllers.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 4),
                          child: IconButton(
                            tooltip: '항목 삭제',
                            onPressed: () => _removeStep(index),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final steps = _stepControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (steps.isEmpty) {
      setState(() {
        _stepsError = '최소 1개 항목이 필요합니다.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _stepsError = null;
    });

    try {
      if (_isEditing) {
        final saved = await widget.store.updateTemplate(
          widget.template!.id,
          _titleController.text.trim(),
          steps,
        );
        if (!saved) {
          throw StateError('템플릿 수정에 실패했습니다.');
        }
      } else {
        await widget.store.addTemplate(_titleController.text.trim(), steps);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } on Object {
      if (mounted) {
        _showError(context, '템플릿을 저장하지 못했습니다.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String get _saveButtonLabel {
    if (_isSaving) {
      return _isEditing ? '수정 중...' : '저장 중...';
    }
    return _isEditing ? '수정' : '저장';
  }

  void _addStep() {
    if (_stepControllers.length >= HanassikStore.maxStepsPerTemplate) {
      return;
    }

    setState(() {
      _stepControllers.add(TextEditingController());
      _stepsError = null;
    });
  }

  void _removeStep(int index) {
    if (_stepControllers.length == 1 ||
        index < 0 ||
        index >= _stepControllers.length) {
      return;
    }

    final controller = _stepControllers[index];
    setState(() {
      _stepControllers.removeAt(index);
      _stepsError = null;
    });
    controller.dispose();
  }

  void _clearStepsErrorIfNeeded() {
    if (_stepsError == null) {
      return;
    }

    final hasStep = _stepControllers.any(
      (controller) => controller.text.trim().isNotEmpty,
    );
    if (!hasStep) {
      return;
    }

    setState(() {
      _stepsError = null;
    });
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => DefaultTabController.of(context).animateTo(1),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('삭제'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _formatRunTimes(WorkRun run) {
  final startedAt = _formatDateTime(run.startedAt);
  final endedAt = run.endedAt;
  if (endedAt == null) {
    return '$startedAt 시작';
  }

  return '$startedAt 시작 · ${_formatDateTime(endedAt)} 종료';
}

String _formatDateTime(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${value.year}.${twoDigits(value.month)}.${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)}';
}

String _newAttachmentId() => DateTime.now().microsecondsSinceEpoch.toString();

String? _guessMimeType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'bmp' => 'image/bmp',
    'heic' => 'image/heic',
    'pdf' => 'application/pdf',
    'txt' => 'text/plain',
    'csv' => 'text/csv',
    _ => null,
  };
}

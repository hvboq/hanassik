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
          return const Scaffold(
            body: LoadErrorState(),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
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

              return Scaffold(
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
          RunCard(
            key: ValueKey(run.id),
            run: run,
            onToggle: (index, value) =>
                _toggleRunStep(context, run, index, value),
            onDelete: () => _deleteRun(context, run),
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
            RunCard(
              key: ValueKey(run.id),
              run: run,
              onToggle: (index, value) =>
                  _toggleRunStep(context, run, index, value),
              onDelete: () => _deleteRun(context, run),
            ),
        ],
      ],
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

  Future<void> _deleteRun(BuildContext context, WorkRun run) async {
    final confirmed = await _confirmDelete(
      context,
      title: '진행 업무 삭제',
      message: '"${run.templateTitle}" 진행 기록을 삭제할까요?',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await store.deleteRun(run.id);
    } on Object {
      if (context.mounted) {
        _showError(context, '진행 업무를 삭제하지 못했습니다.');
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
    required this.onDelete,
  });

  final WorkRun run;
  final Future<void> Function(int index, bool value) onToggle;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final nextUncheckedIndex = run.nextUncheckedIndex;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                        run.templateTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatStartedAt(run.startedAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (run.isDone)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.check_circle, color: colorScheme.primary),
                  ),
                IconButton(
                  tooltip: '삭제',
                  onPressed: () => onDelete(),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: run.progress),
            const SizedBox(height: 8),
            Text('${run.completedCount}/${run.steps.length} 완료'),
            if (nextUncheckedIndex != null) ...[
              const SizedBox(height: 12),
              NextStepPanel(
                step: run.steps[nextUncheckedIndex],
                onComplete: () => onToggle(nextUncheckedIndex, true),
              ),
            ],
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

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
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
                    IconButton(
                      tooltip: '삭제',
                      onPressed: () => _deleteTemplate(context, template),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (var stepIndex = 0;
                    stepIndex < template.steps.length;
                    stepIndex++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child:
                        Text('${stepIndex + 1}. ${template.steps[stepIndex]}'),
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
        );
      },
    );
  }

  Future<void> _startRun(BuildContext context, WorkTemplate template) async {
    try {
      await store.startRun(template);
      if (!context.mounted) {
        return;
      }

      DefaultTabController.of(context).animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${template.title}" 업무를 시작했습니다.')),
      );
    } on Object {
      if (context.mounted) {
        _showError(context, '진행 업무를 시작하지 못했습니다.');
      }
    }
  }

  Future<void> _editTemplate(
    BuildContext context,
    WorkTemplate template,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddTemplateSheet(
        store: store,
        template: template,
      ),
    );
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WorkTemplate template,
  ) async {
    final confirmed = await _confirmDelete(
      context,
      title: '템플릿 삭제',
      message: '"${template.title}" 템플릿을 삭제할까요?',
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await store.deleteTemplate(template.id);
    } on Object {
      if (context.mounted) {
        _showError(context, '템플릿을 삭제하지 못했습니다.');
      }
    }
  }
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                for (var index = 0; index < _stepControllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _stepControllers[index],
                            decoration: InputDecoration(
                              labelText: '체크 항목 ${index + 1}',
                            ),
                            maxLength: HanassikStore.maxStepLength,
                            onChanged: (_) => _clearStepsErrorIfNeeded(),
                            textInputAction:
                                index == _stepControllers.length - 1
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

String _formatStartedAt(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${value.year}.${twoDigits(value.month)}.${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)} 시작';
}

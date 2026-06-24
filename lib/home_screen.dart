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

class HanassikHome extends StatelessWidget {
  const HanassikHome({super.key, required this.store});

  final HanassikStore store;

  @override
  Widget build(BuildContext context) {
    final activeCount = store.runs.where((run) => !run.isDone).length;

    return DefaultTabController(
      length: 2,
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
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showTemplateSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('템플릿 만들기'),
        ),
        body: TabBarView(
          children: [
            RunsView(store: store, activeCount: activeCount),
            TemplatesView(store: store),
          ],
        ),
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
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '진행 중 $activeCount개',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        for (final run in store.runs)
          RunCard(
            key: ValueKey(run.id),
            run: run,
            onToggle: (index, value) => store.toggleStep(run.id, index, value),
            onDelete: () => store.deleteRun(run.id),
          ),
      ],
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
  final void Function(int index, bool value) onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: run.progress),
            const SizedBox(height: 8),
            Text('${run.completedCount}/${run.steps.length} 완료'),
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
                      tooltip: '삭제',
                      onPressed: () => store.deleteTemplate(template.id),
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
                    onPressed: () => store.startRun(template),
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
}

class AddTemplateSheet extends StatefulWidget {
  const AddTemplateSheet({super.key, required this.store});

  final HanassikStore store;

  @override
  State<AddTemplateSheet> createState() => _AddTemplateSheetState();
}

class _AddTemplateSheetState extends State<AddTemplateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final List<TextEditingController> _stepControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

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
                  '업무 템플릿 만들기',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '템플릿 이름'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '템플릿 이름을 입력하세요.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < _stepControllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      controller: _stepControllers[index],
                      decoration:
                          InputDecoration(labelText: '체크 항목 ${index + 1}'),
                      textInputAction: TextInputAction.next,
                      validator: index == 0
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '최소 1개 항목이 필요합니다.';
                              }
                              return null;
                            }
                          : null,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _stepControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('항목 추가'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('저장'),
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

    await widget.store.addTemplate(_titleController.text.trim(), steps);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
          ],
        ),
      ),
    );
  }
}

String _formatStartedAt(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');

  return '${value.year}.${twoDigits(value.month)}.${twoDigits(value.day)} '
      '${twoDigits(value.hour)}:${twoDigits(value.minute)} 시작';
}

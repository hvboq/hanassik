class WorkTemplate {
  WorkTemplate({
    required this.id,
    required this.title,
    required this.steps,
  });

  final String id;
  final String title;
  final List<String> steps;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'steps': steps,
    };
  }

  factory WorkTemplate.fromJson(Map<String, dynamic> json) {
    return WorkTemplate(
      id: _readString(json['id']),
      title: _readString(json['title']),
      steps: _readStringList(json['steps']),
    );
  }
}

class WorkRun {
  WorkRun({
    required this.id,
    required this.templateTitle,
    required this.steps,
    required List<bool> checked,
    required this.startedAt,
  }) : checked = _fitChecked(checked, steps.length);

  final String id;
  final String templateTitle;
  final List<String> steps;
  final List<bool> checked;
  final DateTime startedAt;

  int get completedCount {
    var count = 0;
    final length =
        checked.length < steps.length ? checked.length : steps.length;
    for (var index = 0; index < length; index++) {
      if (checked[index]) {
        count++;
      }
    }
    return count;
  }

  double get progress {
    if (steps.isEmpty) {
      return 0;
    }
    return completedCount / steps.length;
  }

  bool get isDone => steps.isNotEmpty && completedCount == steps.length;

  WorkRun copyWith({List<bool>? checked}) {
    return WorkRun(
      id: id,
      templateTitle: templateTitle,
      steps: steps,
      checked: checked ?? this.checked,
      startedAt: startedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateTitle': templateTitle,
      'steps': steps,
      'checked': checked,
      'startedAt': startedAt.toIso8601String(),
    };
  }

  factory WorkRun.fromJson(Map<String, dynamic> json) {
    final steps = _readStringList(json['steps']);
    final rawChecked = _readBoolList(json['checked']);

    return WorkRun(
      id: _readString(json['id']),
      templateTitle: _readString(json['templateTitle']),
      steps: steps,
      checked: List<bool>.generate(
        steps.length,
        (index) => index < rawChecked.length ? rawChecked[index] : false,
      ),
      startedAt:
          DateTime.tryParse(_readString(json['startedAt'])) ?? DateTime.now(),
    );
  }
}

String _readString(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return [];
  }

  return value
      .whereType<String>()
      .map((text) => text.trim())
      .where((text) => text.isNotEmpty)
      .toList();
}

List<bool> _readBoolList(Object? value) {
  if (value is! List) {
    return [];
  }

  return value.whereType<bool>().toList();
}

List<bool> _fitChecked(List<bool> checked, int length) {
  if (checked.length == length) {
    return List<bool>.from(checked);
  }

  if (checked.length > length) {
    return checked.take(length).toList();
  }

  return [
    ...checked,
    ...List<bool>.filled(length - checked.length, false),
  ];
}

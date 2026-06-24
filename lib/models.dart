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
      id: json['id'] as String,
      title: json['title'] as String,
      steps: List<String>.from(json['steps'] as List<dynamic>),
    );
  }
}

class WorkRun {
  WorkRun({
    required this.id,
    required this.templateTitle,
    required this.steps,
    required this.checked,
    required this.startedAt,
  });

  final String id;
  final String templateTitle;
  final List<String> steps;
  final List<bool> checked;
  final DateTime startedAt;

  int get completedCount => checked.where((value) => value).length;

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
    return WorkRun(
      id: json['id'] as String,
      templateTitle: json['templateTitle'] as String,
      steps: List<String>.from(json['steps'] as List<dynamic>),
      checked: List<bool>.from(json['checked'] as List<dynamic>),
      startedAt: DateTime.parse(json['startedAt'] as String),
    );
  }
}

import 'dart:convert';
import 'dart:typed_data';

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

class WorkAttachment {
  WorkAttachment({
    required this.id,
    required this.name,
    required this.dataBase64,
    this.mimeType,
  });

  final String id;
  final String name;
  final String dataBase64;
  final String? mimeType;

  bool get isImage => mimeType?.startsWith('image/') ?? false;

  Uint8List get bytes => base64Decode(dataBase64);

  int get byteLength => bytes.lengthInBytes;

  WorkAttachment copyWith({
    String? id,
    String? name,
    String? dataBase64,
    String? mimeType,
  }) {
    return WorkAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      dataBase64: dataBase64 ?? this.dataBase64,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'dataBase64': dataBase64,
      'mimeType': mimeType,
    };
  }

  factory WorkAttachment.fromJson(Map<String, dynamic> json) {
    return WorkAttachment(
      id: _readString(json['id']),
      name: _readString(json['name']),
      dataBase64: _readString(json['dataBase64']),
      mimeType: _readNullableString(json['mimeType']),
    );
  }
}

class WorkRun {
  WorkRun({
    required this.id,
    required this.title,
    required this.templateTitle,
    required this.steps,
    required List<bool> checked,
    required this.startedAt,
    List<WorkAttachment> attachments = const [],
    this.note = '',
    this.endedAt,
  })  : checked = _fitChecked(checked, steps.length),
        attachments = List<WorkAttachment>.unmodifiable(attachments);

  final String id;
  final String title;
  final String templateTitle;
  final String note;
  final List<String> steps;
  final List<bool> checked;
  final List<WorkAttachment> attachments;
  final DateTime startedAt;
  final DateTime? endedAt;

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

  int get remainingCount => steps.length - completedCount;

  int? get nextUncheckedIndex {
    for (var index = 0; index < steps.length; index++) {
      if (!checked[index]) {
        return index;
      }
    }

    return null;
  }

  double get progress {
    if (steps.isEmpty) {
      return 0;
    }
    return completedCount / steps.length;
  }

  bool get isDone => steps.isNotEmpty && completedCount == steps.length;

  WorkRun copyWith({
    String? title,
    String? note,
    List<bool>? checked,
    List<WorkAttachment>? attachments,
    DateTime? endedAt,
    bool clearEndedAt = false,
  }) {
    return WorkRun(
      id: id,
      title: title ?? this.title,
      templateTitle: templateTitle,
      note: note ?? this.note,
      steps: steps,
      checked: checked ?? this.checked,
      attachments: attachments ?? this.attachments,
      startedAt: startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'templateTitle': templateTitle,
      'note': note,
      'steps': steps,
      'checked': checked,
      'attachments':
          attachments.map((attachment) => attachment.toJson()).toList(),
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }

  factory WorkRun.fromJson(Map<String, dynamic> json) {
    final steps = _readStringList(json['steps']);
    final rawChecked = _readBoolList(json['checked']);
    final templateTitle = _readString(json['templateTitle']);
    final title = _readString(json['title']);

    return WorkRun(
      id: _readString(json['id']),
      title: title.isEmpty ? templateTitle : title,
      templateTitle: templateTitle,
      note: _readString(json['note']),
      steps: steps,
      checked: List<bool>.generate(
        steps.length,
        (index) => index < rawChecked.length ? rawChecked[index] : false,
      ),
      attachments: _readAttachmentList(json['attachments']),
      startedAt:
          DateTime.tryParse(_readString(json['startedAt'])) ?? DateTime.now(),
      endedAt: DateTime.tryParse(_readString(json['endedAt'])),
    );
  }
}

String _readString(Object? value) {
  if (value is String) {
    return value.trim();
  }
  return '';
}

String? _readNullableString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
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

List<WorkAttachment> _readAttachmentList(Object? value) {
  if (value is! List) {
    return [];
  }

  return value
      .whereType<Map>()
      .map((item) => WorkAttachment.fromJson(Map<String, dynamic>.from(item)))
      .where(
        (attachment) =>
            attachment.id.isNotEmpty &&
            attachment.name.isNotEmpty &&
            attachment.dataBase64.isNotEmpty,
      )
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

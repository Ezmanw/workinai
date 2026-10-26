import 'dart:convert';
import 'dart:ui';

class Profile {
  final String id;
  String name;
  int colorValue;
  final int createdAt;

  Profile({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'colorValue': colorValue,
    'createdAt': createdAt,
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Learner',
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF6750A4,
    createdAt:
        (json['createdAt'] as num?)?.toInt() ??
        DateTime.now().millisecondsSinceEpoch,
  );
}

class AiSettings {
  String provider; // 'local' or 'gemini'
  String baseUrl;
  String model;
  String apiKey;
  String geminiKey;
  String geminiModel;
  bool useFallback;

  AiSettings({
    this.provider = 'local',
    this.baseUrl = 'http://localhost:1234/v1',
    this.model = 'local-model',
    this.apiKey = '',
    this.geminiKey = '',
    this.geminiModel = 'gemini-2.5-flash',
    this.useFallback = true,
  });

  AiSettings copyWith({
    String? provider,
    String? baseUrl,
    String? model,
    String? apiKey,
    String? geminiKey,
    String? geminiModel,
    bool? useFallback,
  }) {
    return AiSettings(
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      apiKey: apiKey ?? this.apiKey,
      geminiKey: geminiKey ?? this.geminiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      useFallback: useFallback ?? this.useFallback,
    );
  }

  bool get isLocal => provider == 'local';
  bool get hasKey => isLocal ? true : geminiKey.trim().isNotEmpty;
  String get endpointLabel => isLocal ? baseUrl : 'Gemini · $geminiModel';
  String get activeModel => (isLocal ? model : geminiModel).trim().isEmpty
      ? 'unknown'
      : (isLocal ? model : geminiModel);

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'baseUrl': baseUrl,
    'model': model,
    'apiKey': apiKey,
    'geminiKey': geminiKey,
    'geminiModel': geminiModel,
    'useFallback': useFallback,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) => AiSettings(
    provider: json['provider'] as String? ?? 'local',
    baseUrl: json['baseUrl'] as String? ?? 'http://localhost:1234/v1',
    model: json['model'] as String? ?? 'local-model',
    apiKey: json['apiKey'] as String? ?? '',
    geminiKey: json['geminiKey'] as String? ?? '',
    geminiModel: json['geminiModel'] as String? ?? 'gemini-2.5-flash',
    useFallback: json['useFallback'] as bool? ?? true,
  );
}

enum BlockType { text, question, diagram }

enum QuestionStyle { short, long, choice, matching }

class WorksheetBlock {
  final BlockType type;
  String? id;
  int number;
  String text;
  String prompt;
  String answer;
  List<String> keywords;
  int answerLines;
  bool workingBox;
  double height;
  QuestionStyle style;
  List<String> options;
  List<String> leftItems;
  List<String> rightItems;
  List<String> matches;

  WorksheetBlock({
    required this.type,
    this.id,
    this.number = 0,
    this.text = '',
    this.prompt = '',
    this.answer = '',
    List<String>? keywords,
    this.answerLines = 2,
    this.workingBox = false,
    this.height = 180,
    this.style = QuestionStyle.short,
    List<String>? options,
    List<String>? leftItems,
    List<String>? rightItems,
    List<String>? matches,
  }) : keywords = keywords ?? <String>[],
       options = options ?? <String>[],
       leftItems = leftItems ?? <String>[],
       rightItems = rightItems ?? <String>[],
       matches = matches ?? <String>[];

  bool get isChoice => style == QuestionStyle.choice && options.length >= 2;
  bool get isMatching =>
      style == QuestionStyle.matching &&
      leftItems.length >= 2 &&
      rightItems.length >= 2;

  String get displayAnswer {
    if (isChoice && answer.trim().isNotEmpty) {
      final letter = answer.trim().toUpperCase();
      final index = letter.codeUnitAt(0) - 65;
      if (letter.length == 1 && index >= 0 && index < options.length) {
        return '$letter. ${options[index]}';
      }
    }
    if (isMatching && matches.isNotEmpty) {
      final parts = <String>[];
      for (var index = 0; index < matches.length; index++) {
        final match = matches[index].trim().toUpperCase();
        if (match.isEmpty) continue;
        final rightIndex = match.length == 1 ? match.codeUnitAt(0) - 65 : -1;
        final detail = rightIndex >= 0 && rightIndex < rightItems.length
            ? '${index + 1}-$match (${rightItems[rightIndex]})'
            : '${index + 1}-$match';
        parts.add(detail);
      }
      if (parts.isNotEmpty) return parts.join(' · ');
    }
    return answer;
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'id': id,
    'number': number,
    'text': text,
    'prompt': prompt,
    'answer': answer,
    'keywords': keywords,
    'answerLines': answerLines,
    'workingBox': workingBox,
    'height': height,
    'style': style.name,
    'options': options,
    'leftItems': leftItems,
    'rightItems': rightItems,
    'matches': matches,
  };

  factory WorksheetBlock.fromJson(Map<String, dynamic> json) {
    final typeName = (json['type']?.toString() ?? 'text').toLowerCase();
    final type = BlockType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => BlockType.text,
    );
    return WorksheetBlock(
      type: type,
      id: json['id'] as String?,
      number: (json['number'] as num?)?.toInt() ?? 0,
      text: json['text'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      keywords: _parseStringList(json['keywords']),
      answerLines: ((json['answerLines'] as num?)?.toInt() ?? 2)
          .clamp(1, 8)
          .toInt(),
      workingBox: json['workingBox'] as bool? ?? false,
      height: ((json['height'] as num?)?.toDouble() ?? 180)
          .clamp(90, 360)
          .toDouble(),
      style: _parseQuestionStyle(json['style'] ?? json['questionStyle']),
      options: _parseStringList(json['options']),
      leftItems: _parseStringList(
        json['leftItems'] ?? json['left'] ?? json['items'],
      ),
      rightItems: _parseStringList(
        json['rightItems'] ?? json['right'] ?? json['definitions'],
      ),
      matches: _parseStringList(json['matches']),
    );
  }
}

class WorksheetSection {
  String title;
  List<WorksheetBlock> blocks;

  WorksheetSection({required this.title, required this.blocks});

  Map<String, dynamic> toJson() => {
    'title': title,
    'blocks': blocks.map((block) => block.toJson()).toList(),
  };

  factory WorksheetSection.fromJson(Map<String, dynamic> json) =>
      WorksheetSection(
        title: json['title'] as String? ?? '',
        blocks:
            (json['blocks'] as List?)
                ?.whereType<Map>()
                .map(
                  (value) =>
                      WorksheetBlock.fromJson(Map<String, dynamic>.from(value)),
                )
                .toList() ??
            <WorksheetBlock>[],
      );
}

class WorksheetPage {
  String title;
  List<WorksheetSection> sections;

  WorksheetPage({required this.title, required this.sections});

  Map<String, dynamic> toJson() => {
    'title': title,
    'sections': sections.map((section) => section.toJson()).toList(),
  };

  factory WorksheetPage.fromJson(Map<String, dynamic> json) => WorksheetPage(
    title: json['title'] as String? ?? '',
    sections:
        (json['sections'] as List?)
            ?.whereType<Map>()
            .map(
              (value) =>
                  WorksheetSection.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList() ??
        <WorksheetSection>[],
  );
}

class Stroke {
  final int page;
  final List<Offset> points;
  final int colorValue;
  final double width;
  final bool erase;

  Stroke({
    required this.page,
    required this.points,
    required this.colorValue,
    required this.width,
    required this.erase,
  });

  Map<String, dynamic> toJson() => {
    'page': page,
    'points': points
        .map(
          (point) => [
            double.parse(point.dx.toStringAsFixed(4)),
            double.parse(point.dy.toStringAsFixed(4)),
          ],
        )
        .toList(),
    'colorValue': colorValue,
    'width': width,
    'erase': erase,
  };

  factory Stroke.fromJson(Map<String, dynamic> json) => Stroke(
    page: (json['page'] as num?)?.toInt() ?? 0,
    points:
        (json['points'] as List?)
            ?.whereType<List>()
            .where((value) => value.length >= 2)
            .map(
              (value) => Offset(
                (value[0] as num).toDouble(),
                (value[1] as num).toDouble(),
              ),
            )
            .toList() ??
        <Offset>[],
    colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF1B1B1B,
    width: (json['width'] as num?)?.toDouble() ?? 2.4,
    erase: json['erase'] as bool? ?? false,
  );
}

class WorksheetQuestion {
  final int pageIndex;
  final WorksheetBlock block;

  const WorksheetQuestion({required this.pageIndex, required this.block});
  String get id => block.id ?? '';
  int get number => block.number;
}

class Worksheet {
  final String id;
  final String profileId;
  final String subject;
  final String area;
  final int createdAt;
  String title;
  String subtitle;
  String instructions;
  List<WorksheetPage> pages;
  Map<String, String> answers;
  Map<String, String> marks;
  int? score;
  int? correct;
  int? total;
  int? reviewCount;
  String? aiReviewJson;
  String? generator;
  List<Stroke> strokes;

  Worksheet({
    required this.id,
    required this.profileId,
    required this.subject,
    required this.area,
    required this.createdAt,
    required this.title,
    required this.subtitle,
    required this.instructions,
    required this.pages,
    Map<String, String>? answers,
    Map<String, String>? marks,
    this.score,
    this.correct,
    this.total,
    this.reviewCount,
    this.aiReviewJson,
    this.generator,
    List<Stroke>? strokes,
  }) : answers = answers ?? <String, String>{},
       marks = marks ?? <String, String>{},
       strokes = strokes ?? <Stroke>[];

  List<WorksheetQuestion> get questions {
    final result = <WorksheetQuestion>[];
    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      for (final section in pages[pageIndex].sections) {
        for (final block in section.blocks) {
          if (block.type == BlockType.question) {
            result.add(WorksheetQuestion(pageIndex: pageIndex, block: block));
          }
        }
      }
    }
    return result;
  }

  int get questionCount => questions.length;

  void assignQuestionIds() {
    var number = 0;
    for (final page in pages) {
      for (final section in page.sections) {
        for (final block in section.blocks) {
          if (block.type == BlockType.question) {
            number += 1;
            block.number = number;
            block.id = 'q$number';
          }
        }
      }
    }
  }

  void trimToQuestions(int maxQuestions) {
    var count = 0;
    for (final page in pages) {
      for (final section in page.sections) {
        section.blocks.removeWhere((block) {
          if (block.type != BlockType.question) return false;
          count += 1;
          return count > maxQuestions;
        });
      }
      page.sections.removeWhere((section) => section.blocks.isEmpty);
    }
    pages.removeWhere((page) => page.sections.isEmpty);
    assignQuestionIds();
  }

  void recalculate() {
    var correctCount = 0;
    var assessed = 0;
    var review = 0;
    for (final question in questions) {
      final mark = marks[question.id];
      if (mark == 'correct') {
        correctCount += 1;
        assessed += 1;
      } else if (mark == 'wrong') {
        assessed += 1;
      } else if (mark == 'review') {
        review += 1;
      }
    }
    correct = correctCount;
    total = assessed;
    reviewCount = review;
    score = assessed == 0 ? null : ((correctCount / assessed) * 100).round();
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'subject': subject,
    'area': area,
    'createdAt': createdAt,
    'title': title,
    'subtitle': subtitle,
    'instructions': instructions,
    'pages': pages.map((page) => page.toJson()).toList(),
    'answers': answers,
    'marks': marks,
    'score': score,
    'correct': correct,
    'total': total,
    'reviewCount': reviewCount,
    'aiReviewJson': aiReviewJson,
    'generator': generator,
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
  };

  factory Worksheet.fromJson(Map<String, dynamic> json) {
    final pages =
        (json['pages'] as List?)
            ?.whereType<Map>()
            .map(
              (value) =>
                  WorksheetPage.fromJson(Map<String, dynamic>.from(value)),
            )
            .toList() ??
        <WorksheetPage>[];
    final worksheet = Worksheet(
      id: json['id'] as String? ?? '',
      profileId: json['profileId'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      area: json['area'] as String? ?? '',
      createdAt:
          (json['createdAt'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
      pages: pages,
      answers:
          (json['answers'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{},
      marks:
          (json['marks'] as Map?)?.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ) ??
          <String, String>{},
      score: (json['score'] as num?)?.toInt(),
      correct: (json['correct'] as num?)?.toInt(),
      total: (json['total'] as num?)?.toInt(),
      reviewCount: (json['reviewCount'] as num?)?.toInt(),
      aiReviewJson: json['aiReviewJson'] as String?,
      generator: json['generator'] as String?,
      strokes:
          (json['strokes'] as List?)
              ?.whereType<Map>()
              .map((value) => Stroke.fromJson(Map<String, dynamic>.from(value)))
              .toList() ??
          <Stroke>[],
    );
    if (worksheet.questions.any((question) => question.block.id == null)) {
      worksheet.assignQuestionIds();
    }
    return worksheet;
  }

  static Worksheet fromAiJson(
    Map<String, dynamic> json, {
    required String profileId,
    required String subject,
    required String area,
    required int questionTarget,
    String? generator,
  }) {
    var pages = <WorksheetPage>[];
    final rawPages = json['pages'];
    if (rawPages is List) {
      for (final raw in rawPages.take(12)) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final sections = _parseSections(map['sections']);
        final pageQuestions = _parseQuestions(map['questions']);
        if (pageQuestions.isNotEmpty) {
          sections.add(
            WorksheetSection(title: 'Questions', blocks: pageQuestions),
          );
        }
        final pageBlocks = _parseBlocks(map['blocks']);
        if (pageBlocks.isNotEmpty) {
          sections.add(
            WorksheetSection(title: 'Questions', blocks: pageBlocks),
          );
        }
        final pageDiagrams = _parseDiagrams(map['diagrams'] ?? map['diagram']);
        if (pageDiagrams.isNotEmpty) {
          sections.add(
            WorksheetSection(
              title: 'Diagram / working space',
              blocks: pageDiagrams,
            ),
          );
        }
        if (sections.isEmpty) continue;
        pages.add(
          WorksheetPage(
            title: _cleanTitle(map['title'], 'Page ${pages.length + 1}'),
            sections: sections,
          ),
        );
      }
    }
    if (pages.isEmpty && json['sections'] is List) {
      final sections = _parseSections(json['sections']);
      if (sections.isNotEmpty) {
        pages.add(WorksheetPage(title: 'Page 1', sections: sections));
      }
    }
    if (pages.isEmpty) {
      final directBlocks = _parseBlocks(json['blocks']);
      if (directBlocks.isNotEmpty) {
        pages = _paginateBlocks(directBlocks);
      } else {
        final questions = _parseQuestions(json['questions']);
        if (questions.isNotEmpty) {
          pages = _buildFlatPages(
            questions: questions,
            diagrams: _parseDiagrams(json['diagrams'] ?? json['diagram']),
            keyTerms: _parseStringList(
              json['keyTerms'] ?? json['keyterms'],
              max: 10,
            ),
          );
        }
      }
    }
    if (pages.isEmpty) {
      throw const FormatException('The AI returned no usable worksheet pages.');
    }

    var questionCount = 0;
    for (final page in pages) {
      for (final section in page.sections) {
        questionCount += section.blocks
            .where((block) => block.type == BlockType.question)
            .length;
      }
    }
    if (pages.length > 4 || questionCount > pages.length * 5) {
      final blocks = <WorksheetBlock>[
        for (final page in pages)
          for (final section in page.sections) ...section.blocks,
      ];
      pages = _paginateBlocks(blocks);
    }

    final worksheet = Worksheet(
      id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
      profileId: profileId,
      subject: subject,
      area: area,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      title: _cleanTitle(json['title'], area),
      subtitle: _cleanTitle(json['subtitle'], subject),
      instructions: _cleanInstructions(json['instructions']),
      pages: pages,
      generator: generator,
    );
    worksheet.trimToQuestions(questionTarget.clamp(1, 24).toInt());
    if (worksheet.questionCount == 0) {
      throw const FormatException(
        'The AI response did not contain any questions.',
      );
    }
    final wanted = questionTarget.clamp(1, 20).toInt();
    if (wanted >= 4 && worksheet.questionCount < ((wanted + 1) ~/ 2)) {
      throw FormatException(
        'The AI returned only ${worksheet.questionCount} of $wanted questions.',
      );
    }
    return worksheet;
  }
}

List<WorksheetPage> _buildFlatPages({
  required List<WorksheetBlock> questions,
  required List<WorksheetBlock> diagrams,
  required List<String> keyTerms,
}) {
  final pages = _paginateQuestions(questions);
  if (keyTerms.isNotEmpty) {
    final block = WorksheetBlock(
      type: BlockType.text,
      text: 'Key terms: ${keyTerms.join(' · ')}',
    );
    if (pages.isEmpty) {
      pages.add(
        WorksheetPage(
          title: 'Page 1',
          sections: [
            WorksheetSection(title: 'Key terms', blocks: [block]),
          ],
        ),
      );
    } else {
      pages.first.sections.insert(
        0,
        WorksheetSection(title: 'Key terms', blocks: [block]),
      );
    }
  }
  if (diagrams.isNotEmpty) {
    if (pages.isEmpty) {
      pages.add(
        WorksheetPage(
          title: 'Page 1',
          sections: [
            WorksheetSection(
              title: 'Diagram / working space',
              blocks: diagrams,
            ),
          ],
        ),
      );
    } else {
      final last = pages.last;
      final lastQuestions = last.sections
          .expand((section) => section.blocks)
          .where((block) => block.type == BlockType.question)
          .length;
      if (lastQuestions >= 5 && pages.length < 4) {
        pages.add(
          WorksheetPage(
            title: 'Page ${pages.length + 1}',
            sections: [
              WorksheetSection(
                title: 'Diagram / working space',
                blocks: diagrams,
              ),
            ],
          ),
        );
      } else {
        last.sections.add(
          WorksheetSection(title: 'Diagram / working space', blocks: diagrams),
        );
      }
    }
  }
  return pages;
}

List<WorksheetPage> _paginateQuestions(List<WorksheetBlock> questions) {
  return _paginateBlocks(questions);
}

List<WorksheetPage> _paginateBlocks(List<WorksheetBlock> blocks) {
  const perPage = 5;
  final pages = <WorksheetPage>[];
  var current = <WorksheetBlock>[];
  var questionsOnPage = 0;

  void flush() {
    if (current.isEmpty) return;
    pages.add(
      WorksheetPage(
        title: 'Page ${pages.length + 1}',
        sections: [WorksheetSection(title: 'Questions', blocks: current)],
      ),
    );
    current = <WorksheetBlock>[];
    questionsOnPage = 0;
  }

  for (final block in blocks) {
    if (block.type == BlockType.question && questionsOnPage >= perPage) {
      flush();
    }
    current.add(block);
    if (block.type == BlockType.question) questionsOnPage += 1;
  }
  flush();
  return pages;
}

List<WorksheetSection> _parseSections(dynamic rawSections) {
  if (rawSections is! List) return <WorksheetSection>[];
  final sections = <WorksheetSection>[];
  for (final rawSection in rawSections.take(4)) {
    if (rawSection is! Map) continue;
    final map = Map<String, dynamic>.from(rawSection);
    final blocks = <WorksheetBlock>[
      ..._parseBlocks(map['blocks']),
      ..._parseQuestions(map['questions']),
      ..._parseDiagrams(map['diagrams'] ?? map['diagram']),
    ];
    if (blocks.isNotEmpty) {
      sections.add(
        WorksheetSection(
          title: _cleanString(map['title'], fallback: 'Questions'),
          blocks: blocks,
        ),
      );
    }
  }
  return sections;
}

List<WorksheetBlock> _parseBlocks(dynamic rawBlocks) {
  if (rawBlocks is! List) return <WorksheetBlock>[];
  final blocks = <WorksheetBlock>[];
  for (final rawBlock in rawBlocks.take(12)) {
    if (rawBlock is! Map) continue;
    final blockMap = Map<String, dynamic>.from(rawBlock);
    final typeName = (blockMap['type']?.toString() ?? '').toLowerCase();
    if (typeName == 'text' || typeName == 'note') {
      final text = _cleanField(
        blockMap['text'] ?? blockMap['prompt'],
        _textPlaceholders,
      );
      if (text.isNotEmpty) {
        blocks.add(WorksheetBlock(type: BlockType.text, text: text));
      }
    } else if (typeName == 'diagram' ||
        typeName == 'box' ||
        typeName == 'workspace') {
      final diagram = _parseDiagram(blockMap);
      if (diagram != null) blocks.add(diagram);
    } else if (typeName == 'question' ||
        typeName == 'choice' ||
        typeName == 'multiplechoice' ||
        typeName == 'matching' ||
        typeName == 'match') {
      final questionMap = Map<String, dynamic>.from(blockMap);
      questionMap['style'] ??= typeName;
      final question = _parseQuestionBlock(questionMap);
      if (question != null) blocks.add(question);
    }
  }
  return blocks;
}

List<WorksheetBlock> _parseQuestions(dynamic rawQuestions) {
  if (rawQuestions is! List) return <WorksheetBlock>[];
  final questions = <WorksheetBlock>[];
  for (final raw in rawQuestions.take(30)) {
    if (raw is! Map) continue;
    final question = _parseQuestionBlock(Map<String, dynamic>.from(raw));
    if (question != null) questions.add(question);
  }
  return questions;
}

List<WorksheetBlock> _parseDiagrams(dynamic rawDiagrams) {
  final items = rawDiagrams is List
      ? rawDiagrams
      : rawDiagrams is Map
      ? <dynamic>[rawDiagrams]
      : rawDiagrams is String
      ? <dynamic>[rawDiagrams]
      : <dynamic>[];
  final diagrams = <WorksheetBlock>[];
  for (final raw in items.take(4)) {
    if (raw is Map) {
      final diagram = _parseDiagram(Map<String, dynamic>.from(raw));
      if (diagram != null) diagrams.add(diagram);
    } else if (raw is String) {
      final prompt = _cleanField(raw, _diagramPlaceholders);
      if (prompt.isNotEmpty) {
        diagrams.add(WorksheetBlock(type: BlockType.diagram, prompt: prompt));
      }
    }
  }
  return diagrams;
}

WorksheetBlock? _parseDiagram(Map<String, dynamic> map) {
  final prompt = _cleanField(
    map['prompt'] ?? map['task'] ?? map['text'] ?? map['label'],
    _diagramPlaceholders,
  );
  if (prompt.isEmpty) return null;
  return WorksheetBlock(
    type: BlockType.diagram,
    prompt: prompt,
    height: _parseDouble(map['height'], fallback: 180, min: 90, max: 360),
  );
}

WorksheetBlock? _parseQuestionBlock(Map<String, dynamic> map) {
  final prompt = _cleanField(map['prompt'], _promptPlaceholders);
  if (prompt.isEmpty) return null;

  var style = _parseQuestionStyle(
    map['style'] ?? map['questionStyle'] ?? map['kind'],
  );
  final options = _parseStringList(
    map['options'] ?? map['choices'],
    max: 6,
    placeholders: _optionPlaceholders,
  );
  final leftItems = _parseStringList(
    map['left'] ?? map['leftItems'] ?? map['items'],
    max: 6,
    placeholders: _matchingPlaceholders,
  );
  final rightItems = _parseStringList(
    map['right'] ?? map['rightItems'] ?? map['definitions'] ?? map['meanings'],
    max: 6,
    placeholders: _matchingPlaceholders,
  );

  if (style == QuestionStyle.short) {
    if (options.length >= 2) {
      style = QuestionStyle.choice;
    } else if (leftItems.length >= 2 && rightItems.length >= 2) {
      style = QuestionStyle.matching;
    }
  }
  if (style == QuestionStyle.choice && options.length < 2) {
    style = QuestionStyle.short;
  }
  if (style == QuestionStyle.matching &&
      (leftItems.length < 2 || rightItems.length < 2)) {
    style = QuestionStyle.short;
  }

  var answer = _cleanField(map['answer'], _answerPlaceholders);
  var matches = <String>[];
  if (style == QuestionStyle.choice) {
    answer = _choiceAnswer(answer, options);
  } else if (style == QuestionStyle.matching) {
    matches = _parseMatches(
      map['matches'] ?? map['pairs'] ?? map['mapping'] ?? answer,
      leftCount: leftItems.length,
      rightItems: rightItems,
    );
  }

  return WorksheetBlock(
    type: BlockType.question,
    prompt: prompt,
    answer: answer,
    keywords: _parseKeywords(map['keywords']),
    answerLines:
        style == QuestionStyle.choice || style == QuestionStyle.matching
        ? 1
        : _parseInt(map['answerLines'], fallback: 2, min: 1, max: 8),
    workingBox: _parseBool(map['workingBox']),
    style: style,
    options: options,
    leftItems: leftItems,
    rightItems: rightItems,
    matches: matches,
  );
}

List<String> _parseStringList(
  dynamic value, {
  int max = 8,
  Set<String>? placeholders,
}) {
  final values = <String>[];
  if (value is List) {
    for (final item in value) {
      if (item == null) continue;
      values.add(item.toString().trim());
    }
  } else if (value is String) {
    values.addAll(value.split(RegExp(r'[,;\n]')));
  } else if (value != null) {
    values.add(value.toString().trim());
  }
  final seen = <String>{};
  return values
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .where(
        (item) =>
            placeholders == null || !placeholders.contains(item.toLowerCase()),
      )
      .where((item) => seen.add(item.toLowerCase()))
      .take(max)
      .toList();
}

QuestionStyle _parseQuestionStyle(dynamic value) {
  final name = (value?.toString() ?? '').toLowerCase().replaceAll(
    RegExp(r'[^a-z]'),
    '',
  );
  if (name == 'long' ||
      name == 'extended' ||
      name == 'paragraph' ||
      name == 'writtenlong') {
    return QuestionStyle.long;
  }
  if (name == 'choice' ||
      name == 'multiplechoice' ||
      name == 'multichoice' ||
      name == 'mcq') {
    return QuestionStyle.choice;
  }
  if (name == 'matching' ||
      name == 'match' ||
      name == 'matchingpairs' ||
      name == 'pairs' ||
      name == 'matchup') {
    return QuestionStyle.matching;
  }
  return QuestionStyle.short;
}

String _choiceAnswer(String raw, List<String> options) {
  final text = raw.trim();
  if (text.isEmpty) return '';
  final direct = RegExp(r'^([A-F])(?:[.\-:)]|\s|$)')
      .firstMatch(text.toUpperCase());
  if (direct != null) return direct.group(1)!;
  final normalized = _normalizeLoose(text);
  for (var index = 0; index < options.length; index++) {
    final option = _normalizeLoose(options[index]);
    if (option.isNotEmpty &&
        (normalized == option || normalized.contains(option))) {
      return String.fromCharCode(65 + index);
    }
  }
  final letter = RegExp(r'\b([A-F])\b').firstMatch(text.toUpperCase());
  return letter?.group(1) ?? text;
}

List<String> _parseMatches(
  dynamic value, {
  required int leftCount,
  required List<String> rightItems,
}) {
  final values = <String>[];
  if (value is List) {
    for (final item in value) {
      if (item == null) continue;
      values.add(item.toString().trim());
    }
  } else if (value is String) {
    values.addAll(value.split(RegExp(r'[,;\n]')));
  }
  if (values.isEmpty) return <String>[];

  final assigned = <int, String>{};
  final sequential = <String>[];
  for (final value in values) {
    if (value.isEmpty) continue;
    final pair = RegExp(r'(\d+)\s*[-=:.)]?\s*([A-Fa-f])').firstMatch(value);
    if (pair != null) {
      final index = int.parse(pair.group(1)!) - 1;
      if (index >= 0 && index < leftCount) {
        assigned[index] = pair.group(2)!.toUpperCase();
      }
      continue;
    }
    final rightIndex = rightItems.indexWhere(
      (item) => _normalizeLoose(item) == _normalizeLoose(value),
    );
    if (rightIndex >= 0) {
      sequential.add(String.fromCharCode(65 + rightIndex));
      continue;
    }
    final letter = RegExp(r'\b([A-Fa-f])\b').firstMatch(value)?.group(1);
    if (letter != null) sequential.add(letter.toUpperCase());
  }

  final result = List<String>.filled(leftCount, '');
  for (var index = 0; index < leftCount; index++) {
    result[index] =
        assigned[index] ?? (index < sequential.length ? sequential[index] : '');
  }
  for (var index = 0; index < result.length; index++) {
    final match = result[index];
    if (match.isEmpty) continue;
    final code = match.codeUnitAt(0) - 65;
    if (code < 0 || code >= rightItems.length) {
      result[index] = '';
    }
  }
  return result.where((item) => item.isNotEmpty).length >= 2
      ? result
      : <String>[];
}

String _normalizeLoose(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _parseKeywords(dynamic value) {
  final values = <String>[];
  if (value is List) {
    for (final item in value) {
      if (item == null) continue;
      values.add(item.toString().trim());
    }
  } else if (value is String) {
    values.addAll(value.split(','));
  }
  final seen = <String>{};
  return values
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .where((item) => !_keywordPlaceholders.contains(item.toLowerCase()))
      .where((item) => seen.add(item.toLowerCase()))
      .take(8)
      .toList();
}

int _parseInt(
  dynamic value, {
  required int fallback,
  required int min,
  required int max,
}) {
  final number = value is num
      ? value.toInt()
      : int.tryParse(value?.toString().trim() ?? '');
  if (number == null) return fallback;
  return number.clamp(min, max).toInt();
}

double _parseDouble(
  dynamic value, {
  required double fallback,
  required double min,
  required double max,
}) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse(value?.toString().trim() ?? '');
  if (number == null) return fallback;
  return number.clamp(min, max).toDouble();
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    return text == 'true' || text == 'yes' || text == '1';
  }
  return false;
}

const _promptPlaceholders = {
  'question text',
  'question prompt',
  'question',
  'prompt',
};

const _answerPlaceholders = {
  'model answer',
  'concise model answer',
  'full model answer',
  'complete model answer',
  'answer text',
  'answer',
};

const _keywordPlaceholders = {
  'word',
  'keywords',
  'keyword',
  'acceptable',
  'acceptable answers',
  'acceptable keywords',
};

const _optionPlaceholders = {
  'option',
  'option text',
  'choice',
  'answer choice',
  'first option',
  'second option',
  'third option',
};

const _matchingPlaceholders = {
  'item',
  'left item',
  'right item',
  'term',
  'definition',
  'meaning',
  'match',
};

const _diagramPlaceholders = {
  'prompt',
  'diagram prompt',
  'what to draw',
  'draw here',
  'use this space for a diagram or working.',
};

const _textPlaceholders = {
  'text',
  'optional short intro or key terms',
  'optional intro',
};

const _titlePlaceholders = {
  'title',
  'worksheet title',
  'short worksheet title',
  'subtitle',
  'subject and level',
  'page title',
};

const _instructionPlaceholders = {
  'instructions',
  'instruction',
  'one short sentence for the student',
  'one short sentence telling the student what to do',
  '1-2 short sentences for the student',
  'short instructions for the student',
};

String _cleanField(dynamic value, Set<String> placeholders) {
  final text = _cleanString(value);
  if (text.isEmpty) return '';
  return placeholders.contains(text.toLowerCase()) ? '' : text;
}

String _cleanTitle(dynamic value, String fallback) {
  final text = _cleanField(value, _titlePlaceholders);
  return text.isEmpty ? fallback : text;
}

String _cleanInstructions(dynamic value) {
  const fallback =
      'Answer in the spaces provided. Show your working where needed.';
  final text = _cleanField(value, _instructionPlaceholders);
  return text.isEmpty ? fallback : text;
}

String _cleanString(dynamic value, {String fallback = ''}) {
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return fallback;
}

class AiReviewItem {
  final int question;
  final String verdict;
  final String feedback;

  const AiReviewItem({
    required this.question,
    required this.verdict,
    required this.feedback,
  });
}

class AiReview {
  final String overall;
  final String confidence;
  final List<AiReviewItem> items;
  final List<String> nextSteps;

  const AiReview({
    required this.overall,
    required this.confidence,
    required this.items,
    required this.nextSteps,
  });

  static AiReview? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final text = raw.trim();
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      final map = Map<String, dynamic>.from(
        jsonDecode(text.substring(start, end + 1)) as Map,
      );
      final items = <AiReviewItem>[];
      final rawItems = map['items'];
      if (rawItems is List) {
        for (final rawItem in rawItems) {
          if (rawItem is! Map) continue;
          final item = Map<String, dynamic>.from(rawItem);
          final number = item['question'];
          final question = number is num
              ? number.toInt()
              : int.tryParse(number?.toString() ?? '') ?? 0;
          if (question <= 0) continue;
          items.add(
            AiReviewItem(
              question: question,
              verdict: (item['verdict'] as String? ?? 'unclear').toLowerCase(),
              feedback: (item['feedback'] as String? ?? '').trim(),
            ),
          );
        }
      }
      return AiReview(
        overall: (map['overall'] as String? ?? '').trim(),
        confidence: (map['confidence'] as String? ?? '').trim(),
        items: items,
        nextSteps:
            (map['nextSteps'] as List?)
                ?.whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList() ??
            <String>[],
      );
    } catch (_) {
      return null;
    }
  }
}

import 'dart:math';

import 'models.dart';

Worksheet generateFallbackWorksheet({
  required String profileId,
  required String subject,
  required String area,
  required int questionCount,
}) {
  final random = Random();
  final count = questionCount.clamp(1, 20).toInt();
  final questions = _questionsFor(subject, area, count, random);
  final pages = <WorksheetPage>[];

  const perPage = 5;
  for (var start = 0; start < questions.length; start += perPage) {
    final end = min(start + perPage, questions.length);
    final blocks = questions.sublist(start, end);
    final pageNumber = pages.length + 1;
    pages.add(
      WorksheetPage(
        title: 'Page $pageNumber',
        sections: [WorksheetSection(title: 'Questions', blocks: blocks)],
      ),
    );
  }

  if (pages.isEmpty) {
    pages.add(
      WorksheetPage(
        title: 'Page 1',
        sections: [
          WorksheetSection(
            title: 'Questions',
            blocks: [_review('Explain what you already know about "$area".')],
          ),
        ],
      ),
    );
  } else if (pages.last.sections.first.blocks.length <= 3) {
    pages.last.sections.add(
      WorksheetSection(
        title: 'Diagram / working space',
        blocks: [
          WorksheetBlock(
            type: BlockType.diagram,
            prompt:
                'Draw a diagram, mind map, or show your working for "$area".',
            height: 170,
          ),
        ],
      ),
    );
  }

  final worksheet = Worksheet(
    id: 'ws_${DateTime.now().microsecondsSinceEpoch}',
    profileId: profileId,
    subject: subject,
    area: area,
    createdAt: DateTime.now().millisecondsSinceEpoch,
    title: area,
    subtitle: subject,
    instructions:
        'Answer in the spaces provided. Show your working where needed. '
        'Use the toolbar to type or draw.',
    pages: pages,
    generator: 'Built-in generator',
  );
  worksheet.assignQuestionIds();
  return worksheet;
}

List<WorksheetBlock> _questionsFor(
  String subject,
  String area,
  int count,
  Random random,
) {
  final subjectKey = subject.toLowerCase();
  final generated = <WorksheetBlock>[];
  final specialised = <WorksheetBlock>[];
  if (RegExp(
    r'math|algebra|geometry|arithmetic|numeracy|statistic|fraction|percent',
  ).hasMatch(subjectKey)) {
    specialised.addAll(_mathQuestions(area, count, random));
  } else if (subjectKey.contains('chem')) {
    specialised.addAll(_chemQuestions(area));
  } else if (subjectKey.contains('phys')) {
    specialised.addAll(_physicsQuestions(area));
  } else if (subjectKey.contains('bio')) {
    specialised.addAll(_biologyQuestions(area));
  } else if (subjectKey.contains('hist')) {
    specialised.addAll(_historyQuestions(area));
  } else if (subjectKey.contains('geo')) {
    specialised.addAll(_geographyQuestions(area));
  } else if (RegExp(r'english|literacy|literature|reading|writing')
      .hasMatch(subjectKey)) {
    specialised.addAll(_englishQuestions(area));
  } else if (subjectKey.trim() == 'science') {
    specialised.addAll(_generalScienceQuestions(area));
  }

  generated.addAll(specialised);
  final reviewPrompts = <String>[
    'Define "$area" in your own words.',
    'Write two key facts about "$area".',
    'Explain why "$area" is important in $subject.',
    'Give a real-world example of "$area".',
    'Describe one thing you find difficult about "$area" and explain how you would work through it.',
    'Write a short summary of "$area" as if you were teaching it to a classmate.',
  ];
  var index = 0;
  while (generated.length < count) {
    generated.add(
      _review(reviewPrompts[index % reviewPrompts.length], lines: 3),
    );
    index += 1;
  }
  return generated.take(count).toList();
}

WorksheetBlock _num(
  String prompt,
  num answer, {
  int lines = 2,
  bool working = true,
}) {
  return WorksheetBlock(
    type: BlockType.question,
    prompt: prompt,
    answer: answer.toString(),
    answerLines: lines,
    workingBox: working,
  );
}

WorksheetBlock _short(
  String prompt,
  String answer, {
  List<String>? keywords,
  int lines = 2,
}) {
  return WorksheetBlock(
    type: BlockType.question,
    prompt: prompt,
    answer: answer,
    keywords: keywords ?? <String>[answer],
    answerLines: lines,
  );
}

WorksheetBlock _review(String prompt, {int lines = 3}) {
  return WorksheetBlock(
    type: BlockType.question,
    prompt: prompt,
    answerLines: lines,
  );
}

List<WorksheetBlock> _mathQuestions(String area, int count, Random random) {
  final key = area.toLowerCase();
  final result = <WorksheetBlock>[];
  for (var index = 0; index < count; index++) {
    final step = index % 4;
    if (key.contains('algebra') ||
        key.contains('equation') ||
        key.contains('linear')) {
      if (step == 0) {
        final x = 2 + random.nextInt(8);
        final coefficient = 2 + random.nextInt(4);
        final constant = 2 + random.nextInt(10);
        result.add(
          _num(
            'Solve for x: ${coefficient}x + $constant = ${coefficient * x + constant}',
            x,
          ),
        );
      } else if (step == 1) {
        final a = 2 + random.nextInt(5);
        final b = 2 + random.nextInt(6);
        result.add(
          _short('Simplify: ${a}x + ${b}x - ${a - 1}x', '${a + b - a + 1}x'),
        );
      } else if (step == 2) {
        final a = 2 + random.nextInt(5);
        final b = 1 + random.nextInt(7);
        final c = 1 + random.nextInt(5);
        result.add(
          _short(
            'Expand and simplify: $a(x + $b) + $c',
            '${a}x + ${a * b + c}',
          ),
        );
      } else {
        final y = 2 + random.nextInt(9);
        final d = 1 + random.nextInt(9);
        result.add(_num('Solve for y: 2y - $d = ${2 * y - d}', y));
      }
    } else if (key.contains('fraction')) {
      if (step == 0) {
        result.add(_num('Write 3/4 as a decimal.', 0.75, working: false));
      } else if (step == 1) {
        final numerator = 2 + random.nextInt(6);
        result.add(_short('Simplify: ${numerator * 2}/$numerator', '2'));
      } else if (step == 2) {
        result.add(
          _short(
            'Calculate: 1/2 + 1/4. Write your answer as a fraction.',
            '3/4',
          ),
        );
      } else {
        final amount = 10 * (1 + random.nextInt(5));
        result.add(_num('What is 2/5 of $amount?', amount * 2 / 5));
      }
    } else if (key.contains('percent')) {
      if (step == 0) {
        final percent = [10, 20, 25, 50][random.nextInt(4)];
        result.add(_num('What is $percent% of 80?', 80 * percent / 100));
      } else if (step == 1) {
        result.add(_num('Write 0.45 as a percentage.', 45, working: false));
      } else if (step == 2) {
        final percent = [10, 20, 25][random.nextInt(3)];
        final price = 20 * (2 + random.nextInt(4));
        result.add(
          _num(
            'A jacket costs \$$price and is reduced by $percent%. What is the new price?',
            price * (100 - percent) / 100,
          ),
        );
      } else {
        result.add(_num('What percentage of 200 is 25?', 12.5, working: false));
      }
    } else if (key.contains('geometry') ||
        key.contains('shape') ||
        key.contains('angle')) {
      if (step == 0) {
        final width = 4 + random.nextInt(9);
        final height = 3 + random.nextInt(8);
        result.add(
          _num(
            'Find the area of a rectangle $width cm x $height cm.',
            width * height,
          ),
        );
      } else if (step == 1) {
        result.add(
          _num(
            'The angles in a triangle add up to how many degrees?',
            180,
            working: false,
          ),
        );
      } else if (step == 2) {
        final base = 4 + random.nextInt(10);
        final height = 2 + random.nextInt(8);
        result.add(
          _num(
            'Find the area of a triangle with base $base cm and height $height cm.',
            base * height / 2,
          ),
        );
      } else {
        result.add(
          _num(
            'A circle has radius 5 cm. Find its area (use pi = 3.14).',
            78.5,
            working: true,
          ),
        );
      }
    } else {
      if (step == 0) {
        final a = 12 + random.nextInt(38);
        final b = 3 + random.nextInt(10);
        result.add(_num('Calculate: $a x $b', a * b));
      } else if (step == 1) {
        final a = 60 + random.nextInt(90);
        final b = 11 + random.nextInt(25);
        result.add(_num('Calculate: $a - $b', a - b));
      } else if (step == 2) {
        final a = 40 + random.nextInt(90);
        final b = 11 + random.nextInt(30);
        result.add(_num('Calculate: $a + $b', a + b));
      } else {
        final a = 4 + random.nextInt(12);
        result.add(_num('Calculate: ${a * 4} / 4', a, working: false));
      }
    }
  }
  return result;
}

List<WorksheetBlock> _chemQuestions(String area) {
  return [
    _short(
      'What is the pH of a neutral solution?',
      '7',
      keywords: ['7', 'seven'],
    ),
    _short(
      'Name the gas released when an acid reacts with a metal.',
      'hydrogen',
    ),
    _short(
      'Write the chemical formula for water.',
      'H2O',
      keywords: ['h2o', 'h₂o'],
    ),
    _short('What is the chemical symbol for sodium?', 'Na'),
    _short('What type of bond shares electrons between atoms?', 'covalent'),
    _short(
      'What gas do plants take in during photosynthesis?',
      'carbon dioxide',
      keywords: ['carbon dioxide', 'co2'],
    ),
    _review('Explain one key idea about $area.'),
  ];
}

List<WorksheetBlock> _physicsQuestions(String area) {
  return [
    _short(
      'What is the SI unit of force?',
      'newton',
      keywords: ['newton', 'n'],
    ),
    _short('Complete the formula: speed = distance / ____.', 'time'),
    _short(
      'What is the SI unit of electric current?',
      'ampere',
      keywords: ['ampere', 'amp', 'a'],
    ),
    _short('What is the SI unit of energy?', 'joule', keywords: ['joule', 'j']),
    _short('What is the SI unit of power?', 'watt', keywords: ['watt', 'w']),
    _review('Explain one real-world example of $area.'),
  ];
}

List<WorksheetBlock> _biologyQuestions(String area) {
  return [
    _short(
      'Which organelle is known as the powerhouse of the cell?',
      'mitochondria',
      keywords: ['mitochondria', 'mitochondrion'],
    ),
    _short(
      'What process do plants use to make food from sunlight?',
      'photosynthesis',
    ),
    _short(
      'What molecule carries genetic information?',
      'DNA',
      keywords: ['dna', 'deoxyribonucleic'],
    ),
    _short(
      'What structure surrounds a plant cell and gives it support?',
      'cell wall',
    ),
    _short(
      'What is the process called when water moves across a membrane?',
      'osmosis',
    ),
    _review('Describe one thing you know about $area.'),
  ];
}

List<WorksheetBlock> _historyQuestions(String area) {
  return [
    _short(
      'What does "chronology" mean?',
      'order of time',
      keywords: ['order of time', 'time order', 'order'],
    ),
    _short(
      'A first-hand account from the time is called a ______ source.',
      'primary',
    ),
    _short(
      'In which century did the First World War begin?',
      '20th',
      keywords: ['20th', 'twentieth'],
    ),
    _short(
      'What is a secondary source?',
      'second-hand interpretation',
      keywords: ['second-hand', 'secondhand', 'interpretation'],
    ),
    _review('Explain why $area is important.'),
  ];
}

List<WorksheetBlock> _geographyQuestions(String area) {
  return [
    _short(
      'What is the imaginary line at 0 degrees latitude called?',
      'equator',
    ),
    _short(
      'What is the process called when water turns into vapour?',
      'evaporation',
    ),
    _short('Name the largest ocean on Earth.', 'Pacific'),
    _short(
      'What is erosion?',
      'wearing away of rock and soil',
      keywords: ['wearing away', 'movement of rock', 'rock and soil'],
    ),
    _short(
      'Name one physical feature formed by a river.',
      'meander',
      keywords: ['meander', 'waterfall', 'valley', 'delta', 'floodplain'],
    ),
    _review('Describe one feature of $area.'),
  ];
}

List<WorksheetBlock> _englishQuestions(String area) {
  return [
    _short(
      'Give one synonym for "rapid".',
      'quick',
      keywords: ['quick', 'fast', 'swift'],
    ),
    _short(
      'What punctuation mark ends a question?',
      'question mark',
      keywords: ['question mark', '?'],
    ),
    _short(
      'What is a metaphor?',
      'comparison',
      keywords: ['comparison', 'compare', 'describes something as'],
    ),
    _short(
      'What is a simile?',
      'comparison using like or as',
      keywords: ['like or as', 'compares', 'comparison'],
    ),
    _short(
      'What is alliteration?',
      'repetition of initial sounds',
      keywords: ['repetition', 'initial sounds', 'same sound'],
    ),
    _short(
      'What is a noun?',
      'naming word',
      keywords: ['naming word', 'person place thing', 'person, place'],
    ),
    _review('Write a short paragraph about $area.'),
  ];
}

List<WorksheetBlock> _generalScienceQuestions(String area) {
  return [
    _short(
      'What is the SI unit of force?',
      'newton',
      keywords: ['newton', 'n'],
    ),
    _short('What process do plants use to make food?', 'photosynthesis'),
    _short('What is the chemical symbol for oxygen?', 'O'),
    _short(
      'Name the three states of matter.',
      'solid, liquid and gas',
      keywords: ['solid', 'liquid', 'gas'],
    ),
    _review('Explain one key idea about $area.'),
  ];
}

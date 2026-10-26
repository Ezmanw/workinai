import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workinai/ai_service.dart';
import 'package:workinai/app_scope.dart';
import 'package:workinai/app_state.dart';
import 'package:workinai/fallback_generator.dart';
import 'package:workinai/models.dart';
import 'package:workinai/screens/worksheet_screen.dart';

Worksheet _buildWorksheet(String profileId) {
  return Worksheet(
    id: 'test_sheet',
    profileId: profileId,
    subject: 'Maths',
    area: 'Arithmetic',
    createdAt: DateTime(2026, 10, 26).millisecondsSinceEpoch,
    title: 'Quick arithmetic',
    subtitle: 'Maths - Year 5',
    instructions: 'Answer in the spaces provided.',
    pages: [
      WorksheetPage(
        title: 'Page 1',
        sections: [
          WorksheetSection(
            title: 'Questions',
            blocks: [
              WorksheetBlock(
                type: BlockType.question,
                prompt: '2 + 2 = ?',
                answer: '4',
                keywords: const ['4', 'four'],
                answerLines: 1,
              ),
              WorksheetBlock(
                type: BlockType.question,
                prompt: 'What is the capital of France?',
                answer: 'Paris',
                keywords: const ['paris'],
                answerLines: 1,
              ),
            ],
          ),
        ],
      ),
    ],
  )..assignQuestionIds();
}

Worksheet _buildStyleWorksheet(String profileId) {
  return Worksheet(
    id: 'style_sheet',
    profileId: profileId,
    subject: 'Science',
    area: 'The Solar System',
    createdAt: DateTime(2026, 10, 26).millisecondsSinceEpoch,
    title: 'Solar System review',
    subtitle: 'Science - Year 5',
    instructions: 'Choose one letter or draw a line for each question.',
    pages: [
      WorksheetPage(
        title: 'Page 1',
        sections: [
          WorksheetSection(
            title: 'Questions',
            blocks: [
              WorksheetBlock(
                type: BlockType.question,
                prompt: 'Which is the largest planet in the Solar System?',
                style: QuestionStyle.choice,
                options: const ['Jupiter', 'Saturn', 'Neptune'],
                answer: 'A',
              ),
              WorksheetBlock(
                type: BlockType.question,
                prompt: 'Match each planet to its description.',
                style: QuestionStyle.matching,
                leftItems: const ['Mercury', 'Venus', 'Earth'],
                rightItems: const [
                  'Our home planet',
                  'Closest to the Sun',
                  'Hottest planet',
                ],
                matches: const ['B', 'C', 'A'],
              ),
            ],
          ),
        ],
      ),
    ],
  )..assignQuestionIds();
}

String _reviewJson({String overall = 'Good work'}) {
  return jsonEncode({
    'overall': overall,
    'confidence': 'high',
    'items': [
      {'question': 1, 'verdict': 'correct', 'feedback': 'Yes, 2 + 2 is 4.'},
    ],
    'nextSteps': ['Try another addition question.'],
  });
}

http.Response _reviewResponse(String content) {
  return http.Response(
    jsonEncode({
      'choices': [
        {
          'message': {'content': content},
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  test('fallback generator spreads questions over multiple pages', () {
    final worksheet = generateFallbackWorksheet(
      profileId: 'p1',
      subject: 'Maths',
      area: 'Fractions',
      questionCount: 12,
    );
    expect(worksheet.questionCount, 12);
    expect(worksheet.pages.length, 3);
    expect(worksheet.pages.first.sections.first.blocks.length, 5);
  });

  test('compact AI pages are reflowed to fit five questions per page', () {
    final worksheet = Worksheet.fromAiJson(
      {
        'title': 'Photosynthesis review',
        'subtitle': 'Science · Year 7',
        'instructions': 'Answer every question in the space provided.',
        'pages': [
          {
            'title': 'Page 1',
            'questions': [
              for (var index = 1; index <= 6; index++)
                {
                  'prompt': 'Question $index about photosynthesis?',
                  'answer': 'Answer $index',
                  'keywords': ['photosynthesis', 'answer $index'],
                  'answerLines': 2,
                  'workingBox': false,
                },
            ],
          },
        ],
      },
      profileId: 'p1',
      subject: 'Science',
      area: 'Photosynthesis',
      questionTarget: 6,
    );

    expect(worksheet.questionCount, 6);
    expect(worksheet.pages.length, 2);
    expect(
      worksheet.pages.first.sections
          .expand((section) => section.blocks)
          .where((block) => block.type == BlockType.question)
          .length,
      5,
    );
    expect(worksheet.questions.last.number, 6);
    expect(
      worksheet.instructions,
      'Answer every question in the space provided.',
    );
  });

  test('flat AI questions are placed on pages automatically', () {
    final worksheet = Worksheet.fromAiJson(
      {
        'title': 'Quick maths',
        'questions': [
          for (var index = 1; index <= 7; index++)
            {
              'prompt': '$index + 1 = ?',
              'answer': '${index + 1}',
              'keywords': ['${index + 1}'],
              'answerLines': 1,
            },
        ],
      },
      profileId: 'p1',
      subject: 'Maths',
      area: 'Addition',
      questionTarget: 7,
    );

    expect(worksheet.questionCount, 7);
    expect(worksheet.pages.length, 2);
    expect(worksheet.pages.first.sections.first.blocks.length, 5);
  });

  test('AI type quirks are parsed without crashing', () {
    final worksheet = Worksheet.fromAiJson(
      {
        'title': 'Tolerant parsing',
        'questions': [
          {
            'prompt': 'What is 2 + 2?',
            'answer': '4',
            'keywords': 'four, 4, four',
            'answerLines': [2],
            'workingBox': 'yes',
          },
        ],
      },
      profileId: 'p1',
      subject: 'Maths',
      area: 'Addition',
      questionTarget: 1,
    );

    final question = worksheet.questions.single.block;
    expect(question.answerLines, 2);
    expect(question.workingBox, isTrue);
    expect(question.keywords, ['four', '4']);
  });

  test('placeholder-only questions and half-empty AI output are rejected', () {
    expect(
      () => Worksheet.fromAiJson(
        {
          'pages': [
            {
              'questions': [
                {
                  'prompt': 'question text',
                  'answer': 'model answer',
                  'keywords': ['word'],
                },
              ],
            },
          ],
        },
        profileId: 'p1',
        subject: 'Science',
        area: 'Photosynthesis',
        questionTarget: 6,
      ),
      throwsFormatException,
    );
  });

  testWidgets('typing, checking and drawing on a worksheet', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final worksheet = _buildWorksheet(state.currentProfile.id);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: WorksheetScreen(worksheet: worksheet)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 + 2 = ?'), findsOneWidget);
    expect(find.text('What is the capital of France?'), findsOneWidget);
    expect(find.text('Page 1 of 1'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '4');
    await tester.enterText(find.byType(TextField).at(1), 'Paris');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(worksheet.correct, 2);
    expect(worksheet.total, 2);
    expect(worksheet.score, 100);
    expect(find.text('Correct'), findsNWidgets(2));

    await tester.tap(find.text('Draw'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Eraser'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 300), const Offset(60, 50));
    await tester.pumpAndSettle();
    expect(worksheet.strokes.length, 1);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(worksheet.strokes, isEmpty);

    await tester.pump(const Duration(seconds: 1));
  });

  test('AI choice, matching, diagram and key-term blocks are parsed', () {
    final worksheet = Worksheet.fromAiJson(
      {
        'title': 'Cells review',
        'subtitle': 'Science - Year 7',
        'instructions': 'Answer every question.',
        'keyTerms': ['nucleus', 'cytoplasm', 'membrane'],
        'questions': [
          {
            'style': 'choice',
            'prompt': 'Which part controls what enters a cell?',
            'options': ['Nucleus', 'Cell membrane', 'Cytoplasm'],
            'answer': 'B. Cell membrane',
          },
          {
            'style': 'matching',
            'prompt': 'Match each cell part to its job.',
            'left': ['Nucleus', 'Cell membrane', 'Cytoplasm'],
            'right': [
              'Jelly-like fluid',
              'Contains DNA',
              'Controls what enters',
            ],
            'matches': ['B', 'C', 'A'],
          },
          {
            'style': 'short',
            'prompt': 'Name one organelle found in a plant cell.',
            'answer': 'Nucleus',
            'keywords': ['nucleus', 'chloroplast'],
          },
        ],
        'diagrams': [
          {'prompt': 'Draw and label a plant cell.', 'height': 200},
        ],
      },
      profileId: 'p1',
      subject: 'Science',
      area: 'Cells',
      questionTarget: 3,
    );

    expect(worksheet.questionCount, 3);
    final blocks = worksheet.pages
        .expand((page) => page.sections)
        .expand((section) => section.blocks)
        .toList();

    final choice = worksheet.questions[0].block;
    expect(choice.style, QuestionStyle.choice);
    expect(choice.isChoice, isTrue);
    expect(choice.options, ['Nucleus', 'Cell membrane', 'Cytoplasm']);
    expect(choice.answer, 'B');
    expect(choice.displayAnswer, 'B. Cell membrane');

    final matching = worksheet.questions[1].block;
    expect(matching.style, QuestionStyle.matching);
    expect(matching.isMatching, isTrue);
    expect(matching.matches, ['B', 'C', 'A']);
    expect(
      matching.displayAnswer,
      '1-B (Contains DNA) · 2-C (Controls what enters) · '
      '3-A (Jelly-like fluid)',
    );

    final diagrams = blocks
        .where((block) => block.type == BlockType.diagram)
        .toList();
    expect(diagrams, hasLength(1));
    expect(diagrams.single.prompt, 'Draw and label a plant cell.');
    expect(diagrams.single.height, 200);

    expect(
      blocks
          .where((block) => block.type == BlockType.text)
          .any((block) => block.text.contains('nucleus')),
      isTrue,
    );
  });

  testWidgets('choice and matching questions can be answered and checked', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.load();
    final worksheet = _buildStyleWorksheet(state.currentProfile.id);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: WorksheetScreen(worksheet: worksheet)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Which is the largest planet in the Solar System?'),
      findsOneWidget,
    );
    expect(find.text('Match each planet to its description.'), findsOneWidget);

    await tester.tap(find.text('Jupiter'));
    await tester.pumpAndSettle();
    expect(find.text('Correct answer: A. Jupiter'), findsNothing);

    await tester.enterText(find.byType(TextField), '1-B, 2-C, 3-A');
    await tester.tap(find.text('Check'));
    await tester.pumpAndSettle();

    expect(worksheet.correct, 2);
    expect(worksheet.total, 2);
    expect(worksheet.score, 100);
    expect(find.text('Correct answer: A. Jupiter'), findsOneWidget);
    expect(
      find.text(
        'Correct pairs: 1-B (Closest to the Sun) · '
        '2-C (Hottest planet) · 3-A (Our home planet)',
      ),
      findsOneWidget,
    );
  });

  test('text-only AI review sends typed answers and no images', () async {
    Map<String, dynamic>? requestBody;
    final client = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return _reviewResponse(_reviewJson());
    });
    final worksheet = _buildWorksheet('p1');
    worksheet.answers[worksheet.questions.first.id] = '4';

    final service = AiService(
      AiSettings(baseUrl: 'http://localhost:9/v1', model: 'deepseek-r1:1.5b'),
      client: client,
    );
    final result = await service.reviewWorksheet(worksheet: worksheet);

    expect(result.usedVision, isFalse);
    expect(result.note, contains('Checked typed answers only'));
    expect(result.json, contains('Good work'));

    final messages = requestBody!['messages'] as List;
    expect(messages, hasLength(2));
    final userContent = (messages[1] as Map)['content'];
    expect(userContent, isA<String>());
    expect(userContent as String, contains('2 + 2 = ?'));
    expect(userContent, contains('"studentAnswer": "4"'));
  });

  test(
    'AI review falls back to typed answers when vision is rejected',
    () async {
      var calls = 0;
      final modes = <String>[];
      final client = MockClient((request) async {
        calls += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final messages = body['messages'] as List;
        final content = (messages[1] as Map)['content'];
        if (calls == 1) {
          expect(content, isA<List>());
          modes.add('vision');
          return http.Response(
            jsonEncode({
              'error': {'message': 'this model does not support images'},
            }),
            400,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(content, isA<String>());
        modes.add('text');
        return _reviewResponse(_reviewJson());
      });
      final worksheet = _buildWorksheet('p1');
      worksheet.answers[worksheet.questions.first.id] = '4';

      final service = AiService(
        AiSettings(baseUrl: 'http://localhost:9/v1', model: 'deepseek-r1:1.5b'),
        client: client,
      );
      final result = await service.reviewWorksheet(
        worksheet: worksheet,
        pageImages: [
          Uint8List.fromList([137, 80, 78, 71]),
        ],
      );

      expect(calls, 2);
      expect(modes, ['vision', 'text']);
      expect(result.usedVision, isFalse);
      expect(result.note, contains('only typed answers were checked'));
      expect(result.json, contains('Good work'));
    },
  );
}

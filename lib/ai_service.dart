import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => message;
}

class AiReviewResult {
  final String json;
  final bool usedVision;
  final String? note;

  const AiReviewResult({
    required this.json,
    required this.usedVision,
    this.note,
  });
}

class AiService {
  final AiSettings settings;
  final http.Client? client;
  AiService(this.settings, {this.client});

  static const _timeout = Duration(seconds: 300);

  Future<Worksheet> generateWorksheet({
    required String profileId,
    required String subject,
    required String area,
    required String level,
    required String notes,
    required int questionCount,
  }) async {
    final raw = await _complete(
      system: settings.isLocal
          ? _flatSystemPrompt(questionCount)
          : _layoutSystemPrompt(questionCount),
      user: _layoutUserPrompt(
        subject: subject,
        area: area,
        level: level,
        notes: notes,
        questionCount: questionCount,
      ),
      json: true,
      maxTokens: 6000,
    );
    final documents = _parseJsonObjects(raw);
    FormatException? failure;
    for (final json in documents) {
      try {
        return Worksheet.fromAiJson(
          json,
          profileId: profileId,
          subject: subject,
          area: area,
          questionTarget: questionCount,
          generator: settings.activeModel,
        );
      } on FormatException catch (error) {
        failure = error;
      }
    }

    final questions = <Map<String, dynamic>>[];
    final seenQuestions = <String>{};
    for (final document in documents) {
      final prompt = document['prompt'];
      if (prompt is! String || prompt.trim().isEmpty) continue;
      final key = prompt.trim().toLowerCase();
      if (!seenQuestions.add(key)) continue;
      questions.add(document);
    }
    if (questions.isNotEmpty) {
      final first = documents.firstWhere(
        (document) => document['title'] is String,
        orElse: () => <String, dynamic>{},
      );
      try {
        return Worksheet.fromAiJson(
          {
            'title': first['title'] ?? area,
            'subtitle': first['subtitle'] ?? subject,
            'instructions': first['instructions'] ?? '',
            'questions': questions,
          },
          profileId: profileId,
          subject: subject,
          area: area,
          questionTarget: questionCount,
          generator: settings.activeModel,
        );
      } on FormatException catch (error) {
        failure = error;
      }
    }

    throw AiException(
      'The AI layout was unusable: ${failure?.message ?? 'no worksheet object was found.'}',
    );
  }

  Future<AiReviewResult> reviewWorksheet({
    required Worksheet worksheet,
    List<Uint8List> pageImages = const <Uint8List>[],
  }) async {
    final hasTypedAnswer = worksheet.questions.any(
      (question) => (worksheet.answers[question.id] ?? '').trim().isNotEmpty,
    );
    if (!hasTypedAnswer && pageImages.isEmpty) {
      throw const AiException(
        'Type an answer or add some drawing before asking AI to check the work.',
      );
    }

    final payload = _reviewPayload(worksheet, vision: pageImages.isNotEmpty);
    if (pageImages.isNotEmpty) {
      try {
        final review = await _requestReview(
          payload,
          images: pageImages,
          vision: true,
        );
        return AiReviewResult(json: review, usedVision: true);
      } on AiException catch (error) {
        if (!_shouldRetryReviewAsText(error)) rethrow;
        final review = await _requestReview(
          _reviewPayload(worksheet, vision: false),
          images: const <Uint8List>[],
          vision: false,
        );
        return AiReviewResult(
          json: review,
          usedVision: false,
          note:
              'The model could not read the page images, so only typed answers were checked. '
              'Handwriting and drawings were not marked.',
        );
      }
    }

    final review = await _requestReview(
      payload,
      images: const <Uint8List>[],
      vision: false,
    );
    return AiReviewResult(
      json: review,
      usedVision: false,
      note: 'Checked typed answers only. Handwriting and drawings were not sent for review.',
    );
  }

  Map<String, dynamic> _reviewPayload(
    Worksheet worksheet, {
    required bool vision,
  }) {
    return <String, dynamic>{
      'subject': worksheet.subject,
      'area': worksheet.area,
      'reviewMode': vision
          ? 'typed answers plus page images'
          : 'typed answers only',
      'questions': worksheet.questions.map((question) {
        final block = question.block;
        return <String, dynamic>{
          'number': question.number,
          'style': block.style.name,
          'prompt': block.prompt,
          'expected': block.displayAnswer,
          'keywords': block.keywords,
          'options': block.options,
          'left': block.leftItems,
          'right': block.rightItems,
          'expectedPairs': block.matches,
          'studentAnswer': worksheet.answers[question.id] ?? '',
          'currentMark': worksheet.marks[question.id] ?? 'unmarked',
        };
      }).toList(),
      'note':
          'Questions may be short written answers, multiple choice (A/B/C), '
          'or matching pairs. Matching answers should be written like 1-B, 2-C, 3-A.',
    };
  }

  Future<String> _requestReview(
    Map<String, dynamic> payload, {
    required List<Uint8List> images,
    required bool vision,
  }) async {
    final raw = await _complete(
      system: vision ? _reviewVisionSystemPrompt : _reviewTextSystemPrompt,
      user: vision
          ? 'Review this work. Worksheet data:\n'
                '${const JsonEncoder.withIndent('  ').convert(payload)}\n\n'
                'The attached images show the worksheet pages in order, including handwriting '
                'and drawings. Use both the typed answers and the images. '
                'Return the JSON review only.'
          : 'Review this work using the typed answers only. Worksheet data:\n'
                '${const JsonEncoder.withIndent('  ').convert(payload)}\n\n'
                'You cannot see the page, handwriting or drawings. Do not pretend that you can. '
                'Return the JSON review only.',
      images: images,
      json: true,
      maxTokens: 3000,
    );
    final documents = _parseJsonObjects(raw);
    if (documents.isEmpty) {
      throw const AiException('The AI did not return a review.');
    }
    final review = documents.firstWhere(
      (document) =>
          document['items'] is List ||
          document['overall'] is String ||
          document['nextSteps'] is List,
      orElse: () => documents.first,
    );
    return jsonEncode(review);
  }

  bool _shouldRetryReviewAsText(AiException error) {
    final text = error.message.toLowerCase();
    if (text.contains('could not reach') ||
        text.contains('network error') ||
        text.contains('took too long')) {
      return false;
    }
    return true;
  }

  Future<String> testConnection() async {
    final response = await _complete(
      system: 'You are a connection test. Reply with the single word OK.',
      user: 'Reply with OK.',
      json: false,
      maxTokens: 700,
    );
    final trimmed = response.trim();
    if (trimmed.isEmpty) {
      throw const AiException(
        'The server replied, but the response was empty.',
      );
    }
    return trimmed.length > 120 ? trimmed.substring(0, 120) : trimmed;
  }

  Future<String> _complete({
    required String system,
    required String user,
    List<Uint8List>? images,
    required bool json,
    required int maxTokens,
  }) {
    return settings.isLocal
        ? _localComplete(
            system: system,
            user: user,
            images: images,
            json: json,
            maxTokens: maxTokens,
          )
        : _geminiComplete(
            system: system,
            user: user,
            images: images,
            json: json,
            maxTokens: maxTokens,
          );
  }

  Future<String> _localComplete({
    required String system,
    required String user,
    List<Uint8List>? images,
    required bool json,
    required int maxTokens,
  }) async {
    final base = settings.baseUrl.trim();
    if (base.isEmpty) {
      throw const AiException('Set your local LLM server URL in Settings.');
    }
    if (settings.model.trim().isEmpty) {
      throw const AiException('Set the model name in Settings.');
    }
    final uri = Uri.tryParse(_localChatUrl(base));
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AiException(
        'That server URL does not look valid. Example: http://192.168.1.20:1234/v1',
      );
    }

    final content = images == null || images.isEmpty
        ? user
        : <Map<String, dynamic>>[
            {'type': 'text', 'text': user},
            for (final image in images)
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,${base64Encode(image)}',
                },
              },
          ];

    final body = <String, dynamic>{
      'model': settings.model.trim(),
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': content},
      ],
      'temperature': 0.3,
      'max_tokens': maxTokens,
      if (json) 'response_format': {'type': 'json_object'},
    };
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (settings.apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${settings.apiKey.trim()}',
    };

    var response = await _post(uri, headers, body);
    if (json && response.statusCode == 400) {
      final detail = response.body.toLowerCase();
      if (detail.contains('response_format') ||
          detail.contains('response format') ||
          detail.contains('unknown field')) {
        body.remove('response_format');
        response = await _post(uri, headers, body);
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        'Local server returned ${response.statusCode}: ${_errorMessage(response.body)}',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final message = choices.first is Map
              ? (choices.first as Map)['message']
              : null;
          final value = message is Map ? message['content'] : null;
          if (value is String && value.trim().isNotEmpty) return value;
          if (value is List) {
            final parts = value
                .whereType<Map>()
                .where((part) => part['type'] == 'text')
                .map((part) => part['text']?.toString() ?? '')
                .where((part) => part.isNotEmpty)
                .join('\n');
            if (parts.trim().isNotEmpty) return parts;
          }
          final text = choices.first is Map
              ? (choices.first as Map)['text']
              : null;
          if (text is String && text.trim().isNotEmpty) return text;
          final reasoning = message is Map
              ? (message['reasoning'] ?? message['reasoning_content'])
              : null;
          if (reasoning is String && reasoning.trim().isNotEmpty) {
            throw const AiException(
              'The model spent all of its tokens thinking and never wrote a final answer. '
              'Try again, ask for fewer questions, or use a model that does not reason before answering.',
            );
          }
        }
      }
    } catch (error) {
      if (error is AiException) rethrow;
      throw AiException('Could not read the local server response: $error');
    }
    throw const AiException(
      'The local server returned an unexpected response. Check that it uses the OpenAI-compatible /v1 API.',
    );
  }

  Future<String> _geminiComplete({
    required String system,
    required String user,
    List<Uint8List>? images,
    required bool json,
    required int maxTokens,
  }) async {
    final key = settings.geminiKey.trim();
    if (key.isEmpty) {
      throw const AiException(
        'Add your Gemini API key in Settings, or switch to a local server.',
      );
    }
    final model = settings.geminiModel.trim().isEmpty
        ? 'gemini-2.5-flash'
        : settings.geminiModel.trim();
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
      {'key': key},
    );
    final parts = <Map<String, dynamic>>[
      {'text': user},
      for (final image in images ?? <Uint8List>[])
        {
          'inline_data': {
            'mime_type': 'image/png',
            'data': base64Encode(image),
          },
        },
    ];
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0.35,
        'maxOutputTokens': maxTokens,
        if (json) 'responseMimeType': 'application/json',
      },
    };

    final response = await _post(uri, const {
      'Content-Type': 'application/json; charset=utf-8',
    }, body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiException(
        'Gemini returned ${response.statusCode}: ${_errorMessage(response.body)}',
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      final candidates = decoded is Map ? decoded['candidates'] : null;
      if (candidates is List && candidates.isNotEmpty) {
        final content = candidates.first is Map
            ? (candidates.first as Map)['content']
            : null;
        final parts = content is Map ? content['parts'] : null;
        if (parts is List) {
          final text = parts
              .whereType<Map>()
              .map((part) => part['text']?.toString() ?? '')
              .where((value) => value.isNotEmpty)
              .join('\n');
          if (text.trim().isNotEmpty) return text;
        }
      }
    } catch (error) {
      throw AiException('Could not read the Gemini response: $error');
    }
    throw const AiException('Gemini returned an unexpected response.');
  }

  Future<http.Response> _post(
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    final client = this.client ?? http.Client();
    try {
      return await client
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
    } on TimeoutException {
      throw const AiException(
        'The AI server took too long to respond. Try a smaller worksheet or check the server.',
      );
    } on http.ClientException catch (error) {
      throw AiException(
        'Could not reach the AI server. Check the URL and network, and enable CORS on the server. '
        'Details: ${error.message}',
      );
    } catch (error) {
      throw AiException('Network error: $error');
    } finally {
      if (this.client == null) client.close();
    }
  }

  String _localChatUrl(String base) {
    var value = base.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.endsWith('/chat/completions')) return value;
    final uri = Uri.tryParse(value);
    if (uri == null) return value;
    if (uri.path.endsWith('/v1')) return '$value/chat/completions';
    if (uri.path.contains('/v1/')) return '$value/chat/completions';
    return '$value/v1/chat/completions';
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {
      // Fall through to the raw body.
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty) return 'no response body';
    return trimmed.length > 500 ? '${trimmed.substring(0, 500)}...' : trimmed;
  }

  List<Map<String, dynamic>> _parseJsonObjects(String raw) {
    var text = raw.trim();
    text = text
        .replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '')
        .replaceAll('```', '')
        .trim();
    if (!text.contains('{')) {
      throw AiException('The AI did not return JSON. ${_responsePreview(raw)}');
    }

    final documents = <Map<String, dynamic>>[];
    for (final candidate in _jsonCandidates(text)) {
      Map<String, dynamic>? parsed;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map) parsed = Map<String, dynamic>.from(decoded);
      } catch (_) {
        final repaired = _repairJson(candidate);
        if (repaired != candidate) {
          try {
            final decoded = jsonDecode(repaired);
            if (decoded is Map) {
              parsed = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {
            // Try the next object in the response.
          }
        }
      }
      if (parsed != null && parsed.isNotEmpty) documents.add(parsed);
    }
    if (documents.isEmpty) {
      throw AiException(
        'The AI returned invalid JSON. ${_responsePreview(raw)}',
      );
    }
    return documents;
  }

  Iterable<String> _jsonCandidates(String text) sync* {
    for (
      var start = text.indexOf('{');
      start >= 0;
      start = text.indexOf('{', start + 1)
    ) {
      var depth = 0;
      var inString = false;
      var escaped = false;
      for (var index = start; index < text.length; index++) {
        final char = text[index];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (char == r'\') {
            escaped = true;
          } else if (char == '"') {
            inString = false;
          }
          continue;
        }
        if (char == '"') {
          inString = true;
        } else if (char == '{') {
          depth += 1;
        } else if (char == '}') {
          depth -= 1;
          if (depth == 0) {
            yield text.substring(start, index + 1);
            break;
          }
        }
      }
    }
  }

  String _repairJson(String value) {
    return value.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
  }

  String _responsePreview(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return 'The model sent an empty response.';
    final preview = cleaned.length > 700
        ? '${cleaned.substring(0, 700)}…'
        : cleaned;
    return 'Response started: $preview';
  }

  String _flatSystemPrompt(int questionCount) {
    return '''
You are an expert teacher and worksheet designer.
Design a printable revision worksheet. Return ONLY one JSON object. No code fences, no markdown, no explanation.

Use exactly this structure with empty values:
{
  "title": "",
  "subtitle": "",
  "instructions": "",
  "keyTerms": [],
  "questions": [
    {"style": "short", "prompt": "", "answer": "", "keywords": [], "answerLines": 2, "workingBox": false},
    {"style": "choice", "prompt": "", "options": ["", "", ""], "answer": "A", "keywords": []},
    {"style": "matching", "prompt": "Match each item with the correct answer.", "left": ["", "", ""], "right": ["", "", ""], "matches": ["B", "C", "A"], "answer": ""}
  ],
  "diagrams": [
    {"prompt": "", "height": 160}
  ]
}

Field guide:
- title: a short title for the worksheet.
- subtitle: the subject and level.
- instructions: one short sentence telling the student what to do.
- keyTerms: optional list of 3 to 6 important words for the topic.
- style: "short", "long", "choice" or "matching".
- short: a written question with 1 to 6 answerLines.
- long: a longer written question with 3 to 6 answerLines.
- choice: a multiple-choice question with exactly 3 options and the correct letter (A, B or C) as answer.
- matching: 3 or 4 left items and 3 or 4 right items. Shuffle the right items. List the correct letter for each left item in matches.
- answer: a complete model answer for written questions and the correct letter for choice questions.
- keywords: 1 to 5 short lowercase words or alternatives used for marking.
- diagrams: optional 1 or 2 drawing/working boxes. The prompt must tell the student what to draw or label. height is 120 to 240.

Rules:
1. Put EXACTLY $questionCount question objects in the "questions" array. Count them before you finish. Choice and matching each count as one question.
2. Use a mix of styles: at least one choice question, one matching question when there are 4 or more questions, and at least one longer written answer.
3. Do NOT create pages inside the JSON. The app will lay out the pages.
4. Fill every field with real content. Do not copy this schema text or leave fields empty.
5. Every written question MUST have a full answer and 1 to 5 lowercase keywords. A choice question must have exactly one correct option.
6. Vary the questions: recall, explain, apply and one challenge.
7. Write real subject questions only. Do not write meta questions about the test, and never include a false premise.
8. Keep them answerable without the internet.
9. Use British English unless the subject requires otherwise.
10. Never reveal answers or marking notes in a prompt, option or instruction.
11. Use plain Unicode text. No images, LaTeX, markdown or code fences.
''';
  }

  String _layoutSystemPrompt(int questionCount) {
    return '''
You are an expert teacher and worksheet designer.
Design one printable revision worksheet. Return ONLY a JSON object. No code fences, no markdown, no explanation.

Use exactly this structure with empty values:
{
  "title": "",
  "subtitle": "",
  "instructions": "",
  "pages": [
    {
      "title": "",
      "sections": [
        {
          "title": "",
          "blocks": [
            {"type": "text", "text": ""},
            {"type": "question", "style": "short", "prompt": "", "answer": "", "keywords": [], "answerLines": 2, "workingBox": false},
            {"type": "question", "style": "choice", "prompt": "", "options": ["", "", ""], "answer": "A", "keywords": []},
            {"type": "question", "style": "matching", "prompt": "Match each item with the correct answer.", "left": ["", "", ""], "right": ["", "", ""], "matches": ["B", "C", "A"], "answer": ""},
            {"type": "diagram", "prompt": "", "height": 160}
          ]
        }
      ]
    }
  ]
}

Field guide:
- title: a short title for the worksheet.
- subtitle: the subject and level.
- instructions: one short sentence telling the student what to do.
- pages: 1 to 4 A4 pages. Place content in sections and blocks.
- text blocks: short intros, key terms or word banks.
- question styles: "short", "long", "choice" or "matching".
- choice questions: exactly 3 options and the correct letter (A, B or C) as answer.
- matching questions: 3 or 4 left items and 3 or 4 right items. Shuffle the right column. List the correct letter for each left item in matches.
- diagram blocks: a prompt telling the student what to draw or label, plus a height from 120 to 240.
- answer: a complete model answer for written questions and the correct letter for choice questions.
- keywords: 1 to 5 short lowercase words or alternatives used for marking.

Rules:
1. Create EXACTLY $questionCount question blocks in total. Count them before you finish. Choice and matching each count as one.
2. Use 1 to 4 pages and no more than 5 questions per page. Every page needs at least one question.
3. Use a mix of styles: at least one choice question, one matching question when there are 4 or more questions, and at least one longer written answer.
4. Add 1 or 2 diagram/working blocks when they help; diagrams do not count as questions.
5. Fill every field with real content. Do not copy this schema text or leave fields empty.
6. Every written question MUST have a full answer and 1 to 5 lowercase keywords. A choice question must have exactly one correct option.
7. Vary the questions: recall, explain, apply and one challenge. Keep them answerable without the internet.
8. Use British English unless the subject requires otherwise.
9. Never reveal answers or marking notes in a prompt, option or instruction.
10. Use plain Unicode text. No images, LaTeX, markdown or code fences.
''';
  }

  String _layoutUserPrompt({
    required String subject,
    required String area,
    required String level,
    required String notes,
    required int questionCount,
  }) {
    return '''
Create a revision worksheet with these details:
Subject: $subject
Area of revision: $area
Level / year group: ${level.trim().isEmpty ? 'not specified' : level}
Extra teacher instructions: ${notes.trim().isEmpty ? 'none' : notes}
Number of questions: $questionCount
The response must contain exactly $questionCount question objects.
Use a mix of written, multiple-choice (A/B/C) and matching questions where they suit the topic.
Add a diagram or working box if it helps the student.
Return only the JSON object.
''';
  }

  static const _reviewTextSystemPrompt = '''
You are a careful, encouraging teacher checking a student's revision worksheet.
You receive the worksheet structure with expected answers and the student's TYPED answers.
You CANNOT see the page, handwriting, drawings or diagrams. Never pretend that you can.
Return ONLY a JSON object. No markdown, no explanation.

JSON schema:
{
  "overall": "2-3 encouraging sentences about the work",
  "confidence": "high | medium | low",
  "items": [
    {"question": 1, "verdict": "correct | partly | incorrect | unclear", "feedback": "specific, short feedback"}
  ],
  "nextSteps": ["one or two concrete revision actions"]
}

Rules:
- Review every question using the typed answer, expected answer and keywords.
- Judge meaning, not exact wording. Accept synonyms, sensible alternatives and correct numeric equivalents.
- For choice questions, compare the student's letter with the expected letter and the options.
- For matching questions, compare the student's pairs with expectedPairs and mention any mismatched pairs.
- If the typed answer is blank, use "unclear" and explain that it was not typed or may be handwritten.
- If a question needs a drawing, say that the drawing could not be checked in text mode.
- Use "partly" for incomplete answers and "incorrect" for answers that are wrong.
- Do not invent marks for work you cannot see. Be concise, specific and kind.
- Return only the JSON object.
''';

  static const _reviewVisionSystemPrompt = '''
You are a careful, encouraging teacher reviewing a student's completed revision worksheet.
You receive the worksheet structure with expected answers and the student's typed answers, plus images of the completed pages in order.
Return ONLY a JSON object. No markdown, no explanation.

JSON schema:
{
  "overall": "2-3 encouraging sentences about the work",
  "confidence": "high | medium | low",
  "items": [
    {"question": 1, "verdict": "correct | partly | incorrect | unclear", "feedback": "specific, short feedback"}
  ],
  "nextSteps": ["one or two concrete revision actions"]
}

Rules:
- Review every question using both the image and the typed answer.
- Judge handwritten work, working and diagrams from the images; do not invent things that are not visible.
- Judge meaning, not exact wording. Accept synonyms, sensible alternatives and correct numeric equivalents.
- For choice questions, check the selected letter against the options and expected answer.
- For matching questions, check the drawn lines or typed pairs against expectedPairs.
- Use "partly" for incomplete answers and "unclear" if the image or handwriting is unreadable.
- Be concise, specific and kind. No scores are required in the items.
- Return only the JSON object.
''';
}

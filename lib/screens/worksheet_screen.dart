import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../ai_service.dart';
import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';

const _ink = Color(0xFF1B1B1B);
const _penColors = <Color>[
  Color(0xFF1B1B1B),
  Color(0xFF0B57D0),
  Color(0xFFB3261E),
  Color(0xFF146C2E),
  Color(0xFF7A4D00),
];
const _penNames = <String>['Black', 'Blue', 'Red', 'Green', 'Brown'];

class WorksheetScreen extends StatefulWidget {
  const WorksheetScreen({super.key, required this.worksheet});

  final Worksheet worksheet;

  @override
  State<WorksheetScreen> createState() => _WorksheetScreenState();
}

class _WorksheetScreenState extends State<WorksheetScreen> {
  late AppState _app;
  late final Map<String, TextEditingController> _controllers;
  late final List<GlobalKey> _pageKeys;
  late List<Stroke> _strokes;
  Stroke? _activeStroke;
  bool _drawMode = false;
  bool _eraser = false;
  Color _penColor = _penColors.first;
  final double _penWidth = 2.6;
  bool _busyAi = false;
  bool _printing = false;

  Worksheet get _sheet => widget.worksheet;

  @override
  void initState() {
    super.initState();
    _strokes = List.of(_sheet.strokes);
    _pageKeys = List.generate(
      _sheet.pages.length,
      (index) => GlobalKey(debugLabel: 'worksheet_page_$index'),
    );
    _controllers = {
      for (final question in _sheet.questions)
        question.id: TextEditingController(
          text: _sheet.answers[question.id] ?? '',
        ),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _app = AppScope.of(context);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _goBack() {
    _sheet.strokes = List.of(_strokes);
    _app.saveNow();
    Navigator.of(context).pop();
  }

  void _answerChanged(String id, String value) {
    _sheet.answers[id] = value;
    _app.scheduleSave();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final checked = _sheet.marks.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _sheet.title.isEmpty ? _sheet.area : _sheet.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${_sheet.subject} · ${_sheet.questionCount} questions · '
              '${_sheet.pages.length} ${_sheet.pages.length == 1 ? 'page' : 'pages'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          if (_busyAi)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              onPressed: _runAiReview,
              tooltip: 'AI review',
              icon: const Icon(Icons.auto_awesome),
            ),
          IconButton(
            onPressed: _printing ? null : () => _printPages(download: false),
            tooltip: 'Print',
            icon: const Icon(Icons.print_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              switch (value) {
                case 'download':
                  _printPages(download: true);
                case 'marks':
                  _clearMarks();
                case 'drawing':
                  _clearDrawing();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Download PDF'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'marks',
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Clear marks'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'drawing',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Clear drawing'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(scheme),
          if (_printing) const LinearProgressIndicator(minHeight: 2),
          if (checked) _buildResultStrip(scheme),
          Expanded(child: _buildPageList(theme, scheme)),
        ],
      ),
    );
  }

  Widget _buildToolbar(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      color: scheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.edit_outlined, size: 18),
                  label: Text('Type'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.draw_outlined, size: 18),
                  label: Text('Draw'),
                ),
              ],
              selected: {_drawMode},
              onSelectionChanged: (values) {
                FocusScope.of(context).unfocus();
                setState(() => _drawMode = values.first);
              },
            ),
            if (_drawMode) ...[
              const SizedBox(width: 10),
              ..._penSwatches(scheme),
              IconButton(
                onPressed: () => setState(() => _eraser = !_eraser),
                isSelected: _eraser,
                tooltip: 'Eraser',
                icon: const Icon(Icons.auto_fix_normal_outlined, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: _eraser ? scheme.secondaryContainer : null,
                ),
              ),
              IconButton(
                onPressed: _undoStroke,
                tooltip: 'Undo',
                icon: const Icon(Icons.undo, size: 20),
              ),
              IconButton(
                onPressed: _clearDrawing,
                tooltip: 'Clear drawing',
                icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              ),
            ],
            const SizedBox(width: 16),
            FilledButton.tonalIcon(
              onPressed: _checkAnswers,
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: const Text('Check'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _penSwatches(ColorScheme scheme) {
    return List<Widget>.generate(_penColors.length, (index) {
      final color = _penColors[index];
      final selected = !_eraser && _penColor == color;
      return Semantics(
        button: true,
        selected: selected,
        label: '${_penNames[index]} pen',
        child: Tooltip(
          message: '${_penNames[index]} pen',
          child: GestureDetector(
            onTap: () => setState(() {
              _penColor = color;
              _eraser = false;
            }),
            child: Container(
              width: 26,
              height: 26,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.onSurface : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildResultStrip(ColorScheme scheme) {
    final parts = <String>[];
    if ((_sheet.total ?? 0) > 0) {
      parts.add('${_sheet.correct ?? 0}/${_sheet.total} correct');
      parts.add('${_sheet.score ?? 0}%');
    }
    if ((_sheet.reviewCount ?? 0) > 0) {
      parts.add('${_sheet.reviewCount} to review');
    }
    if (parts.isEmpty) parts.add('Marked');
    if (_sheet.aiReviewJson != null) parts.add('AI reviewed');

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join(' · '),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          TextButton(onPressed: _clearMarks, child: const Text('Clear marks')),
        ],
      ),
    );
  }

  Widget _buildPageList(ThemeData theme, ColorScheme scheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 720 ? 10.0 : 24.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 80),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                children: [
                  for (var index = 0; index < _sheet.pages.length; index++) ...[
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: _pageKeys[index],
                        child: _buildPage(index),
                      ),
                    ),
                    if (index < _sheet.pages.length - 1)
                      const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPage(int index) {
    final page = _sheet.pages[index];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = (width / 820).clamp(0.72, 1.0).toDouble();
        return Container(
          width: width,
          constraints: BoxConstraints(minHeight: width * 1.414),
          color: Colors.white,
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  54 * scale,
                  44 * scale,
                  54 * scale,
                  34 * scale,
                ),
                child: _buildPageContent(page, index, scale),
              ),
              Positioned.fill(child: _buildDrawingLayer(index)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPageContent(WorksheetPage page, int pageIndex, double scale) {
    final first = pageIndex == 0;
    final heading = first
        ? (_sheet.title.trim().isEmpty ? _sheet.area : _sheet.title)
        : (page.title.trim().isEmpty ? 'Continued' : page.title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REVISION WORKSHEET',
          style: TextStyle(
            fontSize: 9.5 * scale,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF666666),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          heading,
          style: TextStyle(
            fontSize: 26 * scale,
            height: 1.12,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        if (first && _sheet.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            _sheet.subtitle,
            style: TextStyle(
              fontSize: 11.5 * scale,
              color: const Color(0xFF555555),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: EdgeInsets.symmetric(vertical: 6 * scale),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFFDDDDDD)),
              bottom: BorderSide(color: Color(0xFFDDDDDD)),
            ),
          ),
          child: Wrap(
            spacing: 20 * scale,
            runSpacing: 4 * scale,
            children: [
              _metaItem('Subject', _sheet.subject, scale),
              _metaItem('Name', '________________', scale),
              _metaItem('Date', _dateLabel(_sheet.createdAt), scale),
              _metaItem(
                'Page',
                '${pageIndex + 1} / ${_sheet.pages.length}',
                scale,
              ),
            ],
          ),
        ),
        if (first && _sheet.instructions.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _sheet.instructions,
            style: TextStyle(
              fontSize: 11.5 * scale,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: const Color(0xFF555555),
            ),
          ),
        ],
        if (first && _sheet.marks.isNotEmpty) ...[
          const SizedBox(height: 8),
          _sheetResultBanner(scale),
        ],
        for (final section in page.sections) ...[
          const SizedBox(height: 16),
          _sectionHeading(section.title, scale),
          const SizedBox(height: 8),
          for (final block in section.blocks) _buildBlock(block, scale),
        ],
        const SizedBox(height: 12),
        const Divider(height: 1, color: Color(0xFFDDDDDD)),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              'WorkinAI · revision worksheet',
              style: TextStyle(
                fontSize: 8.5 * scale,
                color: const Color(0xFF888888),
              ),
            ),
            const Spacer(),
            Text(
              'Page ${pageIndex + 1} of ${_sheet.pages.length}',
              style: TextStyle(
                fontSize: 8.5 * scale,
                color: const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _metaItem(String label, String value, double scale) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(
              fontSize: 9.5 * scale,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF333333),
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 9.5 * scale,
              color: const Color(0xFF555555),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetResultBanner(double scale) {
    final parts = <String>[];
    if ((_sheet.total ?? 0) > 0) {
      parts.add(
        '${_sheet.correct ?? 0}/${_sheet.total} correct (${_sheet.score ?? 0}%)',
      );
    }
    if ((_sheet.reviewCount ?? 0) > 0) {
      parts.add('${_sheet.reviewCount} to review');
    }
    if (parts.isEmpty) parts.add('Marked');
    if (_sheet.aiReviewJson != null) parts.add('AI reviewed');
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F2),
        border: Border.all(color: const Color(0xFFCFE3D5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 10 * scale,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF183D24),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, double scale) {
    if (title.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.only(left: 8 * scale),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: _ink, width: 3 * scale),
        ),
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11 * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: const Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildBlock(WorksheetBlock block, double scale) {
    switch (block.type) {
      case BlockType.text:
        return Padding(
          padding: EdgeInsets.only(bottom: 10 * scale),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 12 * scale,
              height: 1.5,
              color: const Color(0xFF333333),
            ),
          ),
        );
      case BlockType.diagram:
        return Padding(
          padding: EdgeInsets.only(top: 6 * scale, bottom: 10 * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.prompt.trim().isNotEmpty)
                Text(
                  block.prompt,
                  style: TextStyle(
                    fontSize: 12.5 * scale,
                    height: 1.4,
                    color: _ink,
                  ),
                ),
              SizedBox(height: 6 * scale),
              Container(
                width: double.infinity,
                height: block.height * scale,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFBDBDBD),
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Draw here',
                  style: TextStyle(
                    fontSize: 10 * scale,
                    color: const Color(0xFFAAAAAA),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      case BlockType.question:
        return _buildQuestion(block, scale);
    }
  }

  Widget _buildQuestion(WorksheetBlock block, double scale) {
    final controller = _controllers[block.id];
    if (controller == null) return const SizedBox.shrink();
    final mark = _sheet.marks[block.id];
    if (block.isChoice) {
      return _buildChoiceQuestion(block, scale, controller, mark);
    }
    if (block.isMatching) {
      return _buildMatchingQuestion(block, scale, controller, mark);
    }
    return _buildWrittenQuestion(block, scale, controller, mark);
  }

  Widget _questionShell({
    required WorksheetBlock block,
    required String? mark,
    required double scale,
    required Widget child,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 21 * scale,
                height: 21 * scale,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _ink,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${block.number}',
                  style: TextStyle(
                    fontSize: 10 * scale,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  block.prompt,
                  style: TextStyle(
                    fontSize: 13 * scale,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              if (mark != null) ...[
                SizedBox(width: 6 * scale),
                _badge(mark, scale),
              ],
            ],
          ),
          SizedBox(height: 4 * scale),
          child,
        ],
      ),
    );
  }

  Widget _buildWrittenQuestion(
    WorksheetBlock block,
    double scale,
    TextEditingController controller,
    String? mark,
  ) {
    final lineSpacing = 26.5 * scale;
    final fontSize = 12.5 * scale;
    return _questionShell(
      block: block,
      mark: mark,
      scale: scale,
      child: Container(
        margin: EdgeInsets.only(left: 29 * scale),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: _markColor(mark), width: 2.4 * scale),
          ),
          color: mark == null
              ? Colors.transparent
              : _markColor(mark).withValues(alpha: 0.035),
        ),
        padding: EdgeInsets.only(left: 6 * scale),
        child: CustomPaint(
          painter: _AnswerLinesPainter(spacing: lineSpacing),
          child: TextField(
            controller: controller,
            minLines: block.answerLines,
            maxLines: block.answerLines,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: TextStyle(
              fontSize: fontSize,
              height: lineSpacing / fontSize,
              color: _ink,
            ),
            cursorColor: _ink,
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 4 * scale,
                vertical: 1 * scale,
              ),
              hintText: mark == null ? 'Type your answer…' : null,
              hintStyle: TextStyle(
                fontSize: 11.5 * scale,
                color: const Color(0xFFAAAAAA),
                fontStyle: FontStyle.italic,
              ),
            ),
            onChanged: (value) => _answerChanged(block.id!, value),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceQuestion(
    WorksheetBlock block,
    double scale,
    TextEditingController controller,
    String? mark,
  ) {
    final selected =
        (controller.text.trim().isNotEmpty
                ? controller.text
                : (_sheet.answers[block.id] ?? ''))
            .trim()
            .toUpperCase();
    final correct = block.answer.trim().toUpperCase();
    final hasKey = correct.length == 1;
    return _questionShell(
      block: block,
      mark: mark,
      scale: scale,
      child: Container(
        margin: EdgeInsets.only(left: 29 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < block.options.length; index++)
              Padding(
                padding: EdgeInsets.only(bottom: 5 * scale),
                child: _choiceOption(
                  block: block,
                  scale: scale,
                  index: index,
                  selected: selected,
                  correct: correct,
                  mark: mark,
                  controller: controller,
                  hasKey: hasKey,
                ),
              ),
            if (mark != null && hasKey)
              Padding(
                padding: EdgeInsets.only(top: 1 * scale),
                child: Text(
                  'Correct answer: ${block.displayAnswer}',
                  style: TextStyle(
                    fontSize: 10.5 * scale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF146C2E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceOption({
    required WorksheetBlock block,
    required double scale,
    required int index,
    required String selected,
    required String correct,
    required String? mark,
    required TextEditingController controller,
    required bool hasKey,
  }) {
    final letter = String.fromCharCode(65 + index);
    final isSelected = selected == letter;
    final isCorrect = hasKey && correct == letter;
    final showCorrect = mark != null && isCorrect;
    final showWrong = mark != null && isSelected && !isCorrect;
    final border = showCorrect
        ? const Color(0xFF2E7D32)
        : showWrong
        ? const Color(0xFFB3261E)
        : isSelected
        ? _ink
        : const Color(0xFFBDBDBD);
    final background = showCorrect
        ? const Color(0xFFE7F4EA)
        : showWrong
        ? const Color(0xFFFCE8E6)
        : isSelected
        ? const Color(0xFFF1F1EE)
        : Colors.transparent;
    return Semantics(
      button: true,
      selected: isSelected,
      label: 'Option $letter: ${block.options[index]}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6 * scale),
        onTap: () {
          final value = isSelected ? '' : letter;
          controller.text = value;
          controller.selection = TextSelection.collapsed(offset: value.length);
          _answerChanged(block.id!, value);
          setState(() {});
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 8 * scale,
            vertical: 6 * scale,
          ),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: border, width: 1.1 * scale),
            borderRadius: BorderRadius.circular(6 * scale),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20 * scale,
                height: 20 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected || showCorrect
                      ? border
                      : Colors.transparent,
                  border: Border.all(color: border, width: 1.1 * scale),
                ),
                child: Text(
                  letter,
                  style: TextStyle(
                    fontSize: 9.5 * scale,
                    fontWeight: FontWeight.w800,
                    color: isSelected || showCorrect ? Colors.white : _ink,
                  ),
                ),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  block.options[index],
                  style: TextStyle(
                    fontSize: 11.5 * scale,
                    height: 1.35,
                    color: _ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchingQuestion(
    WorksheetBlock block,
    double scale,
    TextEditingController controller,
    String? mark,
  ) {
    final rows = block.leftItems.length > block.rightItems.length
        ? block.leftItems.length
        : block.rightItems.length;
    return _questionShell(
      block: block,
      mark: mark,
      scale: scale,
      child: Container(
        margin: EdgeInsets.only(left: 29 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Draw a line from each numbered card to its matching letter. '
              'You can also type your pairs below.',
              style: TextStyle(
                fontSize: 9.5 * scale,
                color: const Color(0xFF777777),
                height: 1.35,
              ),
            ),
            SizedBox(height: 6 * scale),
            Table(
              columnWidths: {
                0: const FlexColumnWidth(),
                1: FixedColumnWidth(42 * scale),
                2: const FlexColumnWidth(),
              },
              children: [
                TableRow(
                  children: [
                    _matchColumnLabel('MATCH', scale),
                    const SizedBox.shrink(),
                    _matchColumnLabel('ANSWER', scale),
                  ],
                ),
                for (var index = 0; index < rows; index++)
                  TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(bottom: 5 * scale),
                        child: index < block.leftItems.length
                            ? _matchCard(
                                '${index + 1}',
                                block.leftItems[index],
                                scale,
                              )
                            : const SizedBox.shrink(),
                      ),
                      SizedBox(height: 5 * scale),
                      Padding(
                        padding: EdgeInsets.only(bottom: 5 * scale),
                        child: index < block.rightItems.length
                            ? _matchCard(
                                String.fromCharCode(65 + index),
                                block.rightItems[index],
                                scale,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 5 * scale),
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFBDBDBD))),
              ),
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 1,
                style: TextStyle(fontSize: 11.5 * scale, color: _ink),
                cursorColor: _ink,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4 * scale),
                  hintText: 'Type your pairs: 1-B, 2-C, 3-A',
                  hintStyle: TextStyle(
                    fontSize: 10.5 * scale,
                    color: const Color(0xFFAAAAAA),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                onChanged: (value) => _answerChanged(block.id!, value),
              ),
            ),
            if (mark != null && block.matches.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 4 * scale),
                child: Text(
                  'Correct pairs: ${block.displayAnswer}',
                  style: TextStyle(
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF146C2E),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _matchColumnLabel(String label, double scale) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 8 * scale,
        letterSpacing: 0.9,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF777777),
      ),
    );
  }

  Widget _matchCard(String badge, String text, double scale) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: 32 * scale),
      padding: EdgeInsets.symmetric(horizontal: 7 * scale, vertical: 5 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF7),
        border: Border.all(color: const Color(0xFFBDBDBD), width: 1 * scale),
        borderRadius: BorderRadius.circular(5 * scale),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17 * scale,
            height: 17 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _ink,
              borderRadius: BorderRadius.circular(4 * scale),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 8.5 * scale,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 6 * scale),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 10.5 * scale,
                height: 1.3,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _markColor(String? mark) {
    return switch (mark) {
      'correct' => const Color(0xFF2E7D32),
      'wrong' => const Color(0xFFB3261E),
      'review' => const Color(0xFFC98A00),
      _ => Colors.transparent,
    };
  }

  Widget _badge(String mark, double scale) {
    final background = switch (mark) {
      'correct' => const Color(0xFFE2F4E7),
      'wrong' => const Color(0xFFFCE8E6),
      _ => const Color(0xFFFFF1DC),
    };
    final foreground = switch (mark) {
      'correct' => const Color(0xFF146C2E),
      'wrong' => const Color(0xFFB3261E),
      _ => const Color(0xFF7A4D00),
    };
    final label = switch (mark) {
      'correct' => 'Correct',
      'wrong' => 'Try again',
      _ => 'Review',
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 6 * scale,
        vertical: 2.5 * scale,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5 * scale),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9 * scale,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }

  Widget _buildDrawingLayer(int pageIndex) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return IgnorePointer(
          ignoring: !_drawMode,
          child: MouseRegion(
            cursor: _drawMode
                ? SystemMouseCursors.precise
                : SystemMouseCursors.basic,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (_drawMode) {
                  _beginStroke(event.localPosition, size, pageIndex);
                }
              },
              onPointerMove: (event) {
                if (_drawMode && _activeStroke != null) {
                  _extendStroke(event.localPosition, size);
                }
              },
              onPointerUp: (_) => _finishStroke(),
              onPointerCancel: (_) => _finishStroke(),
              child: CustomPaint(
                painter: _StrokesPainter(
                  strokes: _strokes
                      .where((stroke) => stroke.page == pageIndex)
                      .toList(),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
      },
    );
  }

  void _beginStroke(Offset local, Size size, int pageIndex) {
    if (size.isEmpty) return;
    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
    final stroke = Stroke(
      page: pageIndex,
      points: [point],
      colorValue: _eraser ? 0xFF000000 : _penColor.toARGB32(),
      width: _eraser ? 18 : _penWidth,
      erase: _eraser,
    );
    setState(() {
      _strokes.add(stroke);
      _activeStroke = stroke;
    });
  }

  void _extendStroke(Offset local, Size size) {
    final stroke = _activeStroke;
    if (stroke == null || size.isEmpty) return;
    final point = Offset(
      (local.dx / size.width).clamp(0.0, 1.0).toDouble(),
      (local.dy / size.height).clamp(0.0, 1.0).toDouble(),
    );
    setState(() {
      stroke.points.add(point);
    });
  }

  void _finishStroke() {
    if (_activeStroke == null) return;
    setState(() => _activeStroke = null);
    _sheet.strokes = List.of(_strokes);
    _app.scheduleSave();
  }

  void _undoStroke() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
    _sheet.strokes = List.of(_strokes);
    _app.scheduleSave();
  }

  Future<void> _clearDrawing() async {
    if (_strokes.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all drawing?'),
        content: const Text(
          'This removes handwriting and diagrams from every page.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      setState(() => _strokes.clear());
      _sheet.strokes = <Stroke>[];
      _app.scheduleSave();
      _snack('Drawing cleared.');
    }
  }

  void _checkAnswers() {
    for (final question in _sheet.questions) {
      final text = _controllers[question.id]?.text.trim() ?? '';
      _sheet.answers[question.id] = text;
      _sheet.marks[question.id] = _grade(question.block, text);
    }
    _sheet.recalculate();
    _sheet.strokes = List.of(_strokes);
    _app.scheduleSave();
    setState(() {});
    final total = _sheet.total ?? 0;
    final correct = _sheet.correct ?? 0;
    final review = _sheet.reviewCount ?? 0;
    _snack(
      total == 0
          ? 'Marked for review — open-ended answers need a person or AI.'
          : 'Checked: $correct/$total correct'
                '${review > 0 ? ' · $review to review' : ''}.',
    );
  }

  String _grade(WorksheetBlock block, String raw) {
    final text = raw.trim();
    if (block.isChoice) return _gradeChoice(block, text);
    if (block.isMatching) return _gradeMatching(block, text);
    final expected = block.answer.trim();
    final keywords = block.keywords;
    if (text.isEmpty) {
      return expected.isEmpty && keywords.isEmpty ? 'review' : 'wrong';
    }
    if (expected.isNotEmpty) {
      final expectedNumber = double.tryParse(expected.replaceAll(',', ''));
      if (expectedNumber != null) {
        final match = RegExp(r'-?\d+(?:\.\d+)?')
            .firstMatch(text.replaceAll(',', ''));
        if (match != null) {
          final value = double.tryParse(match.group(0)!);
          if (value != null && (value - expectedNumber).abs() <= 0.01) {
            return 'correct';
          }
        }
      }
      final normalizedExpected = _normalize(expected);
      final normalizedAnswer = _normalize(text);
      if (normalizedAnswer == normalizedExpected ||
          normalizedAnswer.contains(normalizedExpected)) {
        return 'correct';
      }
    }
    for (final keyword in keywords) {
      if (_normalize(text).contains(_normalize(keyword))) return 'correct';
    }
    if (expected.isEmpty && keywords.isEmpty) return 'review';
    return 'wrong';
  }

  String _gradeChoice(WorksheetBlock block, String raw) {
    if (raw.isEmpty) return block.answer.trim().isEmpty ? 'review' : 'wrong';
    if (block.answer.trim().isEmpty) return 'review';
    final expected = _choiceLetter(block.answer, block.options);
    final selected = _choiceLetter(raw, block.options);
    if (expected.isEmpty || selected.isEmpty) return 'review';
    return expected == selected ? 'correct' : 'wrong';
  }

  String _choiceLetter(String raw, List<String> options) {
    final text = raw.trim().toUpperCase();
    if (text.isEmpty) return '';
    final direct = RegExp(r'^([A-F])(?:[.\-:)]|\s|$)').firstMatch(text);
    if (direct != null) return direct.group(1)!;
    final normalized = _normalize(raw);
    for (var index = 0; index < options.length; index++) {
      final option = _normalize(options[index]);
      if (option.isNotEmpty && normalized == option) {
        return String.fromCharCode(65 + index);
      }
    }
    return '';
  }

  String _gradeMatching(WorksheetBlock block, String raw) {
    if (raw.isEmpty) return 'review';
    if (block.matches.isEmpty) return 'review';
    final actual = _matchingLetters(
      raw,
      block.leftItems.length,
      block.rightItems.length,
    );
    if (actual.length != block.matches.length) return 'review';
    for (var index = 0; index < block.matches.length; index++) {
      if (actual[index] != block.matches[index].trim().toUpperCase()) {
        return 'wrong';
      }
    }
    return 'correct';
  }

  List<String> _matchingLetters(String raw, int leftCount, int rightCount) {
    final assigned = <int, String>{};
    final pairs = RegExp(r'(\d+)\s*[-=:.)]?\s*([A-Fa-f])\b').allMatches(raw);
    final sequential = <String>[];
    if (pairs.isNotEmpty) {
      for (final pair in pairs) {
        final index = int.tryParse(pair.group(1) ?? '');
        final letter = pair.group(2)?.toUpperCase() ?? '';
        if (index != null && index > 0 && index <= leftCount) {
          assigned[index - 1] = letter;
        }
      }
    } else {
      for (final match in RegExp(r'[A-Fa-f]').allMatches(raw)) {
        sequential.add(match.group(0)!.toUpperCase());
      }
    }
    final result = List<String>.filled(leftCount, '');
    for (var index = 0; index < leftCount; index++) {
      result[index] =
          assigned[index] ??
          (index < sequential.length ? sequential[index] : '');
    }
    for (final letter in result) {
      if (letter.isEmpty) return <String>[];
      final index = letter.codeUnitAt(0) - 65;
      if (index < 0 || index >= rightCount) return <String>[];
    }
    return result;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _clearMarks() {
    _sheet.marks.clear();
    _sheet.score = null;
    _sheet.correct = null;
    _sheet.total = null;
    _sheet.reviewCount = null;
    _app.scheduleSave();
    setState(() {});
    _snack('Marks cleared.');
  }

  Future<void> _runAiReview() async {
    if (_busyAi) return;
    setState(() => _busyAi = true);
    try {
      for (final question in _sheet.questions) {
        _sheet.answers[question.id] =
            _controllers[question.id]?.text.trim() ?? '';
      }
      _sheet.strokes = List.of(_strokes);
      final images = _strokes.isEmpty
          ? const <Uint8List>[]
          : await _capturePages();
      final result = await AiService(_app.ai)
          .reviewWorksheet(worksheet: _sheet, pageImages: images);
      _sheet.aiReviewJson = result.json;
      _app.scheduleSave();
      if (!mounted) return;
      setState(() => _busyAi = false);
      await _showReviewDialog(result.json, note: result.note);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyAi = false);
      final message = error is AiException ? error.message : error.toString();
      await _showAiError(message);
    }
  }

  Future<void> _showAiError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.auto_awesome_outlined),
        title: const Text('AI review failed'),
        content: SingleChildScrollView(
          child: Text(
            '$message\n\nText-only local models can still check typed answers. '
            'Reviewing handwriting, drawings or page images needs a vision-capable model. '
            'Also check that the server allows CORS.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(String raw, {String? note}) async {
    final review = AiReview.tryParse(raw);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        if (review == null) {
          return AlertDialog(
            title: const Text('AI review'),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note != null && note.isNotEmpty) ...[
                      _reviewNote(note),
                      const SizedBox(height: 12),
                    ],
                    SelectableText(raw),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        }
        return AlertDialog(
          icon: const Icon(Icons.auto_awesome),
          title: const Text('AI review'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.overall,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _reviewNote(note),
                  ],
                  if (review.confidence.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Confidence: ${review.confidence}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                  if (review.items.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    for (final item in review.items) _reviewItem(item),
                  ],
                  if (review.nextSteps.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Next steps',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    for (final step in review.nextSteps)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(step)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
            if (review.items.isNotEmpty)
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _applyAiMarks(review);
                },
                child: const Text('Apply AI marks'),
              ),
          ],
        );
      },
    );
  }

  Widget _reviewNote(String note) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 17,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSecondaryContainer, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewItem(AiReviewItem item) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (item.verdict) {
      'correct' => const Color(0xFF146C2E),
      'partly' => const Color(0xFF7A4D00),
      'incorrect' => const Color(0xFFB3261E),
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Q${item.question}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _promptFor(item.question),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(item.feedback, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _promptFor(int number) {
    for (final question in _sheet.questions) {
      if (question.number == number) return question.block.prompt;
    }
    return 'Question $number';
  }

  void _applyAiMarks(AiReview review) {
    var applied = 0;
    for (final item in review.items) {
      for (final question in _sheet.questions) {
        if (question.number != item.question) continue;
        _sheet.marks[question.id] = switch (item.verdict) {
          'correct' => 'correct',
          'partly' => 'wrong',
          'incorrect' => 'wrong',
          _ => 'review',
        };
        applied += 1;
      }
    }
    if (applied == 0) {
      _snack('No AI marks to apply.');
      return;
    }
    _sheet.recalculate();
    _app.scheduleSave();
    setState(() {});
    _snack('Applied AI marks to $applied question${applied == 1 ? '' : 's'}.');
  }

  Future<List<Uint8List>> _capturePages() async {
    await WidgetsBinding.instance.endOfFrame;
    final images = <Uint8List>[];
    for (final key in _pageKeys) {
      if (!mounted) break;
      final pageContext = key.currentContext;
      if (pageContext == null || !pageContext.mounted) continue;
      final object = pageContext.findRenderObject();
      if (object is! RenderRepaintBoundary) continue;
      final image = await object.toImage(pixelRatio: 2.4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data != null) images.add(data.buffer.asUint8List());
    }
    if (images.isEmpty) {
      throw Exception('The worksheet pages could not be captured.');
    }
    return images;
  }

  Future<void> _printPages({required bool download}) async {
    if (_printing) return;
    setState(() => _printing = true);
    try {
      final images = await _capturePages();
      final document = pw.Document();
      for (final bytes in images) {
        final image = pw.MemoryImage(bytes);
        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.FullPage(
              ignoreMargins: true,
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }
      final bytes = await document.save();
      if (download) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'worksheet-${_sheet.id}.pdf',
        );
      } else {
        await Printing.layoutPdf(onLayout: (format) async => bytes);
      }
    } catch (error) {
      _snack('Could not prepare the PDF: $error');
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(int timestamp) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _AnswerLinesPainter extends CustomPainter {
  _AnswerLinesPainter({required this.spacing});

  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDCDCDC)
      ..strokeWidth = 1;
    for (var y = spacing; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnswerLinesPainter oldDelegate) {
    return oldDelegate.spacing != spacing;
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter({required this.strokes});

  final List<Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty || size.isEmpty) return;
    canvas.saveLayer(Offset.zero & size, Paint());
    final scale = size.width / 820;
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final color = Color(stroke.colorValue);
      final paint = Paint()
        ..color = color
        ..strokeWidth = stroke.width * scale
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = stroke.erase ? BlendMode.clear : BlendMode.srcOver;
      if (stroke.points.length == 1) {
        final point = _scale(stroke.points.first, size);
        final dotPaint = Paint()
          ..color = color
          ..blendMode = paint.blendMode;
        canvas.drawCircle(point, paint.strokeWidth / 2, dotPaint);
      } else {
        final path = Path();
        final first = _scale(stroke.points.first, size);
        path.moveTo(first.dx, first.dy);
        for (final point in stroke.points.skip(1)) {
          final scaled = _scale(point, size);
          path.lineTo(scaled.dx, scaled.dy);
        }
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  Offset _scale(Offset point, Size size) {
    return Offset(point.dx * size.width, point.dy * size.height);
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => true;
}

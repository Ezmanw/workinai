import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';

class ParentScreen extends StatelessWidget {
  const ParentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final marked = app.worksheets
        .where((sheet) => sheet.score != null)
        .toList();
    final average = marked.isEmpty
        ? null
        : (marked.fold<int>(0, (sum, sheet) => sum + (sheet.score ?? 0)) /
                  marked.length)
              .round();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Parent view'),
            Text(
              'Every profile, score and answer',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progress overview',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'A read-only summary of the work saved on this device. Open any worksheet '
                  'to see the student\u2019s answer beside the expected answer.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                      icon: Icons.people_outline,
                      label: 'Profiles',
                      value: '${app.profiles.length}',
                    ),
                    _StatCard(
                      icon: Icons.description_outlined,
                      label: 'Worksheets',
                      value: '${app.worksheets.length}',
                    ),
                    _StatCard(
                      icon: Icons.fact_check_outlined,
                      label: 'Checked',
                      value: '${marked.length}',
                    ),
                    _StatCard(
                      icon: Icons.insights_outlined,
                      label: 'Average score',
                      value: average == null ? '—' : '$average%',
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Text(
                      'Profiles',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${app.worksheets.length} worksheet${app.worksheets.length == 1 ? '' : 's'} total',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (app.profiles.isEmpty)
                  _emptyState(theme, scheme)
                else
                  for (final profile in app.profiles) ...[
                    _ProfileCard(app: app, profile: profile),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme, ColorScheme scheme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.secondaryContainer,
              child: Icon(
                Icons.groups_outlined,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'No profiles yet. Go back to the studio to add a learner and generate a worksheet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 190,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.app, required this.profile});

  final AppState app;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sheets = app.worksheetsFor(profile.id);
    final checked = sheets.where((sheet) => sheet.score != null).toList();
    final average = checked.isEmpty
        ? null
        : (checked.fold<int>(0, (sum, sheet) => sum + (sheet.score ?? 0)) /
                  checked.length)
              .round();
    final questions = sheets.fold<int>(
      0,
      (sum, sheet) => sum + sheet.questionCount,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(profile.colorValue),
                  child: Text(
                    profile.name.isEmpty
                        ? '?'
                        : profile.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sheets.length} worksheet${sheets.length == 1 ? '' : 's'} · '
                        '$questions question${questions == 1 ? '' : 's'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _AverageChip(
                  average: average,
                  checked: checked.length,
                  total: sheets.length,
                ),
              ],
            ),
          ),
          if (sheets.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
              child: Row(
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No worksheets yet for this profile.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final sheet in sheets) ...[
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: scheme.outlineVariant,
              ),
              _WorksheetRow(
                sheet: sheet,
                onTap: () => _showDetail(context, app, profile, sheet),
              ),
            ],
        ],
      ),
    );
  }
}

class _AverageChip extends StatelessWidget {
  const _AverageChip({
    required this.average,
    required this.checked,
    required this.total,
  });

  final int? average;
  final int checked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = average == null
        ? scheme.onSurfaceVariant
        : _scoreInk(average!, scheme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: average == null
            ? scheme.surfaceContainerHighest
            : ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        average == null ? 'No scores' : '$average% avg',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}

class _WorksheetRow extends StatelessWidget {
  const _WorksheetRow({required this.sheet, required this.onTap});

  final Worksheet sheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.article_outlined,
                size: 19,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sheet.title.trim().isEmpty ? sheet.area : sheet.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sheet.subject} · ${_dateLabel(sheet.createdAt)} · '
                    '${sheet.questionCount} questions · '
                    '${sheet.pages.length} page${sheet.pages.length == 1 ? '' : 's'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ScorePill(sheet: sheet),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.sheet});

  final Worksheet sheet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = sheet.score;
    final hasMarks = sheet.marks.isNotEmpty;
    final ink = score == null
        ? scheme.onSurfaceVariant
        : _scoreInk(score, scheme);
    final label = score != null
        ? '$score%'
        : hasMarks
        ? 'To review'
        : 'Not checked';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: score == null
            ? scheme.surfaceContainerHighest
            : ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}

Future<void> _showDetail(
  BuildContext context,
  AppState app,
  Profile profile,
  Worksheet sheet,
) {
  final review = AiReview.tryParse(sheet.aiReviewJson);
  final feedback = <int, AiReviewItem>{
    if (review != null)
      for (final item in review.items) item.question: item,
  };
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final checked = sheet.marks.isNotEmpty;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.article_outlined,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sheet.title.trim().isEmpty
                                ? sheet.area
                                : sheet.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profile.name} · ${sheet.subject} · ${_dateLabel(sheet.createdAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(right: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summary(sheet, checked, theme, scheme),
                        if (sheet.area.trim().isNotEmpty &&
                            sheet.area.trim().toLowerCase() !=
                                sheet.title.trim().toLowerCase()) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Revision area: ${sheet.area}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (review != null && review.overall.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _AiOverview(review: review),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          'Questions & answers',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (sheet.questions.isEmpty)
                          Text(
                            'This worksheet has no questions.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          for (final question in sheet.questions)
                            _QuestionCard(
                              question: question,
                              answer: sheet.answers[question.id] ?? '',
                              mark: sheet.marks[question.id],
                              feedback: feedback[question.number],
                            ),
                        if (review != null && review.nextSteps.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          _NextSteps(steps: review.nextSteps),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Read-only parent summary · stored locally',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _summary(
  Worksheet sheet,
  bool checked,
  ThemeData theme,
  ColorScheme scheme,
) {
  final score = sheet.score;
  final ink = score == null
      ? scheme.onSurfaceVariant
      : _scoreInk(score, scheme);
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 62,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: score == null
                ? scheme.surfaceContainerHighest
                : ink.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score == null ? '—' : '$score%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                !checked
                    ? 'Not checked yet'
                    : score == null || (sheet.total ?? 0) == 0
                    ? 'Marked for review'
                    : '${sheet.correct ?? 0} of ${sheet.total} correct',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${sheet.questionCount} questions · ${sheet.pages.length} '
                '${sheet.pages.length == 1 ? 'page' : 'pages'}'
                '${(sheet.reviewCount ?? 0) > 0 ? ' · ${sheet.reviewCount} need a closer look' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (sheet.generator != null && sheet.generator!.isNotEmpty)
                Text(
                  'Generated by ${sheet.generator}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AiOverview extends StatelessWidget {
  const _AiOverview({required this.review});

  final AiReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI review',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                    if (review.confidence.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        'confidence: ${review.confidence}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  review.overall,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next steps',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: theme.textTheme.bodySmall),
                  Expanded(
                    child: Text(
                      step,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.answer,
    required this.mark,
    required this.feedback,
  });

  final WorksheetQuestion question;
  final String answer;
  final String? mark;
  final AiReviewItem? feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final block = question.block;
    final trimmedAnswer = answer.trim();
    final expectedAnswer = block.displayAnswer.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${block.number}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  block.prompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _MarkBadge(mark: mark),
            ],
          ),
          const SizedBox(height: 10),
          _labelled(
            'Student\u2019s answer',
            trimmedAnswer.isEmpty
                ? 'No typed answer — handwriting or working may be on the page.'
                : trimmedAnswer,
            theme,
            scheme,
            muted: trimmedAnswer.isEmpty,
          ),
          const SizedBox(height: 7),
          _labelled(
            'Expected answer',
            expectedAnswer.isEmpty
                ? 'Open-ended — use teacher or AI judgement.'
                : expectedAnswer,
            theme,
            scheme,
            muted: expectedAnswer.isEmpty,
          ),
          if (block.keywords.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Key ideas: ${block.keywords.join(', ')}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (feedback != null && feedback!.feedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: scheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      feedback!.feedback,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _labelled(
    String label,
    String value,
    ThemeData theme,
    ColorScheme scheme, {
    bool muted = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 9.5,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w700,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            height: 1.45,
            color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
            fontStyle: muted ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }
}

class _MarkBadge extends StatelessWidget {
  const _MarkBadge({required this.mark});

  final String? mark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ink = switch (mark) {
      'correct' => _goodInk(scheme),
      'wrong' => _badInk(scheme),
      'review' => _warnInk(scheme),
      _ => scheme.onSurfaceVariant,
    };
    final label = switch (mark) {
      'correct' => 'Correct',
      'wrong' => 'Wrong',
      'review' => 'Review',
      _ => 'Unmarked',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mark == null
            ? scheme.surfaceContainerHighest
            : ink.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}

Color _goodInk(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFF8BD99A)
    : const Color(0xFF146C2E);

Color _badInk(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFFFFB4AB)
    : const Color(0xFFB3261E);

Color _warnInk(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFFFFD18A)
    : const Color(0xFF7A4D00);

Color _scoreInk(int score, ColorScheme scheme) {
  if (score >= 80) return _goodInk(scheme);
  if (score >= 50) return _warnInk(scheme);
  return _badInk(scheme);
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

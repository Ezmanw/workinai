import 'package:flutter/material.dart';

import '../ai_service.dart';
import '../app_scope.dart';
import '../app_state.dart';
import '../fallback_generator.dart';
import '../models.dart';
import 'parent_screen.dart';
import 'generating_screen.dart';
import 'settings_screen.dart';
import 'worksheet_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _subject = TextEditingController();
  final _area = TextEditingController();
  final _level = TextEditingController();
  final _notes = TextEditingController();
  int _questionCount = 6;
  bool _generating = false;

  @override
  void dispose() {
    _subject.dispose();
    _area.dispose();
    _level.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _generate({required bool builtIn}) async {
    if (_generating) return;
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final subject = _subject.text.trim();
    final area = _area.text.trim();
    if (subject.isEmpty || area.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add a subject and a revision area first.'),
        ),
      );
      return;
    }

    var useBuiltIn = builtIn;
    if (!useBuiltIn) {
      final configured = app.ai.isLocal
          ? app.ai.baseUrl.trim().isNotEmpty && app.ai.model.trim().isNotEmpty
          : app.ai.geminiKey.trim().isNotEmpty;
      if (!configured) {
        if (app.ai.useFallback) {
          useBuiltIn = true;
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'No AI configured, so the built-in generator was used.',
              ),
            ),
          );
        } else {
          await _showError(
            'No AI is configured yet. Add a local server or Gemini in Settings, '
            'or enable the fallback generator.',
          );
          return;
        }
      }
    }

    if (useBuiltIn) {
      final worksheet = generateFallbackWorksheet(
        profileId: app.currentProfile.id,
        subject: subject,
        area: area,
        questionCount: _questionCount,
      );
      app.addWorksheet(worksheet);
      await _openSheet(worksheet);
      return;
    }

    setState(() => _generating = true);
    final worksheet = await Navigator.of(context).push<Worksheet>(
      PageRouteBuilder<Worksheet>(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) =>
            GeneratingScreen(
              profileId: app.currentProfile.id,
              subject: subject,
              area: area,
              level: _level.text,
              notes: _notes.text,
              questionCount: _questionCount,
              modelLabel: app.ai.activeModel,
              service: AiService(app.ai),
              allowBuiltIn: app.ai.useFallback,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
    if (!mounted) return;
    setState(() => _generating = false);
    if (worksheet == null) return;
    app.addWorksheet(worksheet);
    await _openSheet(worksheet);
  }

  Future<void> _openSheet(Worksheet worksheet) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorksheetScreen(worksheet: worksheet),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _showError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.cloud_off_outlined),
        title: const Text('AI request failed'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _openSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
  }

  void _openParentView() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const ParentScreen()));
  }

  Future<void> _addProfile(AppState app) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New profile'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) {
      app.addProfile(name);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteSheet(AppState app, Worksheet sheet) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete worksheet?'),
        content: Text(
          '“${sheet.title.isEmpty ? sheet.area : sheet.title}” and its answers will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      app.deleteWorksheet(sheet.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 680;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: compact ? 8 : 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: scheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'WorkinAI',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Worksheet Studio',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          _buildProfileMenu(app, compact),
          IconButton(
            onPressed: _openParentView,
            tooltip: 'Parent view',
            icon: const Icon(Icons.groups_outlined),
          ),
          IconButton(
            onPressed: _openSettings,
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 90),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'REVISION, MADE QUICK',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Let's build a worksheet.",
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a subject and a topic. The AI designs the full layout — including extra pages — '
                  'then you can type on it, draw on it, print it, or ask AI to review the finished work.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _buildAiStatus(app),
                const SizedBox(height: 14),
                _buildBuilder(app),
                const SizedBox(height: 34),
                Row(
                  children: [
                    Text(
                      'Recent worksheets',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${app.currentWorksheets.length} saved',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHistory(app),
                const SizedBox(height: 34),
                Text(
                  'Everything is stored on this device. AI requests go directly to your chosen server.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileMenu(AppState app, bool compact) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final profile = app.currentProfile;
    return PopupMenuButton<String>(
      tooltip: 'Profiles',
      offset: const Offset(0, 48),
      onSelected: (value) {
        if (value == '__new') {
          _addProfile(app);
        } else {
          app.switchProfile(value);
          setState(() {});
        }
      },
      itemBuilder: (context) => [
        for (final item in app.profiles)
          PopupMenuItem<String>(
            value: item.id,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Color(item.colorValue),
                  child: Text(
                    item.name.isEmpty
                        ? '?'
                        : item.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item.name)),
                if (item.id == app.currentProfile.id)
                  const Icon(Icons.check, size: 18),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '__new',
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined),
              SizedBox(width: 10),
              Text('New profile'),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 4, 10, 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Color(profile.colorValue),
              child: Text(
                profile.name.isEmpty
                    ? '?'
                    : profile.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  profile.name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiStatus(AppState app) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = app.ai.isLocal;
    final endpoint = local ? app.ai.baseUrl : 'Gemini · ${app.ai.geminiModel}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            local ? Icons.dns_outlined : Icons.cloud_outlined,
            size: 18,
            color: scheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${local ? 'Local AI' : 'Gemini'} · $endpoint',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: _openSettings, child: const Text('Configure')),
        ],
      ),
    );
  }

  Widget _buildBuilder(AppState app) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 620;
                final subjectField = _field(
                  'Subject',
                  _subject,
                  'e.g. Biology',
                );
                final areaField = _field(
                  'Area of revision',
                  _area,
                  'e.g. Photosynthesis',
                );
                if (!twoColumns) {
                  return Column(
                    children: [
                      subjectField,
                      const SizedBox(height: 14),
                      areaField,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: subjectField),
                    const SizedBox(width: 14),
                    Expanded(child: areaField),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth > 620;
                final levelField = _field(
                  'Level / year group (optional)',
                  _level,
                  'e.g. Year 10',
                );
                final counter = _buildQuestionCounter();
                if (!twoColumns) {
                  return Column(
                    children: [
                      levelField,
                      const SizedBox(height: 14),
                      Align(alignment: Alignment.centerLeft, child: counter),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(flex: 3, child: levelField),
                    const SizedBox(width: 14),
                    counter,
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _field(
              'Extra instructions (optional)',
              _notes,
              'e.g. include exam-style questions and one challenge task',
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _generating
                      ? null
                      : () => _generate(builtIn: true),
                  icon: const Icon(Icons.bolt_outlined, size: 18),
                  label: const Text('Built-in'),
                ),
                FilledButton.icon(
                  onPressed: _generating
                      ? null
                      : () => _generate(builtIn: false),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate with AI'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'The AI can spread the worksheet over multiple pages. A local server keeps everything on your network; '
              'Gemini needs an API key.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, String hint) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _buildQuestionCounter() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Questions',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: _questionCount > 1
                    ? () => setState(() => _questionCount -= 1)
                    : null,
                icon: const Icon(Icons.remove, size: 18),
                tooltip: 'Fewer questions',
                visualDensity: VisualDensity.compact,
              ),
              SizedBox(
                width: 26,
                child: Text(
                  '$_questionCount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _questionCount < 20
                    ? () => setState(() => _questionCount += 1)
                    : null,
                icon: const Icon(Icons.add, size: 18),
                tooltip: 'More questions',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistory(AppState app) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sheets = app.currentWorksheets;
    if (sheets.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: scheme.secondaryContainer,
                child: Icon(
                  Icons.edit_document,
                  color: scheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No worksheets yet',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Generate one above; it will be saved to this profile.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sheets.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        mainAxisExtent: 178,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _historyCard(app, sheets[index]),
    );
  }

  Widget _historyCard(AppState app, Worksheet sheet) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSheet(sheet),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      sheet.subject.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _scoreChip(sheet, scheme),
                  PopupMenuButton<String>(
                    tooltip: 'Worksheet options',
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.more_vert, size: 18),
                    onSelected: (value) {
                      if (value == 'delete') _deleteSheet(app, sheet);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                sheet.title.isEmpty ? sheet.area : sheet.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _dateLabel(sheet.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.quiz_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${sheet.questionCount} questions',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.description_outlined,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${sheet.pages.length} ${sheet.pages.length == 1 ? 'page' : 'pages'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (sheet.aiReviewJson != null)
                    Icon(Icons.auto_awesome, size: 16, color: scheme.tertiary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreChip(Worksheet sheet, ColorScheme scheme) {
    final checked = sheet.marks.isNotEmpty;
    final label = !checked
        ? 'Not checked'
        : (sheet.total == null || sheet.total == 0)
        ? 'To review'
        : '${sheet.correct ?? 0}/${sheet.total}';
    final color = checked
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final textColor = checked
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
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

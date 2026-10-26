import 'package:flutter/material.dart';

import '../ai_service.dart';
import '../app_scope.dart';
import '../app_state.dart';
import '../models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _model = TextEditingController();
  final _apiKey = TextEditingController();
  final _geminiKey = TextEditingController();
  final _geminiModel = TextEditingController();

  static const _seedNames = <String>[
    'Purple',
    'Blue',
    'Green',
    'Red',
    'Rose',
    'Teal',
    'Amber',
  ];

  late String _provider;
  late bool _useFallback;
  bool _initialised = false;
  bool _testing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    final ai = AppScope.of(context).ai;
    _provider = ai.provider;
    _useFallback = ai.useFallback;
    _baseUrl.text = ai.baseUrl;
    _model.text = ai.model;
    _apiKey.text = ai.apiKey;
    _geminiKey.text = ai.geminiKey;
    _geminiModel.text = ai.geminiModel;
    _initialised = true;
  }

  @override
  void dispose() {
    _baseUrl.dispose();
    _model.dispose();
    _apiKey.dispose();
    _geminiKey.dispose();
    _geminiModel.dispose();
    super.dispose();
  }

  AiSettings _settingsFromForm() {
    return AiSettings(
      provider: _provider,
      baseUrl: _baseUrl.text.trim(),
      model: _model.text.trim(),
      apiKey: _apiKey.text.trim(),
      geminiKey: _geminiKey.text.trim(),
      geminiModel: _geminiModel.text.trim().isEmpty
          ? 'gemini-2.5-flash'
          : _geminiModel.text.trim(),
      useFallback: _useFallback,
    );
  }

  void _save() {
    final messenger = ScaffoldMessenger.of(context);
    final settings = _settingsFromForm();
    if (settings.isLocal) {
      if (settings.baseUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Add the address of your local AI server.'),
          ),
        );
        return;
      }
      if (settings.model.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Add the model name your server is running.'),
          ),
        );
        return;
      }
    }
    AppScope.of(context).setAiSettings(settings);
    messenger.showSnackBar(const SnackBar(content: Text('AI settings saved.')));
  }

  Future<void> _testConnection() async {
    if (_testing) return;
    final messenger = ScaffoldMessenger.of(context);
    final settings = _settingsFromForm();
    if (settings.isLocal && settings.baseUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add the server URL before testing.')),
      );
      return;
    }
    if (!settings.isLocal && settings.geminiKey.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add your Gemini API key before testing.'),
        ),
      );
      return;
    }
    setState(() => _testing = true);
    try {
      final reply = await AiService(settings).testConnection();
      if (!mounted) return;
      setState(() => _testing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Connected. The model replied: $reply')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _testing = false);
      final message = error is AiException ? error.message : error.toString();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.cloud_off_outlined),
          title: const Text('Connection failed'),
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _resetEverything() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Reset WorkinAI?'),
        content: const Text(
          'This deletes every profile, worksheet, answer, mark and drawing, and restores '
          'the default settings. This cannot be undone.',
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
            child: const Text('Reset everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await AppScope.of(context).resetEverything();
    if (!mounted) return;
    _provider = 'local';
    _useFallback = true;
    _baseUrl.text = 'http://localhost:1234/v1';
    _model.text = 'local-model';
    _apiKey.clear();
    _geminiKey.clear();
    _geminiModel.text = 'gemini-2.5-flash';
    setState(() {});
    messenger.showSnackBar(
      const SnackBar(content: Text('WorkinAI has been reset.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make it yours',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Appearance changes apply immediately. AI settings are saved with the button above.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                _section(
                  icon: Icons.palette_outlined,
                  title: 'Appearance',
                  subtitle: 'Material 3 theme and seed colour',
                  children: [
                    Text('Theme mode', style: _labelStyle(theme)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_outlined, size: 18),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_outlined, size: 18),
                            label: Text('Dark'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(
                              Icons.brightness_auto_outlined,
                              size: 18,
                            ),
                            label: Text('System'),
                          ),
                        ],
                        selected: {app.themeMode},
                        onSelectionChanged: (values) {
                          app.setThemeMode(values.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Seed colour', style: _labelStyle(theme)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (
                          var index = 0;
                          index < AppState.seedColors.length;
                          index++
                        )
                          _seedSwatch(
                            app,
                            AppState.seedColors[index],
                            scheme,
                            _seedNames[index],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Every screen, button and badge is generated from this colour.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.auto_awesome,
                  title: 'AI provider',
                  subtitle: 'Where worksheets are designed',
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: 'local',
                            icon: Icon(Icons.dns_outlined, size: 18),
                            label: Text('Local server'),
                          ),
                          ButtonSegment(
                            value: 'gemini',
                            icon: Icon(Icons.cloud_outlined, size: 18),
                            label: Text('Gemini'),
                          ),
                        ],
                        selected: {_provider},
                        onSelectionChanged: (values) {
                          setState(() => _provider = values.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_provider == 'local')
                      ..._localFields(theme, scheme)
                    else
                      ..._geminiFields(theme, scheme),
                    const SizedBox(height: 16),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _useFallback,
                      onChanged: (value) =>
                          setState(() => _useFallback = value),
                      title: const Text(
                        'Use the built-in generator as a fallback',
                      ),
                      subtitle: const Text(
                        'If the AI is unreachable, build a ready-made worksheet instead of stopping.',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon: _testing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.wifi_tethering, size: 18),
                          label: Text(
                            _testing ? 'Testing…' : 'Test connection',
                          ),
                        ),
                        Text(
                          _provider == 'local'
                              ? 'Needs an OpenAI-compatible server with CORS enabled.'
                              : 'Needs an API key with Gemini access.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 18,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Settings and worksheets stay in this browser. Worksheet requests are sent directly '
                              'to the server you choose, never through a WorkinAI server.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSecondaryContainer,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.storage_outlined,
                  title: 'Local data',
                  subtitle: 'Profiles, worksheets, answers and marks',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${app.worksheets.length} worksheet${app.worksheets.length == 1 ? '' : 's'} stored',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Across ${app.profiles.length} profile${app.profiles.length == 1 ? '' : 's'}.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _resetEverything,
                          icon: const Icon(
                            Icons.delete_forever_outlined,
                            size: 18,
                          ),
                          label: const Text('Reset all'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.error,
                            side: BorderSide(
                              color: scheme.error.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'WorkinAI · local worksheet studio',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _localFields(ThemeData theme, ColorScheme scheme) {
    return [
      Text('Local LLM server', style: _labelStyle(theme)),
      const SizedBox(height: 6),
      TextField(
        controller: _baseUrl,
        decoration: const InputDecoration(
          hintText: 'http://localhost:1234/v1',
          prefixIcon: Icon(Icons.link_outlined),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _preset('LM Studio', 'http://localhost:1234/v1'),
          _preset('Ollama', 'http://localhost:11434/v1'),
          _preset('Jan', 'http://localhost:1337/v1'),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Model name', style: _labelStyle(theme)),
                const SizedBox(height: 6),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(
                    hintText: 'e.g. qwen2.5-7b-instruct',
                    prefixIcon: Icon(Icons.memory_outlined),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('API key (optional)', style: _labelStyle(theme)),
                const SizedBox(height: 6),
                TextField(
                  controller: _apiKey,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Only if your server needs one',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Text(
        'Enter the base URL, for example http://192.168.1.20:1234/v1. '
        'For visual review, the selected model must accept images.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    ];
  }

  List<Widget> _geminiFields(ThemeData theme, ColorScheme scheme) {
    return [
      Text('Gemini API key', style: _labelStyle(theme)),
      const SizedBox(height: 6),
      TextField(
        controller: _geminiKey,
        obscureText: true,
        decoration: const InputDecoration(
          hintText: 'AIza…',
          prefixIcon: Icon(Icons.key_outlined),
        ),
      ),
      const SizedBox(height: 14),
      Text('Model', style: _labelStyle(theme)),
      const SizedBox(height: 6),
      TextField(
        controller: _geminiModel,
        decoration: const InputDecoration(
          hintText: 'gemini-2.5-flash',
          prefixIcon: Icon(Icons.cloud_outlined),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'The key is stored only in this browser. Gemini is optional — a local server keeps '
        'everything on your network.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    ];
  }

  Widget _preset(String label, String url) {
    return ActionChip(
      label: Text(label),
      avatar: const Icon(Icons.bolt_outlined, size: 16),
      onPressed: () {
        setState(() {
          _provider = 'local';
          _baseUrl.text = url;
        });
      },
    );
  }

  Widget _seedSwatch(AppState app, int value, ColorScheme scheme, String name) {
    final selected = app.seedValue == value;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name seed colour',
      child: Tooltip(
        message: '$name seed colour',
        child: InkWell(
          onTap: () => app.setSeed(value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Color(value),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? scheme.onSurface : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }

  TextStyle? _labelStyle(ThemeData theme) {
    return theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }
}

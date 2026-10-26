import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../ai_service.dart';
import '../fallback_generator.dart';

class GeneratingScreen extends StatefulWidget {
  const GeneratingScreen({
    super.key,
    required this.profileId,
    required this.subject,
    required this.area,
    required this.level,
    required this.notes,
    required this.questionCount,
    required this.modelLabel,
    required this.service,
    this.allowBuiltIn = true,
  });

  final String profileId;
  final String subject;
  final String area;
  final String level;
  final String notes;
  final int questionCount;
  final String modelLabel;
  final AiService service;
  final bool allowBuiltIn;

  @override
  State<GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<GeneratingScreen>
    with TickerProviderStateMixin {
  static const _stages = <String>[
    'Waking the model',
    'Planning the pages',
    'Writing questions',
    'Laying out the sheet',
  ];

  static const _tips = <String>[
    'The worksheet will be ready to type on, draw on, or print.',
    'Small local models can take a minute. A larger model is usually quicker.',
    'Ask for fewer questions if you want a faster first draft.',
    'The AI can spread the work over several A4 pages.',
    'Answers and keywords are saved with every question for checking later.',
    'You can change the theme and seed colour in Settings.',
  ];

  late final AnimationController _pulse;
  late final AnimationController _orbit;
  Timer? _ticker;
  final Stopwatch _watch = Stopwatch();

  String? _error;
  bool _finishing = false;
  int _tipIndex = 0;
  int _lastTipSecond = -10;

  int get _elapsedSeconds => _watch.elapsed.inSeconds;

  int get _stage {
    final seconds = _elapsedSeconds;
    if (seconds < 4) return 0;
    if (seconds < 12) return 1;
    if (seconds < 35) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _orbit = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _run();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    _orbit.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    _ticker?.cancel();
    _watch
      ..reset()
      ..start();
    setState(() {
      _error = null;
      _finishing = false;
      _tipIndex = 0;
      _lastTipSecond = -10;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final second = _elapsedSeconds;
      setState(() {
        if (second - _lastTipSecond >= 8) {
          _lastTipSecond = second;
          _tipIndex = (_tipIndex + 1) % _tips.length;
        }
      });
    });

    try {
      final worksheet = await widget.service.generateWorksheet(
        profileId: widget.profileId,
        subject: widget.subject,
        area: widget.area,
        level: widget.level,
        notes: widget.notes,
        questionCount: widget.questionCount,
      );
      if (!mounted) return;
      _ticker?.cancel();
      _watch.stop();
      setState(() => _finishing = true);
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted) return;
      Navigator.of(context).pop(worksheet);
    } catch (failure) {
      if (!mounted) return;
      _ticker?.cancel();
      _watch.stop();
      setState(() {
        _finishing = false;
        _error = failure is AiException ? failure.message : failure.toString();
      });
    }
  }

  void _useBuiltIn() {
    final worksheet = generateFallbackWorksheet(
      profileId: widget.profileId,
      subject: widget.subject,
      area: widget.area,
      questionCount: widget.questionCount,
    );
    Navigator.of(context).pop(worksheet);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final error = _error;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          _Backdrop(scheme: scheme),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: error == null
                            ? _buildWorking(theme, scheme)
                            : _buildError(theme, scheme, error),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorking(ThemeData theme, ColorScheme scheme) {
    return LayoutBuilder(
      key: const ValueKey('working'),
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final status = _buildStatus(theme, scheme);
        final paper = _buildPaper(theme, scheme);
        if (!wide) {
          return Column(
            children: [
              status,
              const SizedBox(height: 18),
              SizedBox(height: 170, child: paper),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 6, child: status),
            const SizedBox(width: 44),
            Expanded(flex: 4, child: paper),
          ],
        );
      },
    );
  }

  Widget _buildStatus(ThemeData theme, ColorScheme scheme) {
    final stage = _stage;
    final seconds = _elapsedSeconds;
    final label =
        '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    return Semantics(
      liveRegion: true,
      label: _finishing
          ? 'Worksheet ready'
          : '${_stages[stage]}. Generating for $label.',
      child: Card(
        key: const ValueKey('status'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 26, 26, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 13,
                          color: scheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'WORKINAI STUDIO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 0.9,
                            fontWeight: FontWeight.w800,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_finishing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 17,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Ready',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'A4 · $label',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOrb(scheme),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _finishing
                              ? 'Almost there…'
                              : 'Designing your worksheet',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${widget.subject} · ${widget.area}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.questionCount} questions · ${widget.modelLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 22),
              for (var index = 0; index < _stages.length; index++)
                _stageRow(theme, scheme, index, stage),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  key: ValueKey(_tipIndex),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 18,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _tips[_tipIndex],
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_finishing) ...[
                const SizedBox(height: 16),
                Text(
                  'This can take a minute with a small local model. Keep this tab open.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stageRow(ThemeData theme, ColorScheme scheme, int index, int stage) {
    final done = index < stage || _finishing;
    final active = index == stage && !_finishing;
    final color = done || active ? scheme.primary : scheme.outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: done
                ? Icon(Icons.check_circle, size: 20, color: scheme.primary)
                : active
                ? Padding(
                    padding: const EdgeInsets.all(3),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  )
                : Icon(
                    Icons.radio_button_unchecked,
                    size: 18,
                    color: scheme.outlineVariant,
                  ),
          ),
          const SizedBox(width: 11),
          Text(
            _stages[index],
            style: theme.textTheme.bodyMedium?.copyWith(
              color: done || active
                  ? scheme.onSurface
                  : scheme.onSurfaceVariant,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          if (active) ...[
            const SizedBox(width: 8),
            Text(
              '…',
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrb(ColorScheme scheme) {
    return SizedBox(
      width: 92,
      height: 92,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulse, _orbit]),
        builder: (context, child) {
          final pulse = 0.94 + _pulse.value * 0.08;
          final angle = _orbit.value * math.pi * 2;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: pulse,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(
                          alpha: 0.10 + _pulse.value * 0.16,
                        ),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 34,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(math.cos(angle) * 40, math.sin(angle) * 40),
                child: Icon(
                  Icons.star,
                  size: 13,
                  color: scheme.primary.withValues(alpha: 0.75),
                ),
              ),
              Transform.translate(
                offset: Offset(
                  math.cos(angle + math.pi) * 40,
                  math.sin(angle + math.pi) * 40,
                ),
                child: Icon(
                  Icons.circle,
                  size: 7,
                  color: scheme.tertiary.withValues(alpha: 0.7),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaper(ThemeData theme, ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final glow = 0.55 + _pulse.value * 0.35;
        return AspectRatio(
          aspectRatio: 0.72,
          child: Container(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF24211D)
                  : const Color(0xFFFFFCF7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(
                                Icons.auto_awesome,
                                size: 13,
                                color: scheme.onPrimary,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _paperLine(scheme, 0.8, 7),
                                  const SizedBox(height: 4),
                                  _paperLine(scheme, 0.45, 4),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        _paperLine(scheme, 0.55, 9),
                        const SizedBox(height: 5),
                        _paperLine(scheme, 0.72, 5),
                        const SizedBox(height: 17),
                        for (var index = 0; index < 5; index++) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 13,
                                height: 13,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    fontSize: 6,
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _paperLine(
                                      scheme,
                                      0.92,
                                      5 + (index % 2) * 2,
                                    ),
                                    const SizedBox(height: 4),
                                    _paperLine(scheme, 0.66, 4),
                                    const SizedBox(height: 4),
                                    _paperLine(scheme, 0.78, 4),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            _paperLine(scheme, 0.35, 4),
                            const Spacer(),
                            Text(
                              'A4',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                letterSpacing: 1,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              scheme.primary.withValues(alpha: glow),
                              scheme.tertiary.withValues(alpha: glow * 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _paperLine(ColorScheme scheme, double widthFactor, double height) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, ColorScheme scheme, String error) {
    return Card(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 28, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.cloud_off_outlined,
                    color: scheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'That didn’t work',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        'The worksheet was not created.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Check the server is running and the URL in Settings is correct. '
              'For Ollama, the base URL should look like http://localhost:11434/v1.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: _run,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                ),
                if (widget.allowBuiltIn)
                  OutlinedButton.icon(
                    onPressed: _useBuiltIn,
                    icon: const Icon(Icons.bolt_outlined, size: 18),
                    label: const Text('Use built-in instead'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: _blob(360, scheme.primary.withValues(alpha: 0.10)),
          ),
          Positioned(
            bottom: -180,
            left: -140,
            child: _blob(420, scheme.tertiary.withValues(alpha: 0.09)),
          ),
          Positioned(
            top: 160,
            left: -180,
            child: _blob(300, scheme.secondary.withValues(alpha: 0.07)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

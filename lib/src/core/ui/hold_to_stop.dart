import 'package:flutter/material.dart';

import 'maxvolt_theme.dart';

/// Holding or accessible activation opens a dialog; never sends a command directly.
class HoldToStop extends StatefulWidget {
  const HoldToStop({super.key, required this.onConfirm, this.enabled = true});
  final VoidCallback onConfirm;
  final bool enabled;
  @override
  State<HoldToStop> createState() => _HoldToStopState();
}

class _HoldToStopState extends State<HoldToStop> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _progress = AnimationController(vsync: this, duration: const Duration(seconds: 2))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cancel();
        if (widget.enabled) widget.onConfirm();
      }
    });
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  bool _pointerActivation = false;
  void _release() {
    _cancel();
    Future<void>.delayed(Duration.zero, () {
      _pointerActivation = false;
    });
  }

  void _cancel() {
    _progress.stop();
    _progress.value = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  @override
  void didUpdateWidget(covariant HoldToStop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    label: 'Detener carga. Abrir confirmación',
    onTap: widget.enabled ? widget.onConfirm : null,
    child: ExcludeSemantics(
      child: Listener(
        onPointerDown: widget.enabled
            ? (_) {
                _pointerActivation = true;
                _progress.forward(from: 0);
              }
            : null,
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedBuilder(
          animation: _progress,
          builder: (context, _) => Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: _progress.value,
                      heightFactor: 1,
                      child: ColoredBox(color: MaxVolt.mint.withValues(alpha: .25)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.enabled
                      ? () {
                          if (!_pointerActivation) widget.onConfirm();
                        }
                      : null,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('Mantén 2 s para detener'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

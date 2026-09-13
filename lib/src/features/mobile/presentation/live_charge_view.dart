import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/maxvolt_theme.dart';
import '../../../core/ui/hold_to_stop.dart';

class LiveChargeView extends StatelessWidget {
  const LiveChargeView({
    super.key,
    required this.session,
    required this.onStop,
    this.stale = false,
    this.stopping = false,
  });
  final Map<String, dynamic> session;
  final VoidCallback onStop;
  final bool stale, stopping;
  double? _number(Object? value) {
    final n = double.tryParse(value?.toString() ?? '');
    return n != null && n.isFinite ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final metrics = session['current_metrics'] as Map? ?? {};
    final soc = _number(metrics['soc'] ?? session['current_soc']);
    final validSoc = soc != null && soc >= 0 && soc <= 100 ? soc : null;
    final power = _number(metrics['power_kw'] ?? session['power_kw']);
    final energy = _number(metrics['energy_kwh'] ?? session['total_energy_kwh']);
    final cost = _number(metrics['total_cost'] ?? session['total_cost']);
    final start = DateTime.tryParse(session['start_time']?.toString() ?? '');
    final elapsed = start == null ? null : DateTime.now().difference(start);
    String number(double? value, int digits) => value?.toStringAsFixed(digits) ?? '—';
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        MaxVoltHeading(
          'Un poco más lejos.',
          eyebrow: stopping ? 'Esperando confirmación de parada' : 'Tu energía en movimiento',
          subtitle: session['station'] is Map ? session['station']['name']?.toString() : 'Sesión #${session['id']}',
        ),
        if (stale)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Sin actualización. Mostramos los últimos datos recibidos; la carga puede continuar.'),
          ),
        const SizedBox(height: 24),
        Center(
          child: Semantics(
            label: validSoc == null ? 'Batería no disponible' : 'Batería al ${validSoc.round()} por ciento',
            child: SizedBox(
              width: 236,
              height: 236,
              child: CustomPaint(
                painter: _OrbitPainter(
                  validSoc == null ? null : validSoc / 100,
                  Theme.of(context).colorScheme.outlineVariant,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        validSoc == null ? '—' : '${validSoc.round()}%',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 64, letterSpacing: -3),
                      ),
                      Text(
                        validSoc == null ? 'Batería no disponible' : 'Batería del vehículo',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 18,
          runSpacing: 16,
          children: [
            _metric(context, number(power, 1), 'Potencia · kW'),
            _metric(context, number(energy, 2), 'Energía · kWh'),
            _metric(
              context,
              elapsed == null || elapsed.isNegative
                  ? '—'
                  : '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}',
              'Duración',
            ),
          ],
        ),
        const Divider(height: 40),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 20,
          runSpacing: 8,
          children: [
            const Text('Costo acumulado'),
            Text(
              '${session['currency'] == 'BOB' || session['currency'] == null ? 'Bs' : session['currency']} ${number(cost, 2)}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
        const SizedBox(height: 24),
        HoldToStop(onConfirm: onStop, enabled: !stopping),
        const SizedBox(height: 14),
        Text(
          stopping
              ? 'La solicitud fue enviada. Espera la confirmación del cargador antes de desconectar.'
              : 'Mantén presionado para abrir la confirmación de parada.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _metric(BuildContext context, String value, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(value, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.value, this.track);
  final double? value;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, math.pi * .72, math.pi * 1.65, false, paint);
    if (value != null && value! > 0) {
      paint.shader = const SweepGradient(
        colors: [MaxVolt.forest, MaxVolt.mint, MaxVolt.lime],
        startAngle: 0,
        endAngle: math.pi * 2,
      ).createShader(rect);
      canvas.drawArc(rect, math.pi * .72, math.pi * 1.65 * value!, false, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.value != value || old.track != track;
}

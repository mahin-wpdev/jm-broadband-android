import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'traffic_history.dart';

/// Sixty-second pulse chart; hour-long history is only used for peak records.
class TrafficChart extends StatefulWidget {
  final List<TrafficPoint> points;
  const TrafficChart({super.key, required this.points});

  @override
  State<TrafficChart> createState() => _TrafficChartState();
}

class _TrafficChartState extends State<TrafficChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant TrafficChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.points.isNotEmpty &&
        (oldWidget.points.isEmpty ||
            widget.points.last.atMs != oldWidget.points.last.atMs)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final visible = widget.points
        .where((p) => p.atMs >= now - 60000 && p.atMs <= now + 5000)
        .toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF152640), Color(0xFF091425)]),
        border: Border.all(color: const Color(0xFF304963)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const Icon(Icons.bolt, color: Color(0xFF67E8F9), size: 17),
            const SizedBox(width: 4),
            const Text('LIVE',
                style: TextStyle(
                    color: Color(0xFF67E8F9), fontWeight: FontWeight.w800)),
            const Spacer(),
            const Text('1s pulse  /  60s window',
                style: TextStyle(color: Color(0xFFB4C4D8), fontSize: 12)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _legend(const Color(0xFF38D9F9), 'Download'),
            const SizedBox(width: 18),
            _legend(const Color(0xFFA78BFA), 'Upload'),
          ]),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            const SizedBox(
                height: 195,
                child: Center(
                    child: Text('Waiting for live traffic samples',
                        style: TextStyle(color: Colors.white70))))
          else
            SizedBox(
              height: 195,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _TrafficPainter(
                    points: visible,
                    nowMs: now,
                    pulse: _pulse.value,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 7),
          const Text('Measured samples only · gaps are not filled',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9DB1C8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _legend(Color color, String name) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]);
}

class _TrafficPainter extends CustomPainter {
  final List<TrafficPoint> points;
  final int nowMs;
  final double pulse;
  const _TrafficPainter({
    required this.points,
    required this.nowMs,
    required this.pulse,
  });

  static const downColor = Color(0xFF38D9F9);
  static const upColor = Color(0xFFA78BFA);
  static const textColor = Color(0xFF9DB1C8);
  static const gridColor = Color(0xFF30445A);

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: const TextStyle(color: textColor, fontSize: 10)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 90 || size.height < 70) return;
    const left = 47.0, right = 7.0, top = 9.0, bottom = 23.0;
    final width = size.width - left - right;
    final height = size.height - top - bottom;
    final start = nowMs - 60000;
    final peak = points.fold<double>(1000000,
        (acc, p) => math.max(acc, math.max(p.downloadBps, p.uploadBps)));
    final maxMbps = math.max(1.0, (peak / 1000000 * 1.2).ceilToDouble());
    for (int i = 0; i <= 4; i++) {
      final y = top + height * i / 4;
      canvas.drawLine(
          Offset(left, y),
          Offset(left + width, y),
          Paint()
            ..color = gridColor
            ..strokeWidth = 0.8);
      _label(
          canvas, (maxMbps * (4 - i) / 4).toStringAsFixed(1), Offset(0, y - 6));
    }
    _label(canvas, 'Mbps', const Offset(0, 0));
    _label(canvas, '-60s', Offset(left, top + height + 6));
    _label(canvas, '-45s', Offset(left + width / 4 - 12, top + height + 6));
    _label(canvas, '-30s', Offset(left + width / 2 - 12, top + height + 6));
    _label(canvas, '-15s', Offset(left + width * 3 / 4 - 12, top + height + 6));
    _label(canvas, 'Now', Offset(left + width - 21, top + height + 6));
    final plot = Rect.fromLTWH(left, top, width, height);
    canvas.save();
    canvas.clipRect(plot);
    _line(canvas, plot, start, maxMbps, true, downColor);
    _line(canvas, plot, start, maxMbps, false, upColor);
    canvas.restore();
  }

  void _line(Canvas canvas, Rect plot, int start, double maxMbps, bool download,
      Color color) {
    Path line = Path();
    Offset? last;
    Offset? first;
    bool hasLine = false;
    void flush() {
      if (!hasLine || last == null || first == null) return;
      final fill = Path.from(line)
        ..lineTo(last.dx, plot.bottom)
        ..lineTo(first.dx, plot.bottom)
        ..close();
      canvas.drawPath(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color.withAlpha(96), color.withAlpha(4)],
            ).createShader(plot));
      canvas.drawPath(
          line,
          Paint()
            ..color = color
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      line = Path();
      hasLine = false;
    }

    int? previousMs;
    for (final point in points) {
      if (point.atMs < start || point.atMs > nowMs + 5000) continue;
      final x = plot.left + (point.atMs - start) / 60000 * plot.width;
      final value = download ? point.downloadBps : point.uploadBps;
      final y = plot.bottom - (value / 1000000 / maxMbps) * plot.height;
      final current = Offset(x, y);
      if (last == null ||
          previousMs == null ||
          point.atMs - previousMs > 2500) {
        flush();
        first = current;
        line.moveTo(x, y);
      } else {
        final dx = current.dx - last.dx;
        line.cubicTo(last.dx + dx * 0.45, last.dy, current.dx - dx * 0.45,
            current.dy, current.dx, current.dy);
      }
      last = current;
      previousMs = point.atMs;
      hasLine = true;
    }
    flush();
    if (last != null) {
      canvas.drawCircle(last, 4, Paint()..color = color);
      canvas.drawCircle(
          last,
          8 + 8 * (1 - pulse),
          Paint()
            ..color = color.withAlpha((95 * (1 - pulse)).round())
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
    }
  }

  @override
  bool shouldRepaint(covariant _TrafficPainter old) =>
      old.nowMs != nowMs || old.points != points || old.pulse != pulse;
}

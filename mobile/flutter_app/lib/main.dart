import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const ChronosDriftApp());
}

class ChronosDriftApp extends StatelessWidget {
  const ChronosDriftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chronos Drift Visualizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.cyan,
        scaffoldBackgroundColor: const Color(0xFF0A0A0E),
        cardColor: const Color(0xFF16161D),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double _currentDrift = 0.0;
  List<double> _history = [];
  Timer? _ticker;
  final int _maxHistory = 50;

  @override
  void initState() {
    super.initState();
    _startSimulation();
  }

  void _startSimulation() {
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        // Simulate high-precision drift telemetry mirroring the Rust backend
        _currentDrift = (math.Random().nextDouble() * 40.0) - 20.0;
        _history.add(_currentDrift);
        if (_history.length > _maxHistory) {
          _history.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHRONOS DRIFT TELEMETRY'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            Expanded(child: _buildVisualizer()),
            const SizedBox(height: 20),
            _buildMetricsGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CURRENT OFFSET', style: TextStyle(color: Colors.grey, fontSize: 12)),
              Text(
                '${_currentDrift.toStringAsFixed(3)} ms',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
            ],
          ),
          const Icon(Icons.radar, color: Colors.cyanAccent, size: 40),
        ],
      ),
    );
  }

  Widget _buildVisualizer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: CustomPaint(
        painter: DriftPainter(_history, _maxHistory),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _metricTile('STRATUM', '1'),
        _metricTile('PRECISION', '±0.002ms'),
        _metricTile('JITTER', '0.014ms'),
        _metricTile('SOURCE', 'Atomic/NTP'),
      ],
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class DriftPainter extends CustomPainter {
  final List<double> history;
  final int maxHistory;

  DriftPainter(this.history, this.maxHistory);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyan.withOpacity(0.8)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    final stepX = size.width / maxHistory;
    final centerY = size.height / 2;
    final scaleY = size.height / 60.0;

    // Draw baseline
    final gridPaint = Paint()..color = Colors.white10..strokeWidth = 1;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), gridPaint);

    for (int i = 0; i < history.length; i++) {
      double x = i * stepX;
      double y = centerY - (history[i] * scaleY);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Glow effect at tip
    if (history.isNotEmpty) {
      final lastX = (history.length - 1) * stepX;
      final lastY = centerY - (history.last * scaleY);
      canvas.drawCircle(Offset(lastX, lastY), 4, Paint()..color = Colors.cyanAccent);
    }
  }

  @override
  bool shouldRepaint(covariant DriftPainter oldDelegate) => true;
}
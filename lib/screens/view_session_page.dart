// lib/screens/view_session_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/recorded_session.dart';
import '../services/settings_service.dart';

class ViewSessionPage extends StatefulWidget {
  final RecordedSession session;

  const ViewSessionPage({super.key, required this.session});

  @override
  State<ViewSessionPage> createState() => _ViewSessionPageState();
}

class _ViewSessionPageState extends State<ViewSessionPage> {
  int _selectedIndex = 0; // 0:V1, 1:V2, 2:V3, 3:V4
  final SettingsService _settingsService = SettingsService.instance;

  late double _minX, _maxX, _minY, _maxY;
  late double _initialMinX, _initialMaxX, _initialMinY, _initialMaxY;

  @override
  void initState() {
    super.initState();
    _setupInitialBoundaries();
  }

  List<FlSpot> get _selectedData {
    switch (_selectedIndex) {
      case 0:
        return widget.session.v1Data;
      case 1:
        return widget.session.v2Data;
      case 2:
        return widget.session.v3Data;
      case 3:
        return widget.session.v4Data;
      default:
        return [];
    }
  }

  void _setupInitialBoundaries() {
    final allData = [
      ...widget.session.v1Data,
      ...widget.session.v2Data,
      ...widget.session.v3Data,
      ...widget.session.v4Data,
    ];

    if (allData.isEmpty) {
      _initialMinX = 0;
      _initialMaxX = 10;
      _initialMinY = 0;
      _initialMaxY = 10;
    } else {
      _initialMinX = allData.map((e) => e.x).reduce(min);
      _initialMaxX = allData.map((e) => e.x).reduce(max);
      _initialMinY = allData.map((e) => e.y.abs()).reduce(min);
      _initialMaxY = allData.map((e) => e.y.abs()).reduce(max);

      final xPadding = (_initialMaxX - _initialMinX) * 0.05;
      final yPadding = (_initialMaxY - _initialMinY) * 0.1;
      _initialMinX -= xPadding;
      _initialMaxX += xPadding;
      _initialMinY = 0; // Genelde mutlak değer grafiği çizeriz
      _initialMaxY += yPadding;
    }
    _resetZoom();
  }

  void _resetZoom() {
    setState(() {
      _minX = _initialMinX;
      _maxX = _initialMaxX;
      _minY = _initialMinY;
      _maxY = _initialMaxY;
    });
  }

  // lib/screens/view_session_page.dart dosyasında

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kayıtlı Oturum: Motor ${_selectedIndex + 1}'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            tooltip: "Görünümü Sıfırla",
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: _selectedData.isEmpty
          ? Center(
              child: Text(
                "Motor ${_selectedIndex + 1} için kayıtlı veri bulunamadı.",
              ),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: LineChart(
                LineChartData(
                  minY: _minY,
                  maxY: _maxY,
                  minX: _minX,
                  maxX: _maxX,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _selectedData
                          .map((s) => FlSpot(s.x, s.y.abs()))
                          .toList(),
                      color: _settingsService.transmitterColors[_selectedIndex],
                      barWidth: 2,
                      isCurved: false,
                      dotData: const FlDotData(show: false),
                    ),
                  ],

                  // --- YENİ EKLENEN KISIM ---
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      // Uyarı Eşiği Çizgisi
                      HorizontalLine(
                        y: _settingsService.warningThreshold,
                        color: Colors.yellowAccent.withOpacity(0.8),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 2),
                          style: TextStyle(
                            color: Colors.yellowAccent.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'Uyarı',
                        ),
                      ),
                      // Hata Eşiği Çizgisi
                      HorizontalLine(
                        y: _settingsService.errorThreshold,
                        color: Colors.redAccent.withOpacity(0.8),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 5, bottom: 2),
                          style: TextStyle(
                            color: Colors.redAccent.withOpacity(0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          labelResolver: (line) => 'Hata',
                        ),
                      ),
                    ],
                  ),

                  // --- YENİ KISIM SONU ---
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: (_maxX - _minX) / 5,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    getDrawingHorizontalLine: (v) =>
                        const FlLine(color: Colors.white10, strokeWidth: 0.5),
                    getDrawingVerticalLine: (v) =>
                        const FlLine(color: Colors.white10, strokeWidth: 0.5),
                  ),
                  borderData: FlBorderData(show: false),
                ),
                duration: Duration.zero,
              ),
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() {
          _selectedIndex = index;
          _setupInitialBoundaries();
        }),
        backgroundColor: Theme.of(context).primaryColor,
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        items: List.generate(
          4,
          (i) => BottomNavigationBarItem(
            icon: const Icon(Icons.sensors_outlined),
            activeIcon: const Icon(Icons.sensors),
            label: "V${i + 1}",
            backgroundColor: _settingsService.transmitterColors[i],
          ),
        ),
      ),
    );
  }
}

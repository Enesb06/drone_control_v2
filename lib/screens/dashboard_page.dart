// lib/screens/dashboard_page.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/settings_service.dart';

final esp32WebSocketUrl = Uri.parse('ws://192.168.4.1:81');

enum DataType { x_axis, y_axis, z_axis, resultant }

// --- YENİ: Pasif durum eklendi ---
enum MotorStatus { normal, warning, outOfBounds, inactive }

class DroneDashboardPage extends StatefulWidget {
  const DroneDashboardPage({super.key});

  @override
  State<DroneDashboardPage> createState() => _DroneDashboardPageState();
}

class _DroneDashboardPageState extends State<DroneDashboardPage> {
  // --- STATE DEĞİŞKENLERİ ---
  final int _numTransmitters = 4;
  DataType _selectedDataType = DataType.resultant;

  final Map<int, List<FlSpot>> _dataSpotsX = {
    for (var i = 0; i < 4; i++) i: [],
  };
  final Map<int, List<FlSpot>> _dataSpotsY = {
    for (var i = 0; i < 4; i++) i: [],
  };
  final Map<int, List<FlSpot>> _dataSpotsZ = {
    for (var i = 0; i < 4; i++) i: [],
  };
  final Map<int, List<FlSpot>> _dataSpotsResultant = {
    for (var i = 0; i < 4; i++) i: [],
  };
  // --- GÜNCELLENDİ: Başlangıç durumu inactive olarak ayarlandı ---
  final Map<int, MotorStatus> _motorStatus = {
    for (var i = 0; i < 4; i++) i: MotorStatus.inactive,
  };

  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Bağlanılıyor...";
  double _globalTime = 0;
  final int _dataPointIntervalMs = 100;
  final int _displaySeconds = 5;
  Timer? _dataTimer;
  bool _isClosing = false;

  final SettingsService _settingsService = SettingsService.instance;

  int _selectedViewIndex = 0;
  late List<bool> _viewSelections;

  // --- YENİ: Her vericiden en son ne zaman veri geldiğini saklar ---
  final Map<int, DateTime> _lastDataTime = {};
  // --- YENİ: Bir vericiyi pasif olarak işaretlemek için zaman aşımı süresi ---
  final Duration _inactiveTimeout = const Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _viewSelections = List.generate(5, (index) => index == 0);
    _connectToWebSocket();
    _startDataTimer();
  }

  @override
  void dispose() {
    _isClosing = true;
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _dataTimer?.cancel();
    super.dispose();
  }

  void _connectToWebSocket() {
    if (!mounted) return;
    try {
      _channel = WebSocketChannel.connect(esp32WebSocketUrl);
      _socketSubscription = _channel!.stream.listen(
        (message) {
          if (!mounted || _isClosing) return;
          if (!_isConnected) {
            setState(() {
              _isConnected = true;
              _connectionStatus = "Bağlı - Veri Bekleniyor";
            });
          }
          _handleWebSocketData(message);
        },
        onDone: () {
          if (mounted && !_isClosing) {
            _isClosing = true;
            Navigator.of(context).pop();
          }
        },
        onError: (error) {
          if (mounted && !_isClosing) {
            _isClosing = true;
            Navigator.of(context).pop();
          }
        },
      );
    } catch (e) {
      if (mounted && !_isClosing) {
        _isClosing = true;
        Navigator.of(context).pop();
      }
    }
  }

  void _handleWebSocketData(String jsonData) {
    if (!mounted || _isClosing) return;
    try {
      final data = jsonDecode(jsonData);
      if (data.containsKey('empty') && data['empty'] == true) return;

      final int transmitterIndex = (data['id'] as int) - 1;
      if (transmitterIndex < 0 || transmitterIndex >= _numTransmitters) return;

      // --- YENİ: Veri geldiği zamanı kaydet ---
      _lastDataTime[transmitterIndex] = DateTime.now();

      final double ax = (data['ax'] as num).toDouble();
      final double ay = (data['ay'] as num).toDouble();
      final double az = (data['az'] as num).toDouble();
      final double mag = (data['mag'] as num).toDouble();

      setState(() {
        _dataSpotsX[transmitterIndex]!.add(FlSpot(_globalTime, ax));
        _dataSpotsY[transmitterIndex]!.add(FlSpot(_globalTime, ay));
        _dataSpotsZ[transmitterIndex]!.add(FlSpot(_globalTime, az));
        _dataSpotsResultant[transmitterIndex]!.add(FlSpot(_globalTime, mag));

        MotorStatus newStatus;
        if (mag.abs() > _settingsService.errorThreshold)
          newStatus = MotorStatus.outOfBounds;
        else if (mag.abs() > _settingsService.warningThreshold)
          newStatus = MotorStatus.warning;
        else
          newStatus = MotorStatus.normal;

        if (_motorStatus[transmitterIndex] != newStatus)
          _motorStatus[transmitterIndex] = newStatus;
      });
    } catch (e) {}
  }

  void _startDataTimer() {
    _dataTimer = Timer.periodic(Duration(milliseconds: _dataPointIntervalMs), (
      timer,
    ) {
      if (!mounted || _isClosing) {
        timer.cancel();
        return;
      }

      // --- YENİ: Pasif sensörleri kontrol etme mantığı ---
      final now = DateTime.now();
      bool statusChanged = false;
      for (int i = 0; i < _numTransmitters; i++) {
        // Eğer vericiden daha önce veri gelmişse ve o veri zaman aşımına uğradıysa
        if (_lastDataTime.containsKey(i) &&
            now.difference(_lastDataTime[i]!) > _inactiveTimeout &&
            _motorStatus[i] != MotorStatus.inactive) {
          _motorStatus[i] = MotorStatus.inactive;
          statusChanged = true;
        }
      }

      setState(() {
        _globalTime += (_dataPointIntervalMs / 1000.0);
        final allLists = [
          _dataSpotsX,
          _dataSpotsY,
          _dataSpotsZ,
          _dataSpotsResultant,
        ];
        for (var dataMap in allLists) {
          for (var list in dataMap.values) {
            list.removeWhere((spot) => spot.x < _globalTime - _displaySeconds);
          }
        }
        // Eğer bir durum değişikliği olduysa setState zaten çağrılmış olur.
        // Bu, gereksiz yeniden çizimleri önler.
        if (statusChanged) {
          print("Sensör durumu güncellendi: Bir veya daha fazla sensör pasif.");
        }
      });
    });
  }

  String _getAppBarTitle() {
    if (_selectedViewIndex < 4) {
      String status;
      if (_motorStatus[_selectedViewIndex] == MotorStatus.inactive) {
        status = "Pasif";
      } else {
        status = "Veri Alınıyor";
      }
      return 'V${_selectedViewIndex + 1} Monitör - $status';
    } else {
      return 'Tüm Vericiler - Bileşke Grafik';
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isAllView = _selectedViewIndex == 4;
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Theme.of(context).primaryColor,
        actions: isAllView
            ? null
            : [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: SegmentedButton<DataType>(
                    segments: const [
                      ButtonSegment(value: DataType.x_axis, label: Text('X')),
                      ButtonSegment(value: DataType.y_axis, label: Text('Y')),
                      ButtonSegment(value: DataType.z_axis, label: Text('Z')),
                      ButtonSegment(
                        value: DataType.resultant,
                        label: Text('Bileşke'),
                      ),
                    ],
                    selected: {_selectedDataType},
                    onSelectionChanged: (newSelection) =>
                        setState(() => _selectedDataType = newSelection.first),
                  ),
                ),
              ],
      ),
      body: _isConnected ? _buildGraph() : _buildConnectionPrompt(),
      bottomNavigationBar: _buildViewSelector(),
    );
  }

  Widget _buildViewSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Theme.of(context).primaryColor,
      child: ToggleButtons(
        isSelected: _viewSelections,
        onPressed: (int index) {
          setState(() {
            _selectedViewIndex = index;
            for (int i = 0; i < _viewSelections.length; i++) {
              _viewSelections[i] = (i == index);
            }
          });
        },
        borderRadius: BorderRadius.circular(8.0),
        borderWidth: 2,
        borderColor: Colors.white24,
        selectedBorderColor: Colors.cyanAccent,
        fillColor: Colors.cyan.withOpacity(0.2),
        color: Colors.white70,
        selectedColor: Colors.cyanAccent,
        constraints: BoxConstraints(
          minWidth: (MediaQuery.of(context).size.width - 24) / 5,
          minHeight: 40.0,
        ),
        children: List.generate(5, (index) {
          if (index < 4) {
            return _buildMotorTab("V${index + 1}", _motorStatus[index]!);
          } else {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                "TÜMÜ",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            );
          }
        }),
      ),
    );
  }

  Widget _buildGraph() {
    final double minX = max(0.0, _globalTime - _displaySeconds);
    final double maxX = max(_displaySeconds.toDouble(), _globalTime);
    List<LineChartBarData> lines = [];

    if (_selectedViewIndex == 4) {
      for (int i = 0; i < _numTransmitters; i++) {
        // Sadece aktif olan sensörlerin çizgisini göster
        if (_motorStatus[i] != MotorStatus.inactive) {
          lines.add(
            LineChartBarData(
              spots: _dataSpotsResultant[i]!,
              color: _settingsService.transmitterColors[i],
              barWidth: 2,
              isCurved: false,
              dotData: const FlDotData(show: false),
            ),
          );
        }
      }
    } else {
      List<FlSpot> spots;
      switch (_selectedDataType) {
        case DataType.x_axis:
          spots = _dataSpotsX[_selectedViewIndex]!;
          break;
        case DataType.y_axis:
          spots = _dataSpotsY[_selectedViewIndex]!;
          break;
        case DataType.z_axis:
          spots = _dataSpotsZ[_selectedViewIndex]!;
          break;
        case DataType.resultant:
          spots = _dataSpotsResultant[_selectedViewIndex]!;
          break;
      }
      lines.add(
        LineChartBarData(
          spots: spots,
          color: _settingsService.transmitterColors[_selectedViewIndex],
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: -5,
          maxY: 5,
          minX: minX,
          maxX: maxX,
          lineBarsData: lines,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: Colors.white10, strokeWidth: 0.5),
            getDrawingVerticalLine: (value) =>
                const FlLine(color: Colors.white10, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1.0,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0)),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
        duration: Duration.zero,
      ),
    );
  }

  Widget _buildConnectionPrompt() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text(_connectionStatus),
      ],
    ),
  );

  Widget _buildMotorTab(String title, MotorStatus status) {
    Color indicatorColor;
    switch (status) {
      case MotorStatus.normal:
        indicatorColor = Colors.greenAccent;
        break;
      case MotorStatus.warning:
        indicatorColor = Colors.yellowAccent;
        break;
      case MotorStatus.outOfBounds:
        indicatorColor = Colors.redAccent;
        break;
      // --- YENİ: Pasif durum için renk ---
      case MotorStatus.inactive:
        indicatorColor = Colors.grey[600]!;
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: indicatorColor,
            ),
          ),
        ],
      ),
    );
  }
}

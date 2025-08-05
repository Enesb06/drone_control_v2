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

enum MotorStatus { normal, warning, outOfBounds }

class DroneDashboardPage extends StatefulWidget {
  const DroneDashboardPage({super.key});

  @override
  State<DroneDashboardPage> createState() => _DroneDashboardPageState();
}

class _DroneDashboardPageState extends State<DroneDashboardPage> {
  // --- STATE DEĞİŞKENLERİ ---
  final int _numTransmitters = 4;
  DataType _selectedDataType = DataType.resultant;

  // Veri listeleri
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
  final Map<int, MotorStatus> _motorStatus = {
    for (var i = 0; i < 4; i++) i: MotorStatus.normal,
  };

  // Bağlantı ve Zamanlama
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Bağlanılıyor...";
  double _globalTime = 0;
  final int _dataPointIntervalMs = 100;
  final int _displaySeconds = 5;
  Timer? _dataTimer;
  bool _isClosing = false;
  bool _hasRealData = false;

  final SettingsService _settingsService = SettingsService.instance;

  // --- YENİ: Arayüz durumu için ---
  // 0-3: V1-V4, 4: TÜMÜ
  int _selectedViewIndex = 0;
  // ToggleButtons'un seçili durumunu tutan liste
  late List<bool> _viewSelections;

  @override
  void initState() {
    super.initState();
    // 5 buton var, ilki seçili
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
    // ... Bu fonksiyon aynı kalıyor ...
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
    // ... Bu fonksiyon aynı kalıyor (SettingsService'den okuma dahil) ...
    if (!mounted || _isClosing) return;
    try {
      final data = jsonDecode(jsonData);
      if (data.containsKey('empty') && data['empty'] == true) return;

      final int transmitterIndex = (data['id'] as int) - 1;
      if (transmitterIndex < 0 || transmitterIndex >= _numTransmitters) return;

      final double ax = (data['ax'] as num).toDouble();
      final double ay = (data['ay'] as num).toDouble();
      final double az = (data['az'] as num).toDouble();
      final double mag = (data['mag'] as num).toDouble();

      setState(() {
        if (!_hasRealData) _hasRealData = true;
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
    // ... Bu fonksiyon aynı kalıyor ...
    _dataTimer = Timer.periodic(Duration(milliseconds: _dataPointIntervalMs), (
      timer,
    ) {
      if (!mounted || _isClosing) {
        timer.cancel();
        return;
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
      });
    });
  }

  // --- GÜNCELLENDİ: Başlık metnini dinamik olarak oluşturur ---
  String _getAppBarTitle() {
    if (_selectedViewIndex < 4) {
      String status = _hasRealData ? "Veri Alınıyor" : "Boş Grafik";
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
        // X, Y, Z, Bileşke butonları "TÜMÜ" modunda gizlenir.
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
      // --- YENİ: Butonlar için alt panel ---
      bottomNavigationBar: _buildViewSelector(),
    );
  }

  // --- YENİ: V1-V4 ve TÜMÜ butonlarını oluşturan widget ---
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

  // --- GÜNCELLENDİ: Grafik oluşturma mantığı ---
  Widget _buildGraph() {
    final double minX = max(0.0, _globalTime - _displaySeconds);
    final double maxX = max(_displaySeconds.toDouble(), _globalTime);

    List<LineChartBarData> lines = [];

    // "TÜMÜ" modu seçiliyse
    if (_selectedViewIndex == 4) {
      for (int i = 0; i < _numTransmitters; i++) {
        lines.add(
          LineChartBarData(
            spots: _dataSpotsResultant[i]!,
            color:
                _settingsService.transmitterColors[i], // Ayarlardan gelen renk
            barWidth: 2,
            isCurved: false,
            dotData: const FlDotData(show: false),
          ),
        );
      }
    }
    // Tek bir verici modu seçiliyse
    else {
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
          color: _settingsService
              .transmitterColors[_selectedViewIndex], // Ayarlardan gelen renk
          barWidth: 2,
          isCurved: false,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Padding(
      // ... Geri kalan Padding ve LineChartData yapısı büyük ölçüde aynı kalıyor.
      // Sadece lineBarsData'yı yukarıda oluşturduğumuz 'lines' listesiyle değiştiriyoruz.
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: -5,
          maxY: 5,
          minX: minX,
          maxX: maxX,
          lineBarsData: lines, // DİNAMİK ÇİZGİLER
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

  // ... _buildConnectionPrompt aynı kalıyor ...
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

  // --- GÜNCELLENDİ: Bu widget artık sadece ToggleButtons içinde kullanılıyor ---
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

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

// --- Global Sabitler ve Enumlar ---

// ESP32'nin oluşturduğu Access Point'in IP adresi genellikle bu olur.
// ESP32 kodundaki port numarasıyla (81) aynı olmalıdır.
final esp32WebSocketUrl = Uri.parse('ws://192.168.4.1:81');

// Grafik üzerinde hangi veri tipinin gösterileceğini belirler.
enum DataType { x_axis, y_axis, z_axis, resultant }

// Motor durumunu renklerle göstermek için kullanılır.
enum MotorStatus { normal, warning, outOfBounds }

// --- Uygulamanın Başlangıç Noktası ---
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drone Titreşim Monitörü',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF161625),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        useMaterial3: true,
      ),
      home: const DroneDashboardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Ana Dashboard Sayfası ---
class DroneDashboardPage extends StatefulWidget {
  const DroneDashboardPage({super.key});

  @override
  State<DroneDashboardPage> createState() => _DroneDashboardPageState();
}

class _DroneDashboardPageState extends State<DroneDashboardPage>
    with TickerProviderStateMixin {
  late TabController _transmitterTabController;
  final int _numTransmitters = 4;

  // --- KULLANICI ARAYÜZÜ DURUMU ---
  int _selectedTransmitterIndex = 0;
  DataType _selectedDataType = DataType.resultant;

  // --- VERİ SAKLAMA ---
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

  // --- WEBSOCKET VE BAĞLANTI DURUMU ---
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Bağlanılıyor...";

  // --- ZAMANLAYICI VE GRAFİK AYARLARI ---
  double _globalTime = 0;
  final int _dataPointIntervalMs = 100; // Grafik zaman eksenini ilerletme hızı
  final int _displaySeconds = 5; // Grafikte kaç saniyelik verinin gösterileceği
  Timer? _dataTimer;

  // TODO: Bu değerleri daha sonra bir ayarlar sayfasından yönetebilirsiniz.
  final double _warningValue = 2.0;
  final double _outOfBoundsValue = 4.0;

  @override
  void initState() {
    super.initState();
    _transmitterTabController = TabController(
      length: _numTransmitters,
      vsync: this,
    );
    _transmitterTabController.addListener(() {
      if (!_transmitterTabController.indexIsChanging && mounted) {
        setState(
          () => _selectedTransmitterIndex = _transmitterTabController.index,
        );
      }
    });

    _connectToWebSocket();
    _startDataTimer();
  }

  @override
  void dispose() {
    _transmitterTabController.dispose();
    _socketSubscription?.cancel();
    _channel?.sink.close();
    _dataTimer?.cancel();
    super.dispose();
  }

  void _connectToWebSocket() {
    // Mevcut bağlantıyı kapat (yeniden bağlanma durumları için)
    _socketSubscription?.cancel();
    _channel?.sink.close();

    if (!mounted) return;

    setState(() {
      _isConnected = false;
      _connectionStatus = "ESP32 Ağına Bağlanılıyor...";
    });

    try {
      _channel = WebSocketChannel.connect(esp32WebSocketUrl);
      _socketSubscription = _channel!.stream.listen(
        (message) {
          if (!mounted) return;
          if (!_isConnected) {
            setState(() {
              _isConnected = true;
              _connectionStatus = "Bağlı";
            });
          }
          _handleWebSocketData(message);
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _connectionStatus = "Bağlantı Koptu";
          });
          // 3 saniye sonra tekrar bağlanmayı dene
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectToWebSocket();
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _connectionStatus = "Bağlantı Hatası";
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectToWebSocket();
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _connectionStatus = "URL Hatası";
      });
    }
  }

  void _handleWebSocketData(String jsonData) {
    if (!mounted) return;

    try {
      final data = jsonDecode(jsonData);
      final int transmitterIndex = (data['id'] as int) - 1;

      if (transmitterIndex < 0 || transmitterIndex >= _numTransmitters) return;

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
        if (mag.abs() > _outOfBoundsValue)
          newStatus = MotorStatus.outOfBounds;
        else if (mag.abs() > _warningValue)
          newStatus = MotorStatus.warning;
        else
          newStatus = MotorStatus.normal;

        if (_motorStatus[transmitterIndex] != newStatus) {
          _motorStatus[transmitterIndex] = newStatus;
        }
      });
    } catch (e) {
      // Hatalı JSON verisini görmezden gel
      // print("JSON Parse Hatası: $e");
    }
  }

  void _startDataTimer() {
    _dataTimer = Timer.periodic(Duration(milliseconds: _dataPointIntervalMs), (
      timer,
    ) {
      if (!mounted) {
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

  List<FlSpot> _getSpotsForCurrentView() {
    if (!_isConnected) return [];
    switch (_selectedDataType) {
      case DataType.x_axis:
        return _dataSpotsX[_selectedTransmitterIndex]!;
      case DataType.y_axis:
        return _dataSpotsY[_selectedTransmitterIndex]!;
      case DataType.z_axis:
        return _dataSpotsZ[_selectedTransmitterIndex]!;
      case DataType.resultant:
        return _dataSpotsResultant[_selectedTransmitterIndex]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'V${_selectedTransmitterIndex + 1} Monitör - Durum: $_connectionStatus',
        ),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
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
              style: SegmentedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A2E),
                selectedForegroundColor: Colors.cyanAccent,
                selectedBackgroundColor: Colors.blueAccent.withOpacity(0.3),
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
        ],
      ),
      body: _isConnected ? _buildGraph() : _buildConnectionPrompt(),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).primaryColor,
        child: TabBar(
          controller: _transmitterTabController,
          indicatorColor: Colors.cyanAccent,
          indicatorWeight: 3.0,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: List.generate(_numTransmitters, (index) {
            return _buildMotorTab("V${index + 1}", _motorStatus[index]!);
          }),
        ),
      ),
    );
  }

  Widget _buildGraph() {
    final double minX = max(0.0, _globalTime - _displaySeconds);
    final double maxX = max(_displaySeconds.toDouble(), _globalTime);
    List<FlSpot> spots = _getSpotsForCurrentView();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: LineChart(
        LineChartData(
          minY: -5,
          maxY: 5,
          minX: minX,
          maxX: maxX,
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
                getTitlesWidget: (v, m) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1.0,
                getTitlesWidget: (v, m) => Text(
                  v.toStringAsFixed(0),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: Colors.cyan,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }

  Widget _buildConnectionPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 24),
            Text(
              _connectionStatus,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              "Lütfen telefonunuzun Wi-Fi ayarlarından 'ESP32_Sensor_GW_AP' ağına bağlı olduğunuzdan emin olun.",
              style: TextStyle(color: Colors.white60, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

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
    return Tab(
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
              boxShadow: [
                BoxShadow(
                  color: indicatorColor.withOpacity(0.7),
                  blurRadius: 4.0,
                  spreadRadius: 1.0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

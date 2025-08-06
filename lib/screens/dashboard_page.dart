import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/settings_service.dart';

final esp32WebSocketUrl = Uri.parse('ws://192.168.4.1:81');

enum DataType { x_axis, y_axis, z_axis, resultant }

enum MotorStatus { normal, warning, outOfBounds, inactive }

class DroneDashboardPage extends StatefulWidget {
  const DroneDashboardPage({super.key});

  @override
  State<DroneDashboardPage> createState() => _DroneDashboardPageState();
}

class _DroneDashboardPageState extends State<DroneDashboardPage> {
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
  final Map<int, MotorStatus> _motorStatus = {
    for (var i = 0; i < 4; i++) i: MotorStatus.inactive,
  };
  WebSocketChannel? _channel;
  StreamSubscription? _socketSubscription;
  bool _isConnected = false;
  String _connectionStatus = "Bağlanılıyor...";
  double _globalTime = 0;
  final int _dataPointIntervalMs = 5;
  final int _displaySeconds = 5;
  Timer? _dataTimer;
  bool _isClosing = false;
  final SettingsService _settingsService = SettingsService.instance;
  int _selectedViewIndex = 0;
  late List<bool> _viewSelections;
  final Map<int, DateTime> _lastDataTime = {};
  final Duration _inactiveTimeout = const Duration(seconds: 2);
  bool _isFftView = false;
  static const int _fftSampleSize = 128;
  final Map<int, List<double>> _fftDataBuffer = {
    for (var i = 0; i < 4; i++) i: [],
  };
  final Map<int, List<FlSpot>> _fftSpots = {for (var i = 0; i < 4; i++) i: []};
  static const double _samplingRate = 50.0;

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
      _lastDataTime[transmitterIndex] = DateTime.now();
      final double ax = (data['ax'] as num).toDouble();
      final double ay = (data['ay'] as num).toDouble();
      final double az = (data['az'] as num).toDouble();
      final double mag = (data['mag'] as num).toDouble();

      // İSTEĞİNİZ ÜZERE, YERÇEKİMİ ARINDIRMA KODU KALDIRILDI.
      // Veri ham haliyle, tıpkı eski projenizdeki gibi, FFT tamponuna ekleniyor.
      final buffer = _fftDataBuffer[transmitterIndex]!;
      buffer.add(mag);

      if (buffer.length > _fftSampleSize) {
        buffer.removeAt(0);
      }
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

  void _calculateAndSetFft() {
    if (_selectedViewIndex >= 4 || !_isFftView) {
      if (_fftSpots.containsKey(_selectedViewIndex) &&
          (_fftSpots[_selectedViewIndex]?.isNotEmpty ?? false)) {
        setState(() {
          _fftSpots[_selectedViewIndex] = [];
        });
      }
      return;
    }
    final buffer = _fftDataBuffer[_selectedViewIndex]!;

    if (buffer.length < _fftSampleSize) return;

    final List<FlSpot> newFftSpots = FFT.computeRealFFTMagnitude(
      buffer,
      _samplingRate,
    );

    if (_fftSpots[_selectedViewIndex]!.length != newFftSpots.length ||
        newFftSpots.isNotEmpty) {
      setState(() {
        _fftSpots[_selectedViewIndex] = newFftSpots;
      });
    }
  }

  void _startDataTimer() {
    _dataTimer = Timer.periodic(Duration(milliseconds: _dataPointIntervalMs), (
      timer,
    ) {
      if (!mounted || _isClosing) {
        timer.cancel();
        return;
      }
      _calculateAndSetFft();
      final now = DateTime.now();
      for (int i = 0; i < _numTransmitters; i++) {
        if (_lastDataTime.containsKey(i) &&
            now.difference(_lastDataTime[i]!) > _inactiveTimeout &&
            _motorStatus[i] != MotorStatus.inactive) {
          setState(() {
            _motorStatus[i] = MotorStatus.inactive;
          });
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
      });
    });
  }

  String _getAppBarTitle() {
    String baseTitle;
    if (_selectedViewIndex < 4) {
      String status = _motorStatus[_selectedViewIndex] == MotorStatus.inactive
          ? "Pasif"
          : "Veri Alınıyor";
      baseTitle = 'V${_selectedViewIndex + 1} Monitör - $status';
    } else {
      baseTitle = 'Tüm Vericiler - Bileşke Grafik';
    }
    return _isFftView ? '$baseTitle (FFT)' : baseTitle;
  }

  void _handleViewSelection(int index) {
    setState(() {
      if (index == 4) {
        _isFftView = false;
      }
      _selectedViewIndex = index;
      for (int i = 0; i < _viewSelections.length; i++) {
        _viewSelections[i] = (i == index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isAllView = _selectedViewIndex == 4;
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          if (!isAllView)
            IconButton(
              icon: Icon(_isFftView ? Icons.show_chart : Icons.ssid_chart),
              tooltip: _isFftView
                  ? 'Zaman Grafiğini Göster'
                  : 'FFT Grafiğini Göster',
              onPressed: () {
                setState(() {
                  _isFftView = !_isFftView;
                });
              },
            ),
          if (!isAllView && !_isFftView)
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
      body: _isConnected
          ? (_isFftView ? _buildFftGraph() : _buildGraph())
          : _buildConnectionPrompt(),
      bottomNavigationBar: _buildViewSelector(),
    );
  }

  Widget _buildFftGraph() {
    if (_selectedViewIndex >= 4)
      return const Center(
        child: Text("FFT analizi sadece tekil sensörler için geçerlidir."),
      );
    final List<FlSpot> spots = _fftSpots[_selectedViewIndex] ?? [];
    double maxY = 0;
    if (spots.isNotEmpty) {
      maxY = spots.map((spot) => spot.y).reduce(max);
    }
    maxY = max(0.5, maxY * 1.2);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: _samplingRate / 2,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              color: _settingsService.transmitterColors[_selectedViewIndex],
              barWidth: 2,
              isCurved: false,
              dotData: const FlDotData(show: false),
            ),
          ],
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
                reservedSize: 45,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(2)),
              ),
              axisNameWidget: const Text("Genlik"),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 5,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0)),
              ),
              axisNameWidget: const Text("Frekans (Hz)"),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: true),
        ),
        duration: const Duration(milliseconds: 0),
      ),
    );
  }

  Widget _buildViewSelector() {
    final int buttonCount = _isFftView ? 4 : 5;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      color: Theme.of(context).primaryColor,
      child: Row(
        children: List.generate(buttonCount, (index) {
          bool isSelected = _viewSelections[index];
          if (index < 4) {
            final Color borderColor = _settingsService.transmitterColors[index];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: OutlinedButton(
                  onPressed: () => _handleViewSelection(index),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: isSelected
                        ? Colors.cyan.withOpacity(0.2)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.cyanAccent : borderColor,
                      width: isSelected ? 2.5 : 2.0,
                    ),
                  ),
                  child: _buildMotorTab("V${index + 1}", _motorStatus[index]!),
                ),
              ),
            );
          } else {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: OutlinedButton(
                  onPressed: () => _handleViewSelection(index),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: isSelected
                        ? Colors.cyan.withOpacity(0.2)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    side: BorderSide(
                      color: isSelected ? Colors.cyanAccent : Colors.white24,
                      width: isSelected ? 2.5 : 2.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      "ALL",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.cyanAccent : Colors.white70,
                      ),
                    ),
                  ),
                ),
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
        if (_motorStatus[i] != MotorStatus.inactive) {
          lines.add(
            LineChartBarData(
              spots: _dataSpotsResultant[i]!
                  .map((spot) => FlSpot(spot.x, spot.y.abs()))
                  .toList(),
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
          spots: spots.map((spot) => FlSpot(spot.x, spot.y.abs())).toList(),
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
          minY: 0,
          maxY: 10,
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
                interval: 2.0,
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

  Widget _buildConnectionPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(_connectionStatus),
        ],
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
      case MotorStatus.inactive:
        indicatorColor = Colors.grey[600]!;
        break;
    }
    final bool isCurrentlySelected =
        _viewSelections.length > _selectedViewIndex &&
        _viewSelections[_selectedViewIndex] &&
        title == "V${_selectedViewIndex + 1}";
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isCurrentlySelected ? Colors.cyanAccent : Colors.white70,
            ),
          ),
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

// --- ESKİ ÇALIŞAN KODUNUZDAN ALINAN FFT VE COMPLEX SINIFLARI ---
class Complex {
  double real;
  double imag;

  Complex(this.real, this.imag);

  double abs() {
    return sqrt(real * real + imag * imag);
  }

  Complex operator +(Complex other) {
    return Complex(real + other.real, imag + other.imag);
  }

  Complex operator -(Complex other) {
    return Complex(real - other.real, imag - other.imag);
  }

  Complex operator *(Complex other) {
    return Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real,
    );
  }
}

class FFT {
  static List<Complex> fft(List<Complex> x, bool inverse) {
    int n = x.length;
    if (n == 1) return [x[0]];
    if ((n & (n - 1)) != 0) {
      // FFT size'ı 2'nin kuvveti değilse, hata fırlatmak yerine boş liste dönebiliriz.
      // Bu, uygulamanın çökmesini engeller.
      print("FFT Error: Sample size is not a power of 2. Size: $n");
      return List.filled(n, Complex(0, 0));
    }
    List<Complex> even = [];
    List<Complex> odd = [];
    for (int i = 0; i < n ~/ 2; i++) {
      even.add(x[2 * i]);
      odd.add(x[2 * i + 1]);
    }
    List<Complex> q = fft(even, inverse);
    List<Complex> r = fft(odd, inverse);
    List<Complex> y = List.filled(n, Complex(0, 0));
    for (int k = 0; k < n ~/ 2; k++) {
      double kth = -2 * pi * k / n;
      if (inverse) kth = -kth;
      Complex wk = Complex(cos(kth), sin(kth));
      Complex term = wk * r[k];
      y[k] = q[k] + term;
      y[k + n ~/ 2] = q[k] - term;
    }
    if (inverse) {
      for (int i = 0; i < n; i++) {
        y[i] = Complex(y[i].real / 2, y[i].imag / 2);
      }
    }
    return y;
  }

  static List<FlSpot> computeRealFFTMagnitude(
    List<double> realData,
    double sampleRate,
  ) {
    int n = realData.length;
    if (n == 0) return [];

    // Veri setini 2'nin en yakın kuvvetine pedleme
    int fftSize = 1;
    while (fftSize < n) {
      fftSize <<= 1;
    }

    List<Complex> complexInput = List.generate(
      fftSize,
      (i) => i < n ? Complex(realData[i], 0.0) : Complex(0.0, 0.0),
    );

    List<Complex> result = fft(complexInput, false);

    List<FlSpot> fftSpots = [];
    // Sonucun sadece ilk yarısını alıyoruz (Nyquist teoremi)
    for (int i = 0; i <= fftSize ~/ 2; i++) {
      // Normalizasyon: Örnek sayısına bölme
      double magnitude = result[i].abs() / n;

      // DC (0 Hz) ve Nyquist frekansı hariç diğerlerini 2 ile çarp
      if (i > 0 && i < fftSize / 2) {
        magnitude *= 2;
      }

      double frequency = i * (sampleRate / fftSize);
      fftSpots.add(FlSpot(frequency, magnitude));
    }
    return fftSpots;
  }
}

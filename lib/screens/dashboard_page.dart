// lib/dashboard_page.dart dosyasının tam ve güncel hali

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import '../models/recorded_session.dart';
import '../services/settings_service.dart';
import 'home_page.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

enum DataType { x_axis, y_axis, z_axis, resultant }
enum MotorStatus { normal, warning, outOfBounds, inactive }

class DroneDashboardPage extends StatefulWidget {
  final DashboardArguments args;
  const DroneDashboardPage({super.key, required this.args});

  @override
  State<DroneDashboardPage> createState() => _DroneDashboardPageState();
}

class _DroneDashboardPageState extends State<DroneDashboardPage> {
  // DEĞİŞTİ: Motor sayısı 6'ya çıkarıldı.
  static const int motorCount = 6;

  DataType _selectedDataType = DataType.resultant;
  final Map<int, List<FlSpot>> _dataSpotsX = {
    for (var i = 0; i < motorCount; i++) i: [],
  };
  final Map<int, List<FlSpot>> _dataSpotsY = {
    for (var i = 0; i < motorCount; i++) i: [],
  };
  final Map<int, List<FlSpot>> _dataSpotsZ = {
    for (var i = 0; i < motorCount; i++) i: [],
  };
  final Map<int, List<FlSpot>> _dataSpotsResultant = {
    for (var i = 0; i < motorCount; i++) i: [],
  };

  late Map<int, MotorStatus> _motorStatus;
  StreamSubscription? _dataSubscription;
  double _globalTime = 0;
  final int _dataPointIntervalMs = 30;
  final int _displaySeconds = 4;
  Timer? _guiTimer;
  final SettingsService _settingsService = SettingsService.instance;
  int _selectedViewIndex = 0;
  late List<bool> _viewSelections;

  bool _isFftView = false;
  static const int _fftSampleSize = 128;
  final Map<int, List<double>> _fftDataBuffer = {
    for (var i = 0; i < motorCount; i++) i: [],
  };
  final Map<int, List<FlSpot>> _fftSpots = {for (var i = 0; i < motorCount; i++) i: []};
  static const double _samplingRate = 50.0;

  bool _isRecording = false;
  bool _sessionSaveProcessStarted = false;
  final Map<int, List<FlSpot>> _recordedSpotsResultant = {
    for (var i = 0; i < motorCount; i++) i: [],
  };

  bool _isDroneView = false;

  @override
  void initState() {
    super.initState();
    _viewSelections = List.generate(motorCount + 1, (index) => index == 0);
    _motorStatus = Map.from(widget.args.initialMotorStatus);
    _dataSubscription = widget.args.dataStream.listen(_handleData);
    _startGuiTimer();
    _startRecording();
  }

  @override
  void dispose() {
    if (_isRecording && !_sessionSaveProcessStarted) {
      _sessionSaveProcessStarted = true;
      final contextForDialog = context;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && contextForDialog.mounted) {
          _stopAndPromptSave(contextForDialog);
        }
      });
    }
    _dataSubscription?.cancel();
    _guiTimer?.cancel();
    super.dispose();
  }
  
  void _handleData(Map<String, dynamic> data) {
    if (!mounted) return;
    if (data.containsKey('empty') && data['empty'] == true) return;
    if (!data.containsKey('id')) return;
    final int transmitterIndex = (data['id'] as int) - 1;
    if (transmitterIndex < 0 || transmitterIndex >= motorCount) return;
    final double ax = (data['ax'] as num).toDouble();
    final double ay = (data['ay'] as num).toDouble();
    final double az = (data['az'] as num).toDouble();
    final double mag = (data['mag'] as num).toDouble();
    final buffer = _fftDataBuffer[transmitterIndex]!;
    buffer.add(mag);
    if (buffer.length > _fftSampleSize) {
      buffer.removeAt(0);
    }
    _dataSpotsX[transmitterIndex]!.add(FlSpot(_globalTime, ax));
    _dataSpotsY[transmitterIndex]!.add(FlSpot(_globalTime, ay));
    _dataSpotsZ[transmitterIndex]!.add(FlSpot(_globalTime, az));
    _dataSpotsResultant[transmitterIndex]!.add(FlSpot(_globalTime, mag));
    if (_isRecording) {
      _recordedSpotsResultant[transmitterIndex]!
          .add(FlSpot(_globalTime, mag));
    }
    MotorStatus newStatus;
    if (mag.abs() > _settingsService.errorThreshold)
      newStatus = MotorStatus.outOfBounds;
    else if (mag.abs() > _settingsService.warningThreshold)
      newStatus = MotorStatus.warning;
    else
      newStatus = MotorStatus.normal;
    if (_motorStatus[transmitterIndex] != newStatus) {
      setState(() {
        _motorStatus[transmitterIndex] = newStatus;
      });
    }
  }

  void _startGuiTimer() {
    _guiTimer =
        Timer.periodic(Duration(milliseconds: _dataPointIntervalMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _calculateAndSetFft();
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
            list.removeWhere(
                (spot) => spot.x < _globalTime - _displaySeconds);
          }
        }
      });
    });
  }

  void _startRecording() {
    if (_isRecording) return;
    setState(() {
      _isRecording = true;
      _sessionSaveProcessStarted = false;
      for (var key in _recordedSpotsResultant.keys) {
        _recordedSpotsResultant[key]!.clear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.dataRecordingStarted),
            backgroundColor: Colors.blueAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _stopAndPromptSave(BuildContext dialogContext) async {
    if (!_isRecording || _sessionSaveProcessStarted) return;
    _sessionSaveProcessStarted = true;
    setState(() => _isRecording = false);
    final bool hasDataToSave =
        _recordedSpotsResultant.values.any((list) => list.isNotEmpty);
    if (!hasDataToSave) {
      if (mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
          const SnackBar(
            content: Text('Kayıt durduruldu. Kaydedilecek veri yok.'),
          ),
        );
      }
      return;
    }

    final l10n = AppLocalizations.of(dialogContext)!;
    final bool? shouldSave = await showDialog<bool>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.saveSessionDialogTitle),
        content: Text(l10n.saveSessionDialogContent),
        actions: [
          TextButton(
            child: Text(l10n.dontSaveButton),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ElevatedButton(
            child: Text(l10n.saveButton),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (shouldSave == true) {
      await _saveSessionToFile(dialogContext);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(dialogContext).showSnackBar(
            SnackBar(content: Text(l10n.sessionNotSaved)));
      }
    }
  }

  Future<void> _saveSessionToFile(BuildContext scaffoldContext) async {
    final l10n = AppLocalizations.of(scaffoldContext)!;
    try {
      final session = RecordedSession(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        productCode: widget.args.productCode,
        timestamp: DateTime.now(),
        v1Data: List.from(_recordedSpotsResultant[0]!),
        v2Data: List.from(_recordedSpotsResultant[1]!),
        v3Data: List.from(_recordedSpotsResultant[2]!),
        v4Data: List.from(_recordedSpotsResultant[3]!),
        v5Data: List.from(_recordedSpotsResultant[4]!),
        v6Data: List.from(_recordedSpotsResultant[5]!),
      );
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'session_${session.id}.json';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(jsonEncode(session.toJson()));

      if (mounted) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(content: Text(l10n.sessionSavedSuccessfully(fileName))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(scaffoldContext).showSnackBar(
          SnackBar(content: Text(l10n.errorSavingSession(e.toString()))),
        );
      }
    }
  }

  void _calculateAndSetFft() {
    if (_selectedViewIndex >= motorCount || !_isFftView) {
      if (_fftSpots.containsKey(_selectedViewIndex) &&
          (_fftSpots[_selectedViewIndex]?.isNotEmpty ?? false)) {
        setState(() => _fftSpots[_selectedViewIndex] = []);
      }
      return;
    }
    final buffer = _fftDataBuffer[_selectedViewIndex]!;
    if (buffer.length < _fftSampleSize) return;
    final List<FlSpot> newFftSpots =
        FFT.computeRealFFTMagnitude(buffer, _samplingRate);
    if (!mounted) return;
    if (_fftSpots[_selectedViewIndex]!.length != newFftSpots.length ||
        newFftSpots.isNotEmpty) {
      setState(() => _fftSpots[_selectedViewIndex] = newFftSpots);
    }
  }

  String _getAppBarTitle(AppLocalizations l10n) {
    if (_isDroneView) {
      return l10n.dashboardAppBarTitleAllMotors;
    }
    String baseTitle = (_selectedViewIndex < motorCount)
        ? l10n.dashboardAppBarTitleMotor(_selectedViewIndex + 1)
        : l10n.dashboardAppBarTitleAllMotors;
    return _isFftView ? '$baseTitle ${l10n.dashboardAppBarTitleFFT}' : baseTitle;
  }

  void _handleViewSelection(int index) {
    setState(() {
      if (index == motorCount) _isFftView = false;
      _selectedViewIndex = index;
      for (int i = 0; i < _viewSelections.length; i++) {
        _viewSelections[i] = (i == index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    bool isAllView = _selectedViewIndex == motorCount;
    bool showSegmentedButton = !isAllView && !_isFftView && !_isDroneView;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_isRecording)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 1.0, end: 0.5),
                  duration: const Duration(milliseconds: 700),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: const Icon(
                      Icons.circle,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                  ),
                  onEnd: () {
                    if (mounted && _isRecording) setState(() {});
                  },
                ),
              ),
            Text(_getAppBarTitle(l10n)),
          ],
        ),
         backgroundColor: Theme.of(context).primaryColor,
        actions: [
          if (!_isFftView)
            IconButton(
              icon: Icon(_isDroneView ? Icons.show_chart_rounded : Icons.view_in_ar_outlined),
              tooltip: _isDroneView ? "Grafik Görünümü" : "Drone Görünümü",
              onPressed: () {
                setState(() {
                  _isDroneView = !_isDroneView;
                  if (_isDroneView) {
                    _isFftView = false;
                    _handleViewSelection(motorCount);
                }
              });
            },
          ),
          if (_isRecording)
            IconButton(
              icon: const Icon(
                Icons.stop_circle_outlined,
                color: Colors.redAccent,
              ),
              tooltip: l10n.stopRecordingTooltip,
              onPressed: () {
                if (!_sessionSaveProcessStarted) _stopAndPromptSave(context);
              },
            ),
          if (!isAllView && !_isDroneView)
            IconButton(
              icon: Icon(_isFftView ? Icons.show_chart : Icons.ssid_chart),
              tooltip: _isFftView
                  ? l10n.showTimeGraphTooltip
                  : l10n.showFFTGraphTooltip,
              onPressed: () => setState(() => _isFftView = !_isFftView),
            ),
        ],
        bottom: showSegmentedButton
            ? PreferredSize(
                preferredSize: const Size.fromHeight(56.0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Center(
                    child: Container(
                      height: 42,
                      width: 280,
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Row(
                        children: [
                          _buildSegmentedButton(DataType.x_axis, 'X'),
                          _buildSegmentedButton(DataType.y_axis, 'Y'),
                          _buildSegmentedButton(DataType.z_axis, 'Z'),
                          _buildSegmentedButton(DataType.resultant, 'Mag'),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: _isDroneView
          ? _buildHexagonDroneVisual()
          : (_isFftView ? _buildFftGraph(l10n) : _buildGraph(l10n)),
      bottomNavigationBar: _buildViewSelector(l10n),
    );
  }
  
// RESPONSIVE ALTIGEN DRONE GÖRSELİ - Tüm ekran boyutlarına uyum sağlar
Widget _buildHexagonDroneVisual() {
  return LayoutBuilder(
    builder: (context, constraints) {
      // Ekran boyutuna göre dinamik boyutları hesapla
      final double screenWidth = MediaQuery.of(context).size.width;
      final double screenHeight = MediaQuery.of(context).size.height;
      final double availableSize = math.min(constraints.maxWidth, constraints.maxHeight);
      
      // Responsive boyutlar - ekran boyutuna göre otomatik ayarlama
      final double containerSize = (availableSize * 0.85).clamp(280.0, 450.0);
      final double motorPodSize = (containerSize * 0.17).clamp(45.0, 75.0);
      final double centerBodySize = (containerSize * 0.23).clamp(60.0, 100.0);
      final double armWidth = (containerSize * 0.035).clamp(10.0, 18.0);
      final double armLength = (containerSize * 0.55).clamp(120.0, 190.0);
      final double labelFontSize = (containerSize * 0.035).clamp(10.0, 16.0);
      
      // 6 motorun TAM SİMETRİK açıları (derece cinsinden)
      final List<double> angles = [0, 60, 120, 180, 240, 300];
      
      // 6 motorun etiketleri
      final List<String> labels = ['M1', 'M2', 'M3', 'M4', 'M5', 'M6'];
      
      return Center(
        child: Container(
          width: containerSize,
          height: containerSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. ADIM: Kolları TAM SİMETRİK olarak çiz
              ...List.generate(6, (i) {
                return Transform.rotate(
                  angle: angles[i] * (pi / 180),
                  child: Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: armLength,
                      height: armWidth,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3A3A),
                        borderRadius: BorderRadius.circular(armWidth * 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: armWidth * 0.3,
                            offset: Offset(0, armWidth * 0.15),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              // 2. ADIM: Motorları kolların ucuna TAM SİMETRİK olarak yerleştir
              ...List.generate(6, (i) {
                final double angle = angles[i] * (pi / 180);
                final double motorDistance = armLength / 2 + motorPodSize / 2 - (containerSize * 0.025);
                final double x = math.cos(angle) * motorDistance;
                final double y = math.sin(angle) * motorDistance;
                
                return Transform.translate(
                  offset: Offset(x, y),
                  child: _buildResponsiveMotorPod(
                    i, 
                    labels[i], 
                    motorPodSize, 
                    labelFontSize
                  ),
                );
              }),

              // 3. ADIM: Merkezi gövdeyi en üste çiz
              Container(
                width: centerBodySize,
                height: centerBodySize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade800,
                  gradient: RadialGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade900],
                    stops: const [0.3, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: centerBodySize * 0.2,
                      spreadRadius: centerBodySize * 0.04,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: centerBodySize * 0.25,
                    height: centerBodySize * 0.25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade700,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// RESPONSIVE motor yuvasını çizen yardımcı widget
Widget _buildResponsiveMotorPod(int motorIndex, String label, double motorSize, double fontSize) {
  final status = _motorStatus[motorIndex] ?? MotorStatus.inactive;
  Color indicatorColor;
  switch (status) {
    case MotorStatus.normal:      indicatorColor = Colors.greenAccent; break;
    case MotorStatus.warning:     indicatorColor = Colors.yellowAccent; break;
    case MotorStatus.outOfBounds: indicatorColor = Colors.redAccent; break;
    case MotorStatus.inactive:    indicatorColor = Colors.grey.shade600; break;
  }

  return GestureDetector(
    onTap: () {
      setState(() {
        _isDroneView = false;
        _handleViewSelection(motorIndex);
      });
    },
    child: Container(
      width: motorSize * 1.4,
      height: motorSize * 1.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Motor yuvası
          Container(
            width: motorSize,
            height: motorSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2A2A2A),
              border: Border.all(
                color: Colors.black.withOpacity(0.6), 
                width: motorSize * 0.03
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: motorSize * 0.15,
                  offset: Offset(0, motorSize * 0.03),
                ),
              ],
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: motorSize * 0.8,
                height: motorSize * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: indicatorColor,
                  boxShadow: [
                    if (status != MotorStatus.inactive)
                      BoxShadow(
                        color: indicatorColor.withOpacity(0.7),
                        blurRadius: motorSize * 0.35,
                        spreadRadius: motorSize * 0.035,
                      ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: motorSize * 0.2,
                    height: motorSize * 0.2,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Motor etiketi - responsive pozisyonlama
          Positioned(
            bottom: -fontSize * 0.5,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: fontSize * 0.5, 
                vertical: fontSize * 0.15
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(fontSize * 0.6),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: fontSize,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  Widget _buildSegmentedButton(DataType type, String label) {
    bool isSelected = _selectedDataType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDataType = type),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BCD4) : Colors.transparent,
            borderRadius: BorderRadius.circular(25.0),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.black : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFftGraph(AppLocalizations l10n) {
    if (_selectedViewIndex >= motorCount)
      return Center(
        child: Text(l10n.fftAnalysisNotAvailableForAll),
      );
    final List<FlSpot> spots = _fftSpots[_selectedViewIndex] ?? [];
    double maxY = 0;
    if (spots.isNotEmpty) maxY = spots.map((spot) => spot.y).reduce(max);
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
              axisNameWidget: Text(l10n.fftAmplitude),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 5,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0)),
              ),
              axisNameWidget: Text(l10n.fftFrequency),
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
  
Widget _buildViewSelector(AppLocalizations l10n) {
  // Bu bölüm aynı kalıyor
  final int buttonCount = (_isFftView && !_isDroneView) ? motorCount : motorCount + 1;
  
  // YENİ YAPI:
  // Butonlar ve altındaki çizgileri dikeyde hizalamak için her birini Column içine alacağız.
  // bottomNavigationBar'ın rengini ve padding'ini ayarlayalım.
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
    color: Theme.of(context).primaryColor, // Arka plan rengi
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, // Column'ların tepeden başlamasını sağlar
      children: List.generate(buttonCount, (index) {
        bool isSelected = _isDroneView ? (index == motorCount) : _viewSelections[index];

        // M1'den M6'ya kadar olan motor butonları
        if (index < motorCount) {
          // Her motorun kendi rengini alıyoruz
          final Color motorColor = _settingsService.transmitterColors[index];
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              // GestureDetector ile tüm alana tıklama özelliği veriyoruz
              child: GestureDetector(
                onTap: () {
                  if (_isDroneView) setState(() => _isDroneView = false);
                  _handleViewSelection(index);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Column'un dikeyde minimum yer kaplamasını sağlar
                  children: [
                    // 1. Üst Kısım: Butonun kendisi (çerçeveli kutu)
                    Container(
                      width: double.infinity, // Genişliği doldur
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.cyan.withOpacity(0.2) : Colors.transparent,
                        // Çiziminizdeki gibi standart bir çerçeve
                        border: Border.all(
                          color: isSelected ? Colors.cyanAccent : Colors.grey.shade700,
                          width: isSelected ? 2.0 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      // Butonun içindeki "M1" yazısı ve durum noktası
                      child: _buildMotorTab("M${index + 1}", _motorStatus[index]!),
                    ),
                    // Buton ile çizgi arasına boşluk
                    const SizedBox(height: 5.0),
                    // 2. Alt Kısım: Renkli Çizgi
                    Container(
                      height: 3.5,
                      width: 30, // Çizgi genişliği
                      decoration: BoxDecoration(
                        color: motorColor, // Her motorun kendi rengi
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } 
        // "ALL" butonu
        else {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: GestureDetector(
                onTap: () {
                  if (_isDroneView) setState(() => _isDroneView = false);
                  _handleViewSelection(index);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. Üst Kısım: ALL Butonu
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.cyan.withOpacity(0.2) : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? Colors.cyanAccent : Colors.grey.shade700,
                          width: isSelected ? 2.0 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.allButton.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.cyanAccent : Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    // Buton ile çizgi arasına boşluk
                    const SizedBox(height: 5.0),
                    // 2. Alt Kısım: ALL butonunun altında çizgi olmayacağı için boş bir alan bırakıyoruz
                    // Bu, diğer butonlarla hizalamanın bozulmamasını sağlar.
                    Container(
                      height: 3.5,
                      width: 30,
                      color: Colors.transparent, // Görünmez çizgi
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      }),
    ),
  );
}

// DEĞİŞTİRİLDİ: FittedBox ile içeriğin butona sığması sağlandı.
Widget _buildMotorTab(String title, MotorStatus status) {
  Color indicatorColor;
  switch (status) {
    case MotorStatus.normal: indicatorColor = Colors.greenAccent; break;
    case MotorStatus.warning: indicatorColor = Colors.yellowAccent; break;
    case MotorStatus.outOfBounds: indicatorColor = Colors.redAccent; break;
    case MotorStatus.inactive: indicatorColor = Colors.grey[600]!; break;
  }
  final bool isCurrentlySelected = _isDroneView
      ? false
      : (_viewSelections.length > _selectedViewIndex &&
          _viewSelections[_selectedViewIndex] &&
          title == "M${_selectedViewIndex + 1}");

  // FittedBox, içindeki Row'un kendisine ayrılan alana sığacak şekilde küçülmesini sağlar.
  return FittedBox(
    fit: BoxFit.scaleDown, // Oranları koruyarak küçült
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: isCurrentlySelected ? Colors.cyanAccent : Colors.white70,
          ),
        ),
        const SizedBox(width: 4), // Boşluğu biraz azalttık
        Container(
          width: 8, // İkonu biraz azalttık
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: indicatorColor),
        ),
      ],
    ),
  );
}
  
  Widget _buildGraph(AppLocalizations l10n) {
    final double minX = max(0.0, _globalTime - _displaySeconds);
    final double maxX = max(_displaySeconds.toDouble(), _globalTime);
    List<LineChartBarData> lines = [];
    if (_selectedViewIndex == motorCount) {
      for (int i = 0; i < motorCount; i++) {
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
        case DataType.x_axis: spots = _dataSpotsX[_selectedViewIndex]!; break;
        case DataType.y_axis: spots = _dataSpotsY[_selectedViewIndex]!; break;
        case DataType.z_axis: spots = _dataSpotsZ[_selectedViewIndex]!; break;
        case DataType.resultant: spots = _dataSpotsResultant[_selectedViewIndex]!; break;
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
          maxY: 20,
          minX: minX,
          maxX: maxX,
          lineBarsData: lines,
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: _settingsService.warningThreshold,
                color: Colors.yellowAccent.withOpacity(0.8),
                strokeWidth: 1.5,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 2),
                  style: TextStyle(color: Colors.yellowAccent.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.bold),
                  labelResolver: (line) => l10n.warningThresholdLabel,
                ),
              ),
              HorizontalLine(
                y: _settingsService.errorThreshold,
                color: Colors.redAccent.withOpacity(0.8),
                strokeWidth: 1.5,
                dashArray: [5, 5],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 2),
                  style: TextStyle(color: Colors.redAccent.withOpacity(0.9), fontSize: 10, fontWeight: FontWeight.bold),
                  labelResolver: (line) => l10n.errorThresholdLabel,
                ),
              ),
            ],
          ),
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (value) =>
                const FlLine(color: Colors.white10, strokeWidth: 0.5),
            getDrawingVerticalLine: (value) =>
                const FlLine(color: Colors.white10, strokeWidth: 0.5),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 4.0, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, interval: 1.0, getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0)))),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
        ),
        duration: Duration.zero,
      ),
    );
  }
}

// FFT sınıfları aynı kalıyor
class Complex {
  double real;
  double imag;
  Complex(this.real, this.imag);
  double abs() => sqrt(real * real + imag * imag);
  Complex operator +(Complex other) => Complex(real + other.real, imag + other.imag);
  Complex operator -(Complex other) => Complex(real - other.real, imag - other.imag);
  Complex operator *(Complex other) => Complex(real * other.real - imag * other.imag, real * other.imag + imag * other.real);
}

class FFT {
  static List<Complex> fft(List<Complex> x, bool inverse) {
    int n = x.length;
    if (n == 1) return [x[0]];
    if ((n & (n - 1)) != 0) {
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

  static List<FlSpot> computeRealFFTMagnitude(List<double> realData, double sampleRate) {
    int n = realData.length;
    if (n == 0) return [];
    int fftSize = 1;
    while (fftSize < n) {
      fftSize <<= 1;
    }
    List<Complex> complexInput = List.generate(fftSize, (i) => i < n ? Complex(realData[i], 0.0) : Complex(0.0, 0.0));
    List<Complex> result = fft(complexInput, false);
    List<FlSpot> fftSpots = [];
    for (int i = 0; i <= fftSize ~/ 2; i++) {
      double magnitude = result[i].abs() / n;
      if (i > 0 && i < fftSize / 2) {
        magnitude *= 2;
      }
      double frequency = i * (sampleRate / fftSize);
      fftSpots.add(FlSpot(frequency, magnitude));
    }
    return fftSpots;
  }
}
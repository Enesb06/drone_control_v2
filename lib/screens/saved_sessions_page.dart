// lib/screens/saved_sessions_page.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recorded_session.dart';
import 'view_session_page.dart'; // Bu sayfayı birazdan oluşturacağız

class SavedSessionsPage extends StatefulWidget {
  const SavedSessionsPage({super.key});

  @override
  State<SavedSessionsPage> createState() => _SavedSessionsPageState();
}

class _SavedSessionsPageState extends State<SavedSessionsPage> {
  List<RecordedSession> _savedSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedSessions();
  }

  Future<void> _loadSavedSessions() async {
    setState(() => _isLoading = true);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.json'),
      );

      List<RecordedSession> loadedSessions = [];
      for (var file in files) {
        try {
          final jsonString = await file.readAsString();
          final jsonMap = jsonDecode(jsonString);
          if (jsonMap.containsKey('id') && jsonMap.containsKey('timestamp')) {
            loadedSessions.add(RecordedSession.fromJson(jsonMap));
          }
        } catch (e) {
          print('Oturum yüklenirken hata oluştu ${file.path}: $e');
        }
      }

      loadedSessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _savedSessions = loadedSessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kayıtlar yüklenemedi: $e')));
      }
    }
  }

  Future<void> _deleteSession(RecordedSession session) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Oturumu Sil'),
        content: const Text(
          'Bu oturumu kalıcı olarak silmek istediğinizden emin misiniz?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'session_${session.id}.json';
      final file = File('${directory.path}/$fileName');

      if (await file.exists()) {
        await file.delete();
        setState(() {
          _savedSessions.removeWhere((s) => s.id == session.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Oturum başarıyla silindi.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Oturum silinirken hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıtlı Oturumlar'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedSessions,
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedSessions.isEmpty
          ? const Center(child: Text('Henüz kaydedilmiş bir oturum yok.'))
          : ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _savedSessions.length,
              itemBuilder: (context, index) {
                final session = _savedSessions[index];
                final formattedDate = DateFormat(
                  'dd.MM.yyyy HH:mm:ss',
                ).format(session.timestamp.toLocal());
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.analytics_outlined,
                      color: Colors.cyanAccent,
                    ),
                    title: Text('Oturum: $formattedDate'),
                    subtitle: Text(
                      'Veri Sayısı (V1): ${session.v1Data.length}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => _deleteSession(session),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ViewSessionPage(session: session),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

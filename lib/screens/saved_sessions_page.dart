import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/recorded_session.dart';
import 'view_session_page.dart';
import 'package:drone_control_v2/l10n/app_localizations.dart';

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
      final files = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'));

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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kayıtlar yüklenemedi: $e')));
      }
    }
  }

  Future<void> _deleteSession(RecordedSession session) async {
    final l10n = AppLocalizations.of(context)!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.deleteSessionDialogTitle),
        content: Text(l10n.deleteSessionDialogContent),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteButton, style: const TextStyle(color: Colors.redAccent)),
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
            SnackBar(content: Text(l10n.sessionDeletedSuccessfully)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Oturum silinirken hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.savedSessionsPageTitle),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedSessions,
            tooltip: l10n.refreshButton,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedSessions.isEmpty
              ? Center(child: Text(l10n.noSavedSessions))
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _savedSessions.length,
                  itemBuilder: (context, index) {
                    final session = _savedSessions[index];
                    final locale = Localizations.localeOf(context).toString();
                    final formattedDate = DateFormat(
                      'dd.MM.yyyy HH:mm:ss', locale
                    ).format(session.timestamp.toLocal());

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      child: ListTile(
                        leading: const Icon(Icons.analytics_outlined, color: Colors.cyanAccent),
                        title: Text(l10n.productIdLabel(session.productCode)),
                        subtitle: Text(l10n.dateLabel(formattedDate)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
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
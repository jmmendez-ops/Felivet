import 'dart:io';

import 'package:flutter/material.dart';

import '../models/triage_models.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  final List<TriageResult> history;
  final Future<void> Function(TriageResult entry) onDelete;
  final Future<void> Function() onClearAll;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onDelete,
    required this.onClearAll,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<TriageResult> _items;

  @override
  void initState() {
    super.initState();
    _items = List<TriageResult>.from(widget.history);
  }

  Future<void> _confirmDelete(TriageResult entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this analysis?'),
        content: const Text(
          'This will permanently remove this entry from your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _items.remove(entry));
      await widget.onDelete(entry);
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all history?'),
        content: const Text(
          'This will permanently remove every saved analysis. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() => _items = []);
      await widget.onClearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear all',
              onPressed: _confirmClearAll,
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No saved analyses yet',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final r = _items[i];
                return Dismissible(
                  key: ValueKey(r.timestamp.toIso8601String() + i.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(r);
                    return !_items.contains(r);
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: r.image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                r.image!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Text(
                                  r.urgency.icon,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            )
                          : Text(
                              r.urgency.icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                      title: Text(r.detectedDisease ?? 'No disease detected'),
                      subtitle: Text(
                        '${r.urgency.label} · ${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.grey,
                        ),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(r),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(
                            result: r,
                            history: _items,
                            onDeleteHistoryEntry: widget.onDelete,
                            onClearHistory: widget.onClearAll,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

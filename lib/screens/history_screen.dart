import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/sound_utils.dart';
import '../core/ui_tokens.dart';
import '../models/triage_models.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  final List<TriageResult> history;
  final Future<void> Function(TriageResult entry) onDelete;
  final Future<void> Function() onClearAll;
  final Future<void> Function() onRefresh;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onDelete,
    required this.onClearAll,
    required this.onRefresh,
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

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.history, widget.history)) {
      _items = List<TriageResult>.from(widget.history);
    }
  }

  Future<void> _confirmDelete(TriageResult entry) async {
    AppSounds.playTap();
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
    AppSounds.playTap();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh history',
            onPressed: () async {
              AppSounds.playTap();
              final messenger = ScaffoldMessenger.of(context);
              await widget.onRefresh();
              if (!mounted) return;
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('History refreshed'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
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
              child: Container(
                margin: const EdgeInsets.all(FeliVetUi.spaceXl),
                padding: const EdgeInsets.all(FeliVetUi.spaceXl),
                decoration: FeliVetUi.emptyState(context),
                child: CustomPaint(
                  foregroundPainter: DashedBorderPainter(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    radius: FeliVetUi.cardRadius,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                        decoration: FeliVetUi.iconBadge(context),
                        child: Icon(
                          Icons.history_rounded,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: FeliVetUi.spaceMd),
                      Text(
                        'No saved analyses yet',
                        style: FeliVetUi.muted(context, size: 15),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(FeliVetUi.spaceLg),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final r = _items[i];
                return Dismissible(
                  key: ValueKey(r.timestamp.toIso8601String() + i.toString()),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: FeliVetUi.spaceXl,
                    ),
                    margin: const EdgeInsets.only(bottom: FeliVetUi.spaceMd),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(FeliVetUi.cardRadius),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(r);
                    return !_items.contains(r);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: FeliVetUi.spaceMd),
                    padding: const EdgeInsets.all(FeliVetUi.spaceMd),
                    decoration: FeliVetUi.cardDecoration(context),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(FeliVetUi.cardRadius),
                      onTap: () {
                        AppSounds.playTap();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ResultScreen(
                              result: r,
                              history: _items,
                              onDeleteHistoryEntry: widget.onDelete,
                              onClearHistory: widget.onClearAll,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 128,
                            height: 96,
                            decoration: FeliVetUi.iconBadge(
                              context,
                              color: r.urgency.color,
                            ),
                            child: Center(
                              child: r.image != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        FeliVetUi.compactRadius,
                                      ),
                                      child: Image.file(
                                        r.image!,
                                        width: 128,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        cacheWidth: 256,
                                        filterQuality: FilterQuality.low,
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
                            ),
                          ),
                          const SizedBox(width: FeliVetUi.spaceMd),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  r.detectedDisease ?? 'No disease detected',
                                  style: FeliVetUi.heading(context, size: 16),
                                ),
                                const SizedBox(height: FeliVetUi.spaceXs),
                                Text(
                                  '${r.urgency.label} · ${r.timestamp.day}/${r.timestamp.month}/${r.timestamp.year} ${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: FeliVetUi.muted(context, size: 12),
                                ),
                                if (r.confidence != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: FeliVetUi.spaceXs,
                                    ),
                                    child: Text(
                                      'Confidence ${((r.confidence! * 100).round())}% · ${r.selectedSymptoms.isNotEmpty ? r.selectedSymptoms.join(', ') : '—'}',
                                      style: TextStyle(
                                        color: FeliVetUi.mutedLight,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Delete',
                            onPressed: () => _confirmDelete(r),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

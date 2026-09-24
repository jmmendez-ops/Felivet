import 'dart:async';

import 'package:flutter/material.dart';

import '../core/ui_tokens.dart';
import '../services/reminder_service.dart';

class FollowUpReminderPanel extends StatefulWidget {
  final String? catName;

  const FollowUpReminderPanel({super.key, this.catName});

  @override
  State<FollowUpReminderPanel> createState() => _FollowUpReminderPanelState();
}

class _FollowUpReminderPanelState extends State<FollowUpReminderPanel> {
  final _valueController = TextEditingController(text: '7');
  final _units = const ['Minutes', 'Hours', 'Days', 'Weeks', 'Years'];
  String _unit = 'Days';
  String? _error;
  String? _permissionError;
  List<ScheduledReminder> _reminders = [];
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshReminders();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _refreshReminders() async {
    try {
      final reminders = await ReminderService.reconcileReminders();
      final enabled = await ReminderService.notificationsEnabled();
      if (!mounted) return;
      setState(() {
        _reminders = reminders;
        _permissionError = enabled
            ? null
            : 'Notifications are turned off, so reminders cannot appear.';
        _now = DateTime.now();
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _reminders = [];
          _permissionError =
              'Notification access could not be checked on this device.';
        });
      }
    }
  }

  Duration? _selectedDuration() {
    final value = int.tryParse(_valueController.text.trim());
    if (value == null || value < 1) {
      setState(() => _error = 'Enter a whole number of at least 1.');
      return null;
    }

    final duration = switch (_unit) {
      'Minutes' => Duration(minutes: value),
      'Hours' => Duration(hours: value),
      'Days' => Duration(days: value),
      'Weeks' => Duration(days: value * 7),
      'Years' => Duration(days: value * 365),
      _ => null,
    };
    if (duration == null || duration < const Duration(minutes: 1)) {
      setState(() => _error = 'Choose an interval of at least 1 minute.');
      return null;
    }
    setState(() => _error = null);
    return duration;
  }

  Future<void> _setReminder() async {
    final delay = _selectedDuration();
    if (delay == null || _isBusy) return;
    setState(() => _isBusy = true);
    try {
      final reminder = await ReminderService.scheduleReminder(
        delay,
        catName: widget.catName,
      );
      if (!mounted) return;
      setState(() {
        _reminders = [..._reminders, reminder]
          ..sort((a, b) => a.fireTime.compareTo(b.fireTime));
        _isBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Follow-up reminder scheduled')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to schedule this reminder.')),
      );
    }
  }

  Future<void> _cancelReminder(ScheduledReminder reminder) async {
    await ReminderService.cancelReminder(reminder.id);
    if (!mounted) return;
    setState(() => _reminders.removeWhere((item) => item.id == reminder.id));
  }

  String _countdown(DateTime fireTime) {
    final remaining = fireTime.difference(_now);
    if (remaining.isNegative || remaining == Duration.zero) return 'due now';
    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);
    if (days > 0) return 'in ${days}d ${hours}h ${minutes}m';
    if (hours > 0) return 'in ${hours}h ${minutes}m ${seconds}s';
    return 'in ${minutes}m ${seconds}s';
  }

  String _dateTime(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: FeliVetUi.cardPadding,
      decoration: FeliVetUi.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                decoration: FeliVetUi.iconBadge(context),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: FeliVetUi.spaceMd),
              Text(
                'Follow-up Reminders',
                style: FeliVetUi.heading(context, size: 18),
              ),
            ],
          ),
          const SizedBox(height: FeliVetUi.spaceMd),
          Text('Remind me to check again in:', style: FeliVetUi.muted(context)),
          const SizedBox(height: FeliVetUi.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _valueController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: FeliVetUi.spaceSm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _unit,
                  decoration: const InputDecoration(
                    labelText: 'Unit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _units
                      .map(
                        (unit) =>
                            DropdownMenuItem(value: unit, child: Text(unit)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _unit = value ?? _unit),
                ),
              ),
            ],
          ),
          const SizedBox(height: FeliVetUi.spaceSm),
          FilledButton.icon(
            onPressed: _isBusy ? null : _setReminder,
            icon: const Icon(Icons.add_alert_outlined, size: 18),
            label: const Text('Set Reminder'),
          ),
          if (_permissionError != null) ...[
            const SizedBox(height: FeliVetUi.spaceSm),
            Text(
              _permissionError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton.icon(
              onPressed: ReminderService.openNotificationSettings,
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: const Text('Open notification settings'),
            ),
          ],
          if (_reminders.isNotEmpty) ...[
            const SizedBox(height: FeliVetUi.spaceMd),
            Text(
              'Scheduled reminders',
              style: FeliVetUi.heading(context, size: 14),
            ),
            const SizedBox(height: FeliVetUi.spaceSm),
            ..._reminders.map(
              (reminder) => Padding(
                padding: const EdgeInsets.only(bottom: FeliVetUi.spaceSm),
                child: Container(
                  padding: const EdgeInsets.all(FeliVetUi.spaceSm),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(
                      FeliVetUi.compactRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_outlined, size: 18),
                      const SizedBox(width: FeliVetUi.spaceSm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${_dateTime(reminder.fireTime)} · ${_countdown(reminder.fireTime)}',
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cancel reminder',
                        onPressed: () => _cancelReminder(reminder),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

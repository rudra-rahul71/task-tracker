import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/core/widgets/loading_overlay.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';

class AddTrackerDialog extends StatefulWidget {
  const AddTrackerDialog({super.key});

  @override
  State<AddTrackerDialog> createState() => _AddTrackerDialogState();
}

class _AddTrackerDialogState extends State<AddTrackerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TrackerRepository();

  String _name = '';
  String _type = 'maintain'; // 'maintain' or 'quit'
  String _durationType = 'indefinite'; // 'indefinite' or 'set_time'
  String _measurementUnit = 'days'; // 'days', 'weeks', 'months'
  int? _durationValue;
  bool _isLoading = false;
  DateTime _startDate = DateTime.now();

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = FirebaseAuth.instance.currentUser;
    final navigator = Navigator.of(context);

    if (user == null) {
      if (mounted) {
        SnackbarService(context).showErrorSnackbar(message: 'Error: User not authenticated');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final start = _startDate;
    DateTime? endDate;

    if (_durationType == 'set_time' && _durationValue != null) {
      switch (_measurementUnit) {
        case 'minutes':
          endDate = start.add(Duration(minutes: _durationValue!));
          break;
        case 'hours':
          endDate = start.add(Duration(hours: _durationValue!));
          break;
        case 'weeks':
          endDate = start.add(Duration(days: _durationValue! * 7));
          break;
        case 'months':
          endDate = DateTime(start.year, start.month + _durationValue!, start.day);
          break;
        case 'days':
        default:
          endDate = start.add(Duration(days: _durationValue!));
          break;
      }
    }

    final tracker = TrackerModel(
      id: '',
      userId: user.uid,
      name: _name,
      type: _type,
      durationType: _durationType,
      measurementUnit: _measurementUnit,
      durationValue: _durationValue,
      startDate: start,
      endDate: endDate,
      createdAt: now,
    );

    try {
      await _repository.addTracker(tracker);
      navigator.pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackbarService(context).showErrorSnackbar(message: 'Failed to create tracker: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: LoadingOverlay(
        isLoading: _isLoading,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Create Habit Tracker',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Habit Name Field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Habit Name',
                    hintText: 'e.g., Gym, Sleep Early, No Sweets',
                    hintStyle: const TextStyle(color: Colors.grey),
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name for your tracker';
                    }
                    return null;
                  },
                  onSaved: (value) => _name = value!.trim(),
                ),
                const SizedBox(height: 24),

                // Habit Goal Type
                const Text(
                  'What type of habit is this?',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'maintain',
                        label: Text('Maintain'),
                        icon: Icon(Icons.check_circle_outline_rounded),
                      ),
                      ButtonSegment(
                        value: 'quit',
                        label: Text('Quit'),
                        icon: Icon(Icons.block_flipped),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _type = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: _type == 'quit'
                          ? const Color(0xFFEF5350).withValues(alpha: 0.15)
                          : const Color(0xFF26A69A).withValues(alpha: 0.15),
                      selectedForegroundColor: _type == 'quit'
                          ? const Color(0xFFEF5350)
                          : const Color(0xFF26A69A),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Duration Type: Indefinite vs Set Time
                const Text(
                  'Duration Type',
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'indefinite',
                        label: Text('Indefinite'),
                        icon: Icon(Icons.trending_up_rounded),
                      ),
                      ButtonSegment(
                        value: 'set_time',
                        label: Text('Set Duration'),
                        icon: Icon(Icons.timer_outlined),
                      ),
                    ],
                    selected: {_durationType},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _durationType = newSelection.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      selectedForegroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Measurement Unit Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _measurementUnit,
                  decoration: InputDecoration(
                    labelText: 'Track Period By',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  dropdownColor: const Color(0xFF1E1E1E),
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'minutes', child: Text('Minutes', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'hours', child: Text('Hours', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'days', child: Text('Days', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'weeks', child: Text('Weeks', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'months', child: Text('Months', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _measurementUnit = value!;
                    });
                  },
                ),

                // Duration Value Input (Visible only for set duration)
                if (_durationType == 'set_time') ...[
                  const SizedBox(height: 24),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Duration Value ($_measurementUnit)',
                      hintText: 'e.g., 30',
                      hintStyle: const TextStyle(color: Colors.grey),
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    validator: (value) {
                      if (_durationType == 'set_time') {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a number';
                        }
                        final num = int.tryParse(value);
                        if (num == null || num <= 0) {
                          return 'Please enter a valid positive number';
                        }
                      }
                      return null;
                    },
                    onSaved: (value) => _durationValue = int.tryParse(value!),
                  ),
                ],
                const SizedBox(height: 24),

                // Start Date Picker Row
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date & Time', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')} ${_startDate.hour.toString().padLeft(2, '0')}:${_startDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.calendar_month, color: Theme.of(context).colorScheme.primary),
                    onPressed: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );

                      if (pickedDate != null) {
                        if (!context.mounted) return;
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(_startDate),
                        );
                        if (pickedTime != null) {
                          setState(() {
                            _startDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        } else {
                          setState(() {
                            _startDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              _startDate.hour,
                              _startDate.minute,
                            );
                          });
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                      onPressed: _isLoading ? null : _submit,
                      child: const Text(
                        'Create Tracker',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}

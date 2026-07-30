import 'package:get_it/get_it.dart';
import 'package:dynamic_backend_bridge/dynamic_backend_bridge.dart';
import 'package:flutter/material.dart';
import 'package:task_tracker/core/utils/date_parser.dart';
import 'package:task_tracker/core/utils/snackbar.dart';
import 'package:task_tracker/core/widgets/loading_overlay.dart';
import 'package:task_tracker/features/trackers/data/models/tracker.dart';
import 'package:task_tracker/features/trackers/data/repositories/tracker_repository.dart';

class AddTrackerDialog extends StatefulWidget {
  final TrackerModel? trackerToEdit;
  const AddTrackerDialog({super.key, this.trackerToEdit});

  @override
  State<AddTrackerDialog> createState() => _AddTrackerDialogState();
}

class _AddTrackerDialogState extends State<AddTrackerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TrackerRepository();

  String _name = '';
  String _type = 'maintain'; // 'maintain' or 'quit'
  String _durationType = 'indefinite'; // 'indefinite' or 'set_time'
  String _measurementUnit = 'days'; // 'days' only
  int? _durationValue;
  bool _isLoading = false;
  DateTime _startDate = DateTime.now().dateOnly;

  @override
  void initState() {
    super.initState();
    if (widget.trackerToEdit != null) {
      _name = widget.trackerToEdit!.name;
      _type = widget.trackerToEdit!.type;
      _durationType = widget.trackerToEdit!.durationType;
      _measurementUnit = widget.trackerToEdit!.measurementUnit;
      _durationValue = widget.trackerToEdit!.durationValue;
      _startDate = widget.trackerToEdit!.startDate;
    }
  }

  InputDecoration _buildInputDecoration(
    ColorScheme colorScheme,
    String labelText,
    String hintText,
  ) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.error, width: 2),
      ),
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final user = GetIt.instance<AuthRepository>().currentUser;
    final navigator = Navigator.of(context);

    if (user == null) {
      if (mounted) {
        SnackbarService(
          context,
        ).showErrorSnackbar(message: 'Error: User not authenticated');
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final start = _startDate.dateOnly;
    DateTime? endDate;

    if (_durationType == 'set_time' && _durationValue != null) {
      endDate = start.add(Duration(days: _durationValue!));
    }

    final isEditing = widget.trackerToEdit != null;
    final tracker = TrackerModel(
      id: isEditing ? widget.trackerToEdit!.id : '',
      userId: user.uid,
      name: _name,
      type: _type,
      durationType: _durationType,
      measurementUnit: _measurementUnit,
      durationValue: _durationValue,
      startDate: start,
      endDate: endDate,
      createdAt: isEditing ? widget.trackerToEdit!.createdAt : now,
      originalStartDate: isEditing
          ? (start.isBefore(widget.trackerToEdit!.originalStartDate) ||
                    widget.trackerToEdit!.startDate.isAtSameMomentAs(
                      widget.trackerToEdit!.originalStartDate,
                    )
                ? start
                : widget.trackerToEdit!.originalStartDate)
          : start,
      completedDates: isEditing
          ? widget.trackerToEdit!.completedDates
          : const [],
    );

    try {
      if (isEditing) {
        await _repository.updateTracker(tracker);
      } else {
        await _repository.addTracker(tracker);
      }
      navigator.pop();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        SnackbarService(context).showErrorSnackbar(
          message: 'Failed to ${isEditing ? "update" : "create"} tracker: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: colorScheme.primary.withValues(alpha: 0.15),
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
                          widget.trackerToEdit != null
                              ? 'Edit Tracker'
                              : 'Create Habit Tracker',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Habit Name Field
                  TextFormField(
                    initialValue: _name,
                    decoration: _buildInputDecoration(
                      colorScheme,
                      'Habit Name',
                      'e.g., Gym, Sleep Early, No Sweets',
                    ),
                    style: TextStyle(color: colorScheme.onSurface),
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
                  Text(
                    'What type of habit is this?',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                            ? colorScheme.error.withValues(alpha: 0.15)
                            : colorScheme.tertiary.withValues(alpha: 0.15),
                        selectedForegroundColor: _type == 'quit'
                            ? colorScheme.error
                            : colorScheme.tertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Duration Type: Indefinite vs Set Time
                  Text(
                    'Duration Type',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
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
                        selectedBackgroundColor: colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                        selectedForegroundColor: colorScheme.primary,
                      ),
                    ),
                  ),

                  // Duration Value Input (Visible only for set duration)
                  if (_durationType == 'set_time') ...[
                    const SizedBox(height: 24),
                    TextFormField(
                      initialValue: _durationValue?.toString() ?? '',
                      decoration: _buildInputDecoration(
                        colorScheme,
                        'Duration Value ($_measurementUnit)',
                        'e.g., 30',
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: colorScheme.onSurface),
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
                    title: Text(
                      'Start Date',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.calendar_month,
                        color: colorScheme.primary,
                      ),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );

                        if (pickedDate != null) {
                          setState(() {
                            _startDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                            );
                          });
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
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: Text(
                          widget.trackerToEdit != null
                              ? 'Save Changes'
                              : 'Create Tracker',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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

import 'package:fitapp/app/theme/tokens.dart';
import 'package:fitapp/core/format.dart';
import 'package:fitapp/core/haptics.dart';
import 'package:fitapp/data/db/app_database.dart';
import 'package:fitapp/data/providers.dart';
import 'package:fitapp/domain/activity_types.dart';
import 'package:fitapp/features/activities/activity_icons.dart';
import 'package:fitapp/widgets/guard.dart';
import 'package:fitapp/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

export 'package:fitapp/core/format.dart' show formatActivityMinutes;

/// Opens the past-session / edit activity form.
Future<void> showActivitySheet(
  BuildContext context, {
  ActivityRow? existing,
  String? initialTypeId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _ActivitySheet(existing: existing, initialTypeId: initialTypeId),
);

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class _ActivitySheet extends ConsumerStatefulWidget {
  const new({required this.existing, this.initialTypeId});

  final ActivityRow? existing;

  /// Preselected type for a new entry.
  final String? initialTypeId;

  @override
  ConsumerState<_ActivitySheet> createState() => _ActivitySheetState();
}

class _ActivitySheetState extends ConsumerState<_ActivitySheet> {
  late final _note = TextEditingController(text: widget.existing?.notes);
  late String? _typeId = widget.existing?.typeId ?? widget.initialTypeId;
  late DateTime _date = _day(
    (widget.existing?.startedAt ?? ref.read(clockProvider)()).toLocal(),
  );
  late bool _hasDuration = widget.existing?.durationMinutes != null;
  late int _minutes = widget.existing?.durationMinutes ?? 30;
  late bool _hasDistance = widget.existing?.distanceMeters != null;
  late final _distance = TextEditingController(
    text: switch (widget.existing?.distanceMeters) {
      final m? => distanceKmText(m),
      _ => '',
    },
  );
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// A GPS-tracked activity: duration and distance come from the recording
  /// and are not editable; only type (among live types), date and note are.
  bool get _isGps => widget.existing?.source == 'gps';

  /// Whether the selected type can carry a distance.
  bool get _showDistance =>
      _typeId != null && (activityTypeById(_typeId!)?.hasDistance ?? false);

  /// Typed distance in metres; null when empty or invalid.
  int? get _parsedDistance => parseDistanceKm(_distance.text);

  bool get _distanceInvalid =>
      !_isGps && _showDistance && _hasDistance && _parsedDistance == null;

  /// Distance to store: typed value for distance types, the stored value
  /// kept for retired (unknown) types, otherwise none.
  int? get _distanceToSave {
    if (_showDistance) return _hasDistance ? _parsedDistance : null;
    final id = _typeId;
    if (id != null && activityTypeById(id) == null) {
      return widget.existing?.distanceMeters;
    }
    return null;
  }

  @override
  void dispose() {
    _note.dispose();
    _distance.dispose();
    super.dispose();
  }

  String _dateLabel(DateTime now) {
    final today = _day(now);
    if (_date == today) return 'Today';
    if (_date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return formatDateShort(_date);
  }

  Future<void> _pickDate() async {
    final today = _day(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(today.year - 5, today.month, today.day),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _date = _day(picked));
  }

  Future<void> _save() async {
    final typeId = _typeId;
    if (typeId == null) return;
    final now = ref.read(clockProvider)().toLocal();
    final existing = widget.existing;
    final DateTime startedAt;
    if (existing != null && _day(existing.startedAt.toLocal()) == _date) {
      startedAt = existing.startedAt;
    } else {
      startedAt = DateTime(
        _date.year,
        _date.month,
        _date.day,
        now.hour,
        now.minute,
      );
    }
    final repo = ref.read(activityRepositoryProvider);
    final duration = _isGps
        ? existing?.durationMinutes
        : (_hasDuration ? _minutes : null);
    final distance = _isGps ? existing?.distanceMeters : _distanceToSave;
    final notes = _note.text;
    setState(() => _saving = true);
    final ok = await guard(
      context,
      () => existing == null
          ? repo.create(
              typeId: typeId,
              startedAt: startedAt,
              durationMinutes: duration,
              distanceMeters: distance,
              notes: notes,
            )
          : repo.update(
              existing.id,
              typeId: typeId,
              startedAt: startedAt,
              durationMinutes: duration,
              distanceMeters: distance,
              notes: notes,
            ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ref.read(hapticsProvider).success();
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete activity?',
      message: 'This activity will be deleted. This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!ok || !mounted) return;
    final repo = ref.read(activityRepositoryProvider);
    final done = await guard(context, () => repo.delete(widget.existing!.id));
    if (done && mounted) Navigator.of(context).pop();
  }

  /// Whether the type picker offers [t]. A GPS activity keeps to the live
  /// types, and tracked snowboarding is never switched to or from.
  bool _offers(ActivityType t) {
    if (!_isGps) return true;
    if (widget.existing?.typeId == 'snowboarding') {
      return t.id == 'snowboarding';
    }
    return t.hasLiveTracking && t.id != 'snowboarding';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider)();
    final options = [
      for (final t in activityTypes)
        if (_offers(t)) t,
      if (widget.existing != null &&
          activityTypeById(widget.existing!.typeId) == null)
        ActivityType(widget.existing!.typeId, 'Activity'),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Space.m,
          0,
          Space.m,
          Space.m + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEdit ? 'Edit activity' : 'Log a past session',
              style: text.titleLarge,
            ),
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.s,
              runSpacing: Space.s,
              children: [
                for (final t in options)
                  _TypeTile(
                    type: t,
                    isSelected: t.id == _typeId,
                    onTap: () => setState(() => _typeId = t.id),
                  ),
              ],
            ),
            const SizedBox(height: Space.m),
            Group(
              children: [
                GroupRow(
                  title: 'Date',
                  trailing: Text(
                    _dateLabel(now),
                    style: text.bodyLarge?.copyWith(color: AppColors.accent),
                  ),
                  showChevron: true,
                  onTap: _pickDate,
                ),
              ],
            ),
            const SizedBox(height: Space.m),
            if (_isGps)
              Text(
                'Duration and distance come from the GPS recording.',
                style: text.bodySmall?.copyWith(color: AppColors.textSecondary),
              )
            else ...[
              Text('DURATION', style: text.labelSmall),
              const SizedBox(height: Space.s),
              ChipSelector<bool>(
                options: const [false, true],
                selected: _hasDuration,
                labelOf: (v) => v ? 'Set' : 'None',
                onSelected: (v) => setState(() => _hasDuration = v),
              ),
            ],
            if (!_isGps && _hasDuration) ...[
              const SizedBox(height: Space.m),
              DurationPicker(
                minutes: _minutes,
                max: maxActivityMinutes,
                onChanged: (v) => setState(() => _minutes = v),
              ),
            ],
            if (!_isGps && _showDistance) ...[
              const SizedBox(height: Space.m),
              Text('DISTANCE', style: text.labelSmall),
              const SizedBox(height: Space.s),
              ChipSelector<bool>(
                options: const [false, true],
                selected: _hasDistance,
                labelOf: (v) => v ? 'Set' : 'None',
                onSelected: (v) => setState(() => _hasDistance = v),
              ),
              if (_hasDistance) ...[
                const SizedBox(height: Space.m),
                Semantics(
                  label: 'Distance in kilometres',
                  child: TextField(
                    controller: _distance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Distance',
                      suffixText: 'km',
                      errorText: _distanceInvalid && _distance.text.isNotEmpty
                          ? 'Enter a distance up to 1000 km'
                          : null,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: Space.m),
            TextField(
              controller: _note,
              maxLength: maxActivityNoteLength,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: Space.m),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: _typeId == null || _saving || _distanceInvalid
                  ? null
                  : _save,
            ),
            if (_isEdit)
              TextButton(
                onPressed: _delete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  minimumSize: const Size.fromHeight(Sizes.tap),
                ),
                child: const Text('Delete'),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypeTile extends StatelessWidget {
  const new({
    required this.type,
    required this.isSelected,
    required this.onTap,
  });

  final ActivityType type;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isSelected ? AppColors.onAccent : AppColors.textPrimary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: type.label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: isSelected ? AppColors.accent : AppColors.surfaceHigh,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.tap),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ActivityIcon(type.id, size: 20, color: fg),
                  const SizedBox(width: Space.s),
                  Text(
                    type.label,
                    style: TextStyle(fontWeight: FontWeight.w700, color: fg),
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

import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Rebuilds [builder] once per second. Only for display: values are always
/// computed from stored timestamps.
class Tick extends StatefulWidget {
  const new({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<Tick> createState() => _TickState();
}

class _TickState extends State<Tick> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

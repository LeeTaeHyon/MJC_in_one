import "package:flutter/material.dart";

/// Tooltip can throw `No Overlay widget found` when built with a context that
/// doesn't have an [Overlay] (e.g. in some embedded/hosted trees).
///
/// This widget degrades gracefully by rendering [child] without a tooltip when
/// there is no overlay available.
class SafeTooltip extends StatelessWidget {
  const SafeTooltip({
    super.key,
    required this.message,
    required this.child,
    this.waitDuration,
    this.preferBelow,
  });

  final String message;
  final Widget child;
  final Duration? waitDuration;
  final bool? preferBelow;

  @override
  Widget build(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return child;
    return Tooltip(
      message: message,
      waitDuration: waitDuration,
      preferBelow: preferBelow,
      child: child,
    );
  }
}


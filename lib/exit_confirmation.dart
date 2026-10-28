import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitConfirmation extends StatefulWidget {
  const ExitConfirmation({super.key, required this.child});
  final Widget child;

  @override
  State<ExitConfirmation> createState() => _ExitConfirmationState();
}

class _ExitConfirmationState extends State<ExitConfirmation> {
  bool confirming = false;

  Future<void> confirmExit() async {
    if (confirming || ModalRoute.of(context)?.isCurrent != true) return;
    confirming = true;
    try {
      final exit = await showDialog<bool>(
        context: context,
        builder: (context) => Dialog(
          alignment: Alignment.bottomCenter,
          insetPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          constraints: const BoxConstraints(maxWidth: 380),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                Text('Çıkış?', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('İptal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Tamam'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (exit == true && mounted) await SystemNavigator.pop();
    } finally {
      confirming = false;
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) confirmExit();
    },
    child: widget.child,
  );
}

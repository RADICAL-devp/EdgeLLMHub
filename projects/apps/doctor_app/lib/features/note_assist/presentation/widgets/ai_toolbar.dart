import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/ai_assist_cubit.dart';
import '../cubit/ai_assist_state.dart';

class AiToolbar extends StatelessWidget {
  final String currentText;

  const AiToolbar({super.key, required this.currentText});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiAssistCubit, AiAssistState>(
      builder: (context, state) {
        final isBusy = state is AiAssistGenerating;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionButton(
                  context,
                  icon: Icons.auto_fix_high,
                  label: 'Clean up',
                  isBusy: isBusy,
                  onPressed: () {
                    if (currentText.isNotEmpty) {
                      context.read<AiAssistCubit>().cleanUpText(currentText);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  context,
                  icon: Icons.format_list_bulleted,
                  label: 'Structure',
                  isBusy: isBusy,
                  onPressed: () {
                    if (currentText.isNotEmpty) {
                      context.read<AiAssistCubit>().structureNote(currentText);
                    }
                  },
                ),
                _buildActionButton(
                  context,
                  icon: Icons.data_object,
                  label: 'Extract',
                  isBusy: isBusy,
                  onPressed: () {
                    if (currentText.isNotEmpty) {
                      context.read<AiAssistCubit>().extractFields(currentText);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  context,
                  icon: Icons.summarize,
                  label: 'Recap',
                  isBusy: isBusy,
                  onPressed: () {
                    if (currentText.isNotEmpty) {
                      context.read<AiAssistCubit>().generateRecap(currentText);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isBusy,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: isBusy ? null : onPressed,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

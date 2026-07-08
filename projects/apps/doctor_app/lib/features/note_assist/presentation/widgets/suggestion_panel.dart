import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/ai_assist_cubit.dart';
import '../cubit/ai_assist_state.dart';

class SuggestionPanel extends StatelessWidget {
  final Function(String) onAccept;

  const SuggestionPanel({super.key, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AiAssistCubit, AiAssistState>(
      builder: (context, state) {
        if (state is AiAssistInitial) {
          return const SizedBox.shrink();
        }

        String content = '';
        String action = '';
        bool isGenerating = false;

        if (state is AiAssistGenerating) {
          content = state.currentSuggestion;
          action = state.activeAction;
          isGenerating = true;
        } else if (state is AiAssistSuggestionReady) {
          content = state.suggestion;
          action = state.action;
        } else if (state is AiAssistError) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade100,
            child: Text('Error: ${state.message}', style: const TextStyle(color: Colors.red)),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      isGenerating ? Icons.sync : Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isGenerating ? 'AI is $action...' : 'AI Suggestion ($action)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Spacer(),
                    if (isGenerating)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => context.read<AiAssistCubit>().discardSuggestion(),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    content.isEmpty ? 'Waiting for response...' : content,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              if (!isGenerating) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.read<AiAssistCubit>().discardSuggestion(),
                        child: const Text('Discard'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () {
                          onAccept(content);
                          context.read<AiAssistCubit>().discardSuggestion();
                        },
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

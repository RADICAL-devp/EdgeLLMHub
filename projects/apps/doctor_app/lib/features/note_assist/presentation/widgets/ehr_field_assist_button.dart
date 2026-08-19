import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/models/patient_context.dart';
import '../cubit/ehr_assist_cubit.dart';
import '../cubit/ehr_assist_state.dart';

/// A button that triggers AI assistance for a specific EHR field.
///
/// Wraps a form field (e.g., TextFormField) and shows an "AI Assist" button
/// that generates suggestions using the local LLM.
class EhrFieldAssistButton extends StatelessWidget {
  final String fieldName;
  final String fieldLabel;
  final String transcriptText;
  final PatientContext? patientContext;
  final Function(String) onSuggestionAccepted;
  final bool useStreaming;
  final bool useContextEnrichment;

  const EhrFieldAssistButton({
    super.key,
    required this.fieldName,
    required this.fieldLabel,
    required this.transcriptText,
    this.patientContext,
    required this.onSuggestionAccepted,
    this.useStreaming = true,
    this.useContextEnrichment = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EhrAssistCubit, EhrAssistState>(
      builder: (context, state) {
        final isBusy = state is EhrAssistGenerating;
        final AiSuggestion? suggestion = _getSuggestion(state);
        final hasError = state is EhrAssistError && state.fieldName == fieldName;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    fieldLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                ActionChip(
                  avatar: Icon(
                    isBusy ? Icons.hourglass_empty : Icons.auto_awesome,
                    size: 16,
                    color: isBusy ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                  ),
                  label: Text(isBusy ? 'Generating...' : '🤖 Assist'),
                  onPressed: isBusy
                      ? null
                      : () {
                          if (useStreaming) {
                            context.read<EhrAssistCubit>().suggestFieldStream(
                                  fieldName: fieldName,
                                  transcriptText: transcriptText,
                                  patientContext: patientContext,
                                  useContextEnrichment: useContextEnrichment,
                                );
                          } else {
                            context.read<EhrAssistCubit>().suggestField(
                                  fieldName: fieldName,
                                  transcriptText: transcriptText,
                                  patientContext: patientContext,
                                  useContextEnrichment: useContextEnrichment,
                                );
                          }
                        },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: isBusy
                      ? Theme.of(context).colorScheme.surfaceContainerHighest
                      : null,
                ),
              ],
            ),
            if (suggestion != null) ...[
              const SizedBox(height: 8),
              _SuggestionCard(
                suggestion: suggestion,
                isGenerating: isBusy,
                hasError: hasError,
                errorMessage: hasError ? (state as EhrAssistError).message : null,
                onAccept: () {
                  onSuggestionAccepted(suggestion.suggestion);
                  context.read<EhrAssistCubit>().acceptSuggestion();
                },
                onDismiss: () {
                  context.read<EhrAssistCubit>().discardSuggestion();
                },
                onEdit: (edited) {
                  context.read<EhrAssistCubit>().acceptEditedSuggestion(edited);
                },
              ),
            ],
            if (hasError) ...[
              const SizedBox(height: 8),
              Text(
                (state as EhrAssistError).message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
          ],
        );
      },
    );
  }

  AiSuggestion? _getSuggestion(EhrAssistState state) {
    if (state is EhrAssistGenerating) {
      // During generation, create a temporary AiSuggestion with partial text
      return AiSuggestion(
        fieldName: state.fieldName,
        suggestion: state.suggestion,
        confidence: 0.0,
      );
    } else if (state is EhrAssistSuggestionReady) {
      return state.suggestion;
    }
    return null;
  }
}

class _SuggestionCard extends StatelessWidget {
  final AiSuggestion suggestion;
  final bool isGenerating;
  final bool hasError;
  final String? errorMessage;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final Function(String) onEdit;

  const _SuggestionCard({
    required this.suggestion,
    required this.isGenerating,
    required this.hasError,
    this.errorMessage,
    required this.onAccept,
    required this.onDismiss,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: isGenerating
          ? scheme.surfaceContainerHighest
          : hasError
              ? scheme.errorContainer.withValues(alpha: 0.3)
              : scheme.secondaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isGenerating
              ? scheme.primary.withValues(alpha: 0.5)
              : hasError
                  ? scheme.error
                  : scheme.secondary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isGenerating
                      ? Icons.hourglass_empty
                      : hasError
                          ? Icons.error_outline
                          : Icons.auto_awesome,
                  size: 16,
                  color: isGenerating
                      ? scheme.primary
                      : hasError
                          ? scheme.error
                          : scheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isGenerating
                        ? 'Generating...'
                        : hasError
                            ? 'Error: $errorMessage'
                            : 'AI Suggestion',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isGenerating
                              ? scheme.primary
                              : hasError
                                  ? scheme.error
                                  : scheme.secondary,
                        ),
                  ),
                ),
                if (!isGenerating && !hasError && suggestion.confidence > 0)
                  _ConfidenceBadge(confidence: suggestion.confidence),
              ],
            ),
            const SizedBox(height: 8),
            if (suggestion.contextUsed != null && suggestion.contextUsed!.isNotEmpty)
              _ContextUsedIndicator(contexts: suggestion.contextUsed!),
            if (!isGenerating && suggestion.contextUsed != null && suggestion.contextUsed!.isNotEmpty)
              const SizedBox(height: 8),
            SelectableText(
              suggestion.suggestion,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 12),
            if (!isGenerating && !hasError) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Dismiss'),
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showEditDialog(context),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accept'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: suggestion.suggestion);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Suggestion'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          minLines: 3,
          decoration: const InputDecoration(
            hintText: 'Modify the suggestion before accepting',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onEdit(controller.text);
              Navigator.pop(context);
            },
            child: const Text('Save & Accept'),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color color;
    String label;

    if (confidence >= 0.8) {
      color = Colors.green;
      label = 'High';
    } else if (confidence >= 0.5) {
      color = Colors.orange;
      label = 'Medium';
    } else {
      color = Colors.red;
      label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label (${(confidence * 100).toInt()}%)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _ContextUsedIndicator extends StatelessWidget {
  final List<PastConsultationContext> contexts;

  const _ContextUsedIndicator({required this.contexts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history, size: 14, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enriched with ${contexts.length} past consultation${contexts.length > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (contexts.isNotEmpty)
                  Text(
                    'Top match: ${contexts.first.patientName} (${(contexts.first.similarityScore * 100).toStringAsFixed(0)}%)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
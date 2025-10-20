import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';

/// Displays a single Daily Prompt assessment.
/// Equivalent to prompt/[id]/+page.svelte.
class PromptPage extends StatefulWidget {
  final String instanceId;
  const PromptPage({super.key, required this.instanceId});

  @override
  State<PromptPage> createState() => _PromptPageState();
}

class _PromptPageState extends State<PromptPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? user;
  Map<String, dynamic>? question;
  Map<String, dynamic>? feedback;
  bool loading = true;
  String? error;
  late int startTime;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final session = await SessionService.loadSession();
      if (session == null || session['user_id'] == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        });
        return;
      }

      setState(() => user = session);

      // Fetch the prompt question
      final result = await supabase.rpc(
        'rpc_fetch_prompt_question',
        params: {'p_instance_id': widget.instanceId},
      );

      if (result == null) throw Exception('No data returned.');
      Map<String, dynamic> q;
      if (result is List && result.isNotEmpty) {
        q = Map<String, dynamic>.from(result.first);
      } else {
        q = Map<String, dynamic>.from(result as Map);
      }

      setState(() {
        question = q;
        startTime = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submitResponse(String choiceLabel) async {
    if (question == null || user == null) return;

    final endTime = DateTime.now().millisecondsSinceEpoch;
    final timeSpent = endTime - startTime;

    try {
      final data = await supabase.rpc('rpc_submit_prompt_response', params: {
        'p_instance_id': widget.instanceId,
        'p_question_id': question!['question_id'],
        'p_choice_label': choiceLabel,
        'p_user_id': user!['user_id'],
        'p_response_time_ms': timeSpent,
      });

      if (data == null) throw Exception('No response from server.');

      Map<String, dynamic> fb;
      if (data is List && data.isNotEmpty) {
        fb = Map<String, dynamic>.from(data.first);
      } else {
        fb = Map<String, dynamic>.from(data as Map);
      }

      setState(() => feedback = fb);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Recall Prompt'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: loading
                ? const CircularProgressIndicator()
                : error != null
                ? Text(error!,
                style:
                const TextStyle(color: Colors.red, fontSize: 16))
                : feedback != null
                ? _buildFeedback(theme)
                : _buildQuestion(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(ThemeData theme) {
    final q = question!;
    final choices = (q['choices'] as List<dynamic>? ?? [])
        .map<Map<String, dynamic>>(
            (c) => Map<String, dynamic>.from(c as Map))
        .toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              q['stem'] ?? 'No question text.',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...choices.map((choice) {
              final label = choice['label'] ?? '?';
              final text = choice['text'] ?? '';
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  onPressed: () => _submitResponse(label),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade50,
                    foregroundColor: Colors.indigo.shade900,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('$label. $text',
                        style: const TextStyle(fontSize: 15)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Text(
              '${q['topic'] ?? '—'} • ${q['difficulty'] ?? '—'}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback(ThemeData theme) {
    final isCorrect = feedback?['is_correct'] == true;
    final explanation = feedback?['explanation'] ?? '';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isCorrect ? '✅ Correct!' : '❌ Incorrect',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: isCorrect ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          explanation,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        FilledButton.icon(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
          icon: const Icon(Icons.dashboard),
          label: const Text('Return to Dashboard'),
        ),
      ],
    );
  }
}
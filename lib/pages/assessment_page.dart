import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';

/// Equivalent to Svelte's assessment/[id]/+page.svelte
/// Handles short quizzes, adaptive, or mock exams where multiple questions are loaded upfront.
class AssessmentPage extends StatefulWidget {
  final String instanceId;
  const AssessmentPage({super.key, required this.instanceId});

  @override
  State<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends State<AssessmentPage> {
  final supabase = Supabase.instance.client;

  Map<String, dynamic>? user;
  List<Map<String, dynamic>> questions = [];
  int currentIndex = 0;
  bool loading = true;
  bool completed = false;
  String? error;
  int startTime = 0;

  @override
  void initState() {
    super.initState();
    _initializeAssessment();
  }

  Future<void> _initializeAssessment() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final session = await SessionService.loadSession();
      if (session == null || session['user_id'] == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
        return;
      }
      setState(() => user = session);

      final data = await supabase.rpc(
        'rpc_fetch_assessment_instance_items',
        params: {'p_instance_id': widget.instanceId},
      );

      if (data == null) throw Exception('No questions returned.');

      List<Map<String, dynamic>> parsed;
      if (data is List && data.isNotEmpty) {
        parsed =
            data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        parsed = [];
      }

      if (parsed.isEmpty) throw Exception('Empty question list.');

      setState(() {
        questions = parsed;
        currentIndex = 0;
        completed = false;
        startTime = DateTime.now().millisecondsSinceEpoch;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submitResponse(String choiceLabel) async {
    if (user == null || questions.isEmpty) return;

    final currentQuestion = questions[currentIndex];
    final endTime = DateTime.now().millisecondsSinceEpoch;
    final responseTime = endTime - startTime;

    try {
      await supabase.rpc('rpc_submit_response', params: {
        'p_instance_id': widget.instanceId,
        'p_question_id': currentQuestion['question_id'],
        'p_choice_label': choiceLabel,
        'p_user_id': user!['user_id'],
        'p_response_time_ms': responseTime,
      });

      if (currentIndex + 1 >= questions.length) {
        // Quiz completed
        setState(() => completed = true);
      } else {
        setState(() {
          currentIndex++;
          startTime = DateTime.now().millisecondsSinceEpoch;
        });
      }
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
        title: const Text('Assessment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
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
                style: const TextStyle(color: Colors.red, fontSize: 16))
                : completed
                ? _buildCompletionScreen(theme)
                : _buildQuestion(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestion(ThemeData theme) {
    if (questions.isEmpty) {
      return const Text('No questions found.');
    }

    final q = questions[currentIndex];
    final total = questions.length;
    final indexDisplay = currentIndex + 1;
    final choices = (q['choices'] as List<dynamic>? ?? [])
        .map<Map<String, dynamic>>(
            (c) => Map<String, dynamic>.from(c as Map))
        .toList();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Question $indexDisplay of $total',
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              q['stem'] ?? 'No question text.',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
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
      ),
    );
  }

  Widget _buildCompletionScreen(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle_outline,
            size: 80, color: Colors.green),
        const SizedBox(height: 20),
        Text(
          'Assessment Complete!',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text('Your answers have been recorded successfully.'),
        const SizedBox(height: 30),
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
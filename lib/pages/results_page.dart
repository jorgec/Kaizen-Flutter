import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';

class ResultsPage extends StatefulWidget {
  final String instanceId;
  final String? title;

  const ResultsPage({
    super.key,
    required this.instanceId,
    this.title,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> results = [];

  // Track which questions have “Show Answer” toggled
  final Map<int, bool> _revealedAnswers = {};

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  Future<void> _loadResults() async {
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

      final data = await supabase.rpc(
        'rpc_fetch_assessment_results_detail',
        params: {'p_instance_id': widget.instanceId},
      );

      if (data == null || data is! List) {
        throw Exception('Unexpected result format from RPC');
      }

      setState(() {
        results = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
            child: Text(
              error!,
              style: const TextStyle(color: Colors.red),
            ),
          )
              : results.isEmpty
              ? const Center(
            child: Text('No result data available.'),
          )
              : _buildResults(theme),
        ),
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    final total = results.length;
    final correct =
        results.where((q) => q['is_user_correct'] == true).length;
    final percent = total == 0 ? 0.0 : (correct / total * 100);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Icon(Icons.emoji_events,
                    size: 80, color: Colors.amberAccent),
                const SizedBox(height: 8),
                Text(
                  widget.title ?? 'Assessment Results',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: Colors.indigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$correct / $total correct',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Question Review',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...results.asMap().entries.map((entry) {
            final index = entry.key;
            final q = entry.value;
            return _buildQuestionCard(index, q);
          }).toList(),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.dashboard),
              label: const Text('Return to Dashboard'),
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/dashboard'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, Map<String, dynamic> q) {
    final stem = q['stem'] ?? '—';
    final isCorrect = q['is_user_correct'] ?? false;
    final userChoice = q['user_choice'] ?? '';
    final userChoiceText = q['user_choice_text'] ?? '';
    final correctLabel = q['correct_label'] ?? '';
    final correctText = q['correct_text'] ?? '';
    final explanation = q['explanation'] ?? '';
    final difficulty = q['difficulty'] ?? '';
    final topic = q['topic'] ?? '';
    final subtopic = q['subtopic'] ?? '';
    final subject = q['subject'] ?? '';
    final isRevealed = _revealedAnswers[index] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stem,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              isCorrect
                  ? '✅ Your Answer: $userChoice — $userChoiceText'
                  : '❌ Your Answer: $userChoice — $userChoiceText',
              style: TextStyle(
                color: isCorrect ? Colors.green : Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),

            // Reveal button
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: Icon(
                  isRevealed ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                ),
                label: Text(
                  isRevealed ? 'Hide Correct Answer' : 'Show Correct Answer',
                ),
                onPressed: () {
                  setState(() {
                    _revealedAnswers[index] = !isRevealed;
                  });
                },
              ),
            ),

            AnimatedCrossFade(
              crossFadeState: isRevealed
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Correct Answer: $correctLabel — $correctText',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (explanation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        explanation,
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('Subject: $subject', Colors.blueGrey.shade100),
                _chip('Topic: $topic', Colors.indigo.shade100),
                _chip('Subtopic: $subtopic', Colors.deepPurple.shade100),
                _chip('Difficulty: $difficulty', Colors.orange.shade100),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color bg) => Chip(
    backgroundColor: bg,
    label: Text(
      text,
      style: const TextStyle(fontSize: 12),
    ),
  );
}
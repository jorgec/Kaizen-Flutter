import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';

class AnalyticsAptitudePage extends StatefulWidget {
  const AnalyticsAptitudePage({super.key});

  @override
  State<AnalyticsAptitudePage> createState() => _AnalyticsAptitudePageState();
}

class _AnalyticsAptitudePageState extends State<AnalyticsAptitudePage> {
  final supabase = Supabase.instance.client;

  bool loading = true;
  String? error;
  Map<String, dynamic>? user;
  List<Map<String, dynamic>> disciplines = [];

  List<Map<String, dynamic>> drilldownItems = [];
  bool showDrawer = false;
  String drilldownTitle = '';

  @override
  void initState() {
    super.initState();
    _loadAptitude();
  }

  Future<void> _loadAptitude() async {
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

      final response = await supabase.rpc(
        'rpc_calculate_user_aptitude',
        params: {'p_user_id': session['user_id']},
      );

      if (response == null || response is! List) {
        throw Exception('Unexpected result format');
      }

      final parsed = response.map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() {
        disciplines = parsed;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _loadDrilldown({
    int? subjectId,
    int? topicId,
    int? subtopicId,
    required String title,
  }) async {
    try {
      final res = await supabase.rpc(
        'rpc_user_taxonomy_drilldown',
        params: {
          'p_user_id': user?['user_id'],
          'p_subject_id': subjectId,
          'p_topic_id': topicId,
          'p_subtopic_id': subtopicId,
        },
      );

      if (res == null || res is! List) throw Exception('Unexpected result');

      final parsed = res.map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() {
        drilldownItems = parsed;
        drilldownTitle = title;
        showDrawer = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading details: $e')),
      );
    }
  }

  Widget _buildSummaryRow(String label, dynamic value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color ?? Colors.grey.shade700, fontSize: 13),
      ),
    );
  }

  List<Widget> _buildSubtopics(List subs, int topicId) {
    return subs.map<Widget>((sub) {
      final mastery = ((sub['mastery_pct'] ?? 0.0) as num).toStringAsFixed(1);
      return ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 32, right: 8),
        title: Text(sub['subtopic'] ?? 'Unnamed Subtopic',
            style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          'Mastery: $mastery% | Stability: ${(sub['stability'] ?? 0.0).toStringAsFixed(2)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _loadDrilldown(
          subtopicId: sub['subtopic_id'],
          title: sub['subtopic'] ?? '',
        ),
      );
    }).toList();
  }

  List<Widget> _buildTopics(List topics, int subjectId) {
    return topics.map<Widget>((topic) {
      final mastery = ((topic['mastery'] ?? 0.0) * 100).toStringAsFixed(1);
      return ExpansionTile(
        title: Text(topic['topic'] ?? 'Unnamed Topic'),
        subtitle: Text(
            'Mastery: $mastery% | Attempts: ${topic['attempts']} | Stability: ${(topic['stability'] ?? 0.0).toStringAsFixed(2)}'),
        children: _buildSubtopics(topic['subtopics'] ?? [], topic['topic_id']),
        onExpansionChanged: (_) {},
      );
    }).toList();
  }


  Widget _buildSubjects(List subjects) {
    return Column(
      children: subjects.map<Widget>((subject) {
        final mastery = ((subject['mastery'] ?? 0.0) * 100).toStringAsFixed(1);
        return ExpansionTile(
          title: Text(subject['subject'] ?? 'Unnamed Subject',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(
              'Mastery: $mastery% | Attempts: ${subject['attempts']} | Stability: ${(subject['stability'] ?? 0.0).toStringAsFixed(2)}'),
          trailing: const Icon(Icons.school),
          children: _buildTopics(subject['topics'] ?? [], subject['subject_id']),
          onExpansionChanged: (expanded) {
            if (!expanded) return;
            // optional: lazy loading if subject-level drilldown needed
          },
        );
      }).toList(),
    );
  }

  Widget _buildDrilldownDrawer() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      right: showDrawer ? 0 : -400,
      top: 0,
      bottom: 0,
      width: 400,
      child: Material(
        elevation: 8,
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.close),
                title: Text(drilldownTitle,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                onTap: () => setState(() => showDrawer = false),
              ),
              const Divider(height: 1),
              Expanded(
                child: drilldownItems.isEmpty
                    ? const Center(child: Text('No items found'))
                    : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: drilldownItems.length,
                  itemBuilder: (context, i) {
                    final q = drilldownItems[i];
                    final responses =
                        (q['responses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                    bool showAnswer = false;

                    return StatefulBuilder(
                      builder: (context, setLocalState) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(q['stem'] ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Text(
                                  'Difficulty: ${q['difficulty'] ?? '—'}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  children: responses.map((r) {
                                    final correct = r['is_correct'] == true;
                                    return ListTile(
                                      dense: true,
                                      leading: Icon(
                                        correct
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: correct
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      title: Text(
                                          '${r['choice_label']}. ${r['choice_text']}'),
                                      subtitle: Text(
                                          'Answered at: ${r['answered_at'] ?? ''}'),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 10),
                                Center(
                                  child: OutlinedButton.icon(
                                    icon: Icon(
                                      showAnswer
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                    label: Text(showAnswer
                                        ? 'Hide Correct Answer'
                                        : 'Show Correct Answer'),
                                    onPressed: () => setLocalState(() {
                                      showAnswer = !showAnswer;
                                    }),
                                  ),
                                ),
                                AnimatedCrossFade(
                                  firstChild: const SizedBox.shrink(),
                                  secondChild: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      '✅ Correct Answer: ${q['correct_label']}. ${q['correct_text']}',
                                      style: const TextStyle(
                                        color: Colors.blueGrey,
                                        fontStyle: FontStyle.italic,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  crossFadeState: showAnswer
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  duration:
                                  const Duration(milliseconds: 250),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aptitude Analytics'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/dashboard'),
        ),
      ),
      body: Stack(
        children: [
          if (loading)
            const Center(child: CircularProgressIndicator())
          else if (error != null)
            Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
          else
            ListView(
              padding: const EdgeInsets.all(16),
              children: disciplines.map((disc) {
                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(disc['discipline'] ?? 'Unnamed Discipline',
                            style: theme.textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _buildSubjects(disc['subjects'] ?? []),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          _buildDrilldownDrawer(),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/session_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final supabase = Supabase.instance.client;
  bool loading = true;
  String? error;

  List<Map<String, dynamic>> active = [];
  List<Map<String, dynamic>> completed = [];

  // Filters
  String activeSortBy = 'date';
  bool activeReverse = true;

  String completedSortBy = 'date';
  bool completedReverse = true;

  // Pagination-like controls
  int activeVisible = 5;
  int completedVisible = 5;
  final int increment = 5;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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

      final userId = session['user_id'];

      final activeData = await supabase.rpc(
        'rpc_fetch_active_assessments',
        params: {'p_user_id': userId},
      );
      final completedData = await supabase.rpc(
        'rpc_fetch_completed_assessments',
        params: {'p_user_id': userId},
      );

      setState(() {
        active = List<Map<String, dynamic>>.from(activeData ?? []);
        completed = List<Map<String, dynamic>>.from(completedData ?? []);
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _sortList(List<Map<String, dynamic>> list, String sortBy, bool reverse) {
    list.sort((a, b) {
      dynamic av, bv;
      switch (sortBy) {
        case 'type':
          av = a['type'] ?? '';
          bv = b['type'] ?? '';
          break;
        case 'score':
          av = (a['score'] ?? 0).toDouble();
          bv = (b['score'] ?? 0).toDouble();
          break;
        default:
          av = DateTime.tryParse(a['assigned_at'] ?? a['completed_at'] ?? '') ??
              DateTime(1970);
          bv = DateTime.tryParse(b['assigned_at'] ?? b['completed_at'] ?? '') ??
              DateTime(1970);
      }
      return reverse ? bv.compareTo(av) : av.compareTo(bv);
    });
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'prompt':
        return Icons.lightbulb_outline;
      case 'short_quiz':
        return Icons.quiz;
      case 'adaptive':
        return Icons.bar_chart;
      case 'mock_exam':
        return Icons.flag;
      default:
        return Icons.assignment;
    }
  }

  // Launch functions (still wired)
  Future<void> _startPrompt() async {
    final session = await SessionService.loadSession();
    if (session == null) return;

    final userId = session['user_id'];
    final orgId = session['orgs'][0]['org_id'];

    final result = await supabase.rpc('rpc_generate_prompt_assessment', params: {
      'p_user_id': userId,
      'p_org_id': orgId,
      'p_title': 'Daily Recall Prompt',
    });

    final instanceId = (result is Map)
        ? result['instance_id']
        : (result is String ? result : result.toString());

    Navigator.pushNamed(context, '/prompt', arguments: {'instance_id': instanceId});
  }

  Future<void> _startShortQuiz() async {
    final session = await SessionService.loadSession();
    if (session == null) return;

    if (session?['orgs'] is String) {
      session!['orgs'] = jsonDecode(session['orgs']);
    }

    final orgs = session?['orgs'] ?? [];
    final orgId = orgs.isNotEmpty ? orgs[0]['org_id'] : null;

    final userId = session['user_id'];

    final result = await supabase.rpc('rpc_generate_standard_assessment',
        params: {
          'p_user_id': userId,
          'p_org_id': orgId,
          'p_total': 10,
          'p_title': 'Short Quiz',
        });

    final instanceId = (result is Map)
        ? result['instance_id']
        : (result is String ? result : result.toString());
    Navigator.pushNamed(context, '/assessment',
        arguments: {'instance_id': instanceId});
  }

  Future<void> _startAdaptiveQuiz() async {
    final session = await SessionService.loadSession();
    if (session == null) return;

    final userId = session['user_id'];
    if (session?['orgs'] is String) {
      session!['orgs'] = jsonDecode(session['orgs']);
    }

    final orgs = session?['orgs'] ?? [];
    final orgId = orgs.isNotEmpty ? orgs[0]['org_id'] : null;

    final result = await supabase.rpc('rpc_generate_adaptive_assessment',
        params: {
          'p_user_id': userId,
          'p_org_id': orgId,
          'p_total': 15,
          'p_title': 'Adaptive Quiz',
        });

    final instanceId = result['instance_id'] ?? result;
    Navigator.pushNamed(context, '/assessment',
        arguments: {'instance_id': instanceId});
  }

  Future<void> _startMockExam() async {
    final session = await SessionService.loadSession();
    if (session == null) return;

    final userId = session['user_id'];
    if (session?['orgs'] is String) {
      session!['orgs'] = jsonDecode(session['orgs']);
    }

    final orgs = session?['orgs'] ?? [];
    final orgId = orgs.isNotEmpty ? orgs[0]['org_id'] : null;

    final result =
    await supabase.rpc('rpc_generate_mock_exam', params: {
      'p_user_id': userId,
      'p_org_id': orgId,
      'p_title': 'Mock Exam',
    });

    final instanceId = result['instance_id'] ?? result;
    Navigator.pushNamed(context, '/assessment',
        arguments: {'instance_id': instanceId});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _sortList(active, activeSortBy, activeReverse);
    _sortList(completed, completedSortBy, completedReverse);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await SessionService.clearSession();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text('Error: $error'))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLaunchButtons(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                'Active Assessments',
                activeSortBy,
                activeReverse,
                    (v) => setState(() => activeSortBy = v),
                    () => setState(() => activeReverse = !activeReverse),
              ),
              ...active.take(activeVisible)
                  .map((a) => _buildAssessmentCard(a, false))
                  .toList(),
              _showMoreLessButton(active, true),

              const SizedBox(height: 24),
              _buildSectionHeader(
                'Completed Assessments',
                completedSortBy,
                completedReverse,
                    (v) => setState(() => completedSortBy = v),
                    () => setState(() => completedReverse = !completedReverse),
              ),
              ...completed.take(completedVisible)
                  .map((a) => _buildAssessmentCard(a, true))
                  .toList(),
              _showMoreLessButton(completed, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchButtons() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Daily Prompt'),
          onPressed: _startPrompt,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.quiz),
          label: const Text('Short Quiz'),
          onPressed: _startShortQuiz,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.bar_chart),
          label: const Text('Adaptive Quiz'),
          onPressed: _startAdaptiveQuiz,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.flag),
          label: const Text('Mock Exam'),
          onPressed: _startMockExam,
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.analytics),
          label: const Text('View Analytics'),
          onPressed: () =>
              Navigator.pushNamed(context, '/analytics_aptitude'),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String sortBy, bool reverse,
      Function(String) onSort, VoidCallback toggleReverse) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style:
            const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Row(
          children: [
            DropdownButton<String>(
              value: sortBy,
              onChanged: (v) {
                if (v != null) onSort(v);
              },
              items: const [
                DropdownMenuItem(value: 'date', child: Text('Date')),
                DropdownMenuItem(value: 'type', child: Text('Type')),
                DropdownMenuItem(value: 'score', child: Text('Score')),
              ],
            ),
            IconButton(
              icon:
              Icon(reverse ? Icons.arrow_downward : Icons.arrow_upward),
              onPressed: toggleReverse,
            )
          ],
        ),
      ],
    );
  }

  Widget _showMoreLessButton(List<Map<String, dynamic>> list, bool isActive) {
    final visible = isActive ? activeVisible : completedVisible;
    final total = list.length;
    final canShowMore = visible < total;

    return Center(
      child: TextButton.icon(
        icon: Icon(canShowMore ? Icons.expand_more : Icons.expand_less),
        label: Text(canShowMore ? 'Show more' : 'Show less'),
        onPressed: () {
          setState(() {
            if (canShowMore) {
              if (isActive) activeVisible += increment;
              else completedVisible += increment;
            } else {
              if (isActive) activeVisible = increment;
              else completedVisible = increment;
            }
          });
        },
      ),
    );
  }

  Widget _buildAssessmentCard(Map<String, dynamic> a, bool completed) {
    final title = a['title'] ?? 'Untitled';
    final type = a['type'] ?? '';
    final date = a['completed_at'] ?? a['assigned_at'] ?? '';
    final score = a['score'];
    final total = a['total_items'];
    final id = a['instance_id'];
    final icon = _iconForType(type);

    final formatted = date.isNotEmpty
        ? DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(date))
        : '—';

    return InkWell(
      onTap: () {
        if (completed) {
          Navigator.pushNamed(context, '/results',
              arguments: {'instance_id': id, 'title': title});
        } else {
          Navigator.pushNamed(context, '/assessment',
              arguments: {'instance_id': id, 'title': title});
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.indigo.shade50,
                child: Icon(icon, color: Colors.indigo),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(formatted,
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              if (score != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: score >= 75
                            ? Colors.green
                            : score >= 50
                            ? Colors.orange
                            : Colors.red,
                      ),
                    ),
                    if (total != null)
                      Text(
                        '${(score / 100 * total).round()}/$total',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
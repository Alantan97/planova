import 'package:flutter/material.dart';

import '../core/time/date_time_helpers.dart';
import '../core/theme/app_theme.dart';

import '../features/today/screens/today_screen.dart';
import '../features/today/view_models/today_view_model.dart';
import '../features/planner/screens/planner_screen.dart';
import '../features/planner/view_models/planner_view_model.dart';
import '../features/tasks/screens/tasks_screen.dart';
import '../features/progress/screens/progress_screen.dart';
import 'app_dependencies.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;
  final _scrollControllers = List.generate(4, (_) => ScrollController());
  late final TodayViewModel _today = TodayViewModel(
    studyRepository: widget.dependencies.study,
    taskRepository: widget.dependencies.tasks,
    clock: widget.dependencies.clock,
  );
  late final PlannerViewModel _planner = PlannerViewModel(
    repository: widget.dependencies.study,
    clock: widget.dependencies.clock,
  );

  @override
  void dispose() {
    _planner.dispose();
    for (final controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _viewPlan() {
    _planner.showToday();
    setState(() => _tab = 2);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.dependencies.tasks,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              key: PageStorageKey('tab-$_tab'),
              controller: _scrollControllers[_tab],
              primary: false,
              slivers: [
                SliverToBoxAdapter(
                  child: _BrandHeader(date: widget.dependencies.clock.now()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: switch (_tab) {
                      0 => TodayScreen(
                        viewModel: _today,
                        onViewPlan: _viewPlan,
                      ),
                      1 => TasksScreen(
                        repository: widget.dependencies.tasks,
                        clock: widget.dependencies.clock,
                        ranking: widget.dependencies.ranking,
                      ),
                      2 => ListenableBuilder(
                        listenable: _planner,
                        builder: (context, _) =>
                            PlannerScreen(viewModel: _planner),
                      ),
                      _ => ProgressScreen(
                        studyRepository: widget.dependencies.study,
                        taskRepository: widget.dependencies.tasks,
                        clock: widget.dependencies.clock,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE6E6E6))),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (index) => setState(() => _tab = index),
          destinations: const [
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: 'Tasks',
            ),
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Plan',
            ),
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: 'Progress',
            ),
          ],
        ),
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.date});
  final DateTime date;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/branding/planova_wordmark_black.png',
              width: 144,
              height: 30,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'Planova logo',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Preview date',
                textAlign: TextAlign.right,
                style: TextStyle(color: planovaMuted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                '${date.day} ${months[date.month - 1]} ${date.year}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: planovaInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

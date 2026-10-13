import 'package:flutter/material.dart';

import '../core/widgets/study_components.dart';
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
  Widget build(BuildContext context) => Scaffold(
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
              const SliverToBoxAdapter(child: _BrandHeader()),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                sliver: SliverToBoxAdapter(
                  child: switch (_tab) {
                    0 => TodayScreen(viewModel: _today, onViewPlan: _viewPlan),
                    1 => TasksScreen(repository: widget.dependencies.tasks),
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
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Progress',
          ),
        ],
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'planova full title black.png',
              width: 190,
              height: 40,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'Planova logo',
            ),
          ),
        ),
        const SizedBox(width: 16),
        const DemoTag('DEMO'),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../core/time/date_time_helpers.dart';
import '../core/theme/app_theme.dart';
import '../core/time/demo_clock.dart';

import '../features/today/screens/today_screen.dart';
import '../features/today/view_models/today_view_model.dart';
import '../features/planner/screens/planner_screen.dart';
import '../features/planner/view_models/planner_view_model.dart';
import '../features/courses/screens/course_overview_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/quick_add/quick_add_sheet.dart';
import '../services/planning/rule_based_planner.dart';
import 'app_dependencies.dart';
import 'widgets/planova_nav_bar.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.dependencies, this.onClearData});
  final AppDependencies dependencies;

  /// Development only: wipes saved data and restarts the app.
  final Future<void> Function()? onClearData;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Tab order in the bottom bar. The "+" beside it is an action, not a tab.
enum _Tab { today, plan, courses, profile }

class _AppShellState extends State<AppShell> {
  _Tab _tab = _Tab.today;
  final _scrollControllers = List.generate(
    _Tab.values.length,
    (_) => ScrollController(),
  );
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
    setState(() => _tab = _Tab.plan);
  }

  static const _navItems = [
    NavItem(
      label: 'Today',
      icon: Icons.wb_sunny_outlined,
      selectedIcon: Icons.wb_sunny_rounded,
    ),
    NavItem(
      label: 'Plan',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
    ),
    NavItem(
      label: 'Courses',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
    ),
    NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  void _openQuickAdd(BuildContext context) => showQuickAddSheet(
    context,
    tasks: widget.dependencies.tasks,
    availability: widget.dependencies.availability,
    clock: widget.dependencies.clock,
    plans: widget.dependencies.plans,
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.dependencies.tasks,
      widget.dependencies.availability,
      widget.dependencies.profile,
      ?widget.dependencies.plans,
    ]),
    builder: (context, _) => Scaffold(
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CustomScrollView(
              key: PageStorageKey('tab-${_tab.name}'),
              controller: _scrollControllers[_tab.index],
              primary: false,
              slivers: [
                SliverToBoxAdapter(
                  child: _TabHeader(
                    title: _navItems[_tab.index].label,
                    date: widget.dependencies.clock.now(),
                    preview: widget.dependencies.clock is DemoClock,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: switch (_tab) {
                      _Tab.today => TodayScreen(
                        viewModel: _today,
                        availability: widget.dependencies.availability,
                        onViewPlan: _viewPlan,
                        plans: widget.dependencies.plans,
                        profile: widget.dependencies.profile,
                      ),
                      _Tab.plan => ListenableBuilder(
                        listenable: Listenable.merge([
                          _planner,
                          widget.dependencies.availability,
                        ]),
                        builder: (context, _) => PlannerScreen(
                          viewModel: _planner,
                          availability: widget.dependencies.availability,
                          tasks: widget.dependencies.tasks,
                          plans: widget.dependencies.plans,
                          settings: PlannerSettings.fromPreferences(
                            widget.dependencies.profile.progress.preferences,
                          ),
                        ),
                      ),
                      _Tab.courses => CourseOverviewScreen(
                        repository: widget.dependencies.tasks,
                        clock: widget.dependencies.clock,
                        ranking: widget.dependencies.ranking,
                      ),
                      _Tab.profile => ProfileScreen(
                        profile: widget.dependencies.profile,
                        auth: widget.dependencies.auth,
                        tasks: widget.dependencies.tasks,
                        availability: widget.dependencies.availability,
                        clock: widget.dependencies.clock,
                        onClearData: widget.onClearData,
                      ),
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PlanovaNavBar(
        items: _navItems,
        selectedIndex: _tab.index,
        onSelect: (index) => setState(() => _tab = _Tab.values[index]),
        onAdd: () => _openQuickAdd(context),
      ),
    ),
  );
}

/// Top of every tab: the tab's name in bold, plus the fixed date in the
/// demo build.
class _TabHeader extends StatelessWidget {
  const _TabHeader({
    required this.title,
    required this.date,
    required this.preview,
  });
  final String title;
  final DateTime date;

  /// Only the demo build uses a fixed date; the real app shows none here
  /// because Today already shows the real date.
  final bool preview;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            // Very large text sizes shrink the name instead of cutting it.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: const TextStyle(
                  color: planovaInk,
                  fontSize: 32,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ),
        ),
        if (preview) ...[
          const SizedBox(width: 12),
          Flexible(
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
      ],
    ),
  );
}

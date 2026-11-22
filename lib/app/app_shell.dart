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
import 'app_dependencies.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<AppShell> createState() => _AppShellState();
}

/// Tab order. The centre slot of the bar is the "+" button, not a tab.
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

  static const _addSlot = 2;
  static int _barIndex(_Tab tab) =>
      tab.index < _addSlot ? tab.index : tab.index + 1;
  static _Tab _tabAt(int index) =>
      _Tab.values[index < _addSlot ? index : index - 1];

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
                  child: _BrandHeader(
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
          selectedIndex: _barIndex(_tab),
          onDestinationSelected: (index) {
            if (index == _addSlot) {
              _openQuickAdd(context);
            } else {
              setState(() => _tab = _tabAt(index));
            }
          },
          destinations: const [
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.wb_sunny_outlined),
              selectedIcon: Icon(Icons.wb_sunny_rounded),
              label: 'Today',
            ),
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Plan',
            ),
            NavigationDestination(
              key: ValueKey('quick-add'),
              tooltip: '',
              icon: _AddIcon(),
              label: 'Add',
            ),
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Courses',
            ),
            NavigationDestination(
              tooltip: '',
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    ),
  );
}

/// The centre "+": a filled orange circle so it reads as an action, not a tab.
class _AddIcon extends StatelessWidget {
  const _AddIcon();
  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 32,
    decoration: BoxDecoration(
      color: planovaActionOrange,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Icon(Icons.add_rounded, color: planovaOnOrange),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.date, required this.preview});
  final DateTime date;

  /// Only the demo build uses a fixed date; the real app shows none here
  /// because Today already shows the real date.
  final bool preview;
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
        if (preview) ...[
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
      ],
    ),
  );
}

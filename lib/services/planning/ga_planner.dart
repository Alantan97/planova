import 'dart:math' as math;

import '../../models/academic_task.dart';
import '../../models/study_session.dart';
import '../../models/weekly_availability.dart';
import 'free_study_slots.dart';
import 'rule_based_planner.dart';

/// The "balanced" planner: a Genetic Algorithm (GA) that searches for a
/// more even week than the rule-based planner, without missing more work.
///
/// A GA is a search method, not trained AI. It keeps a population of valid
/// candidate plans, scores each one with a fixed goal, and breeds better ones
/// by recombining and slightly changing the best. The same inputs and seed
/// always give the same plan.
///
/// This is a line-for-line copy of the evaluated Python version
/// (ai/planova_scheduling/ga.py, objective.py, rng.py). Tests check that it
/// reproduces the Python plans exactly (ai/scenarios/expected_ga/), so the
/// app runs the GA that docs/scheduling_evaluation.md reports on.
///
/// Goal, in order of importance ("deadline-safe even spread"): no due work
/// left unplaced, finish each task [PlanGoalWeights.bufferHours] early,
/// spread study evenly across usable days, prefer fewer sessions.
///
/// Every plan keeps the same hard rules as [planWeek]: free study time only,
/// no overlaps, breaks inside a free period, daily and per-task-per-day
/// limits, days off, session lengths, never past a deadline. The rule-based
/// plan is part of the first population, so the result is never worse than
/// it on the goal.
BalancedPlanResult planWeekBalanced({
  required List<AcademicTask> tasks,
  required WeeklyAvailability availability,
  required DateTime now,
  PlannerSettings settings = const PlannerSettings(),
  int seed = 0,
  BalancedPlannerConfig config = const BalancedPlannerConfig(),
  PlanGoalWeights weights = const PlanGoalWeights(),
}) {
  final ctx = _Context(tasks, availability, now, settings);
  final decoder = _Decoder(ctx);
  final rng = PlanRng(seed);
  final n = decoder.turns.length;
  final usable = decoder.offsets;
  final cache = <String, _Evaluated>{};

  _Evaluated fitness(_Individual ind) =>
      cache.putIfAbsent('${ind.order.join(',')}|${ind.days.join(',')}', () {
        final sessions = decoder.decode(ind.order, ind.days);
        return _Evaluated(sessions, _evaluate(ctx, sessions, weights));
      });

  _Individual randomIndividual() {
    final order = List<int>.generate(n, (i) => i);
    rng.shuffle(order);
    final days = [
      for (var i = 0; i < n; i++) usable.isNotEmpty ? rng.choice(usable) : 0,
    ];
    return _Individual(order, days);
  }

  var population = [
    for (var i = 0; i < config.population; i++) randomIndividual(),
  ];
  if (config.startFromBaseline && population.isNotEmpty) {
    population[0] = decoder.encode(
      planWeek(
        tasks: tasks,
        availability: availability,
        now: now,
        settings: settings,
      ),
    );
  }

  final dayRate = n > 0 ? 2 / n : 0.0;
  for (var generation = 0; generation < config.generations; generation++) {
    final values = [for (final ind in population) fitness(ind).score.total];
    // Stable ranking: equal values keep population order.
    final ranked = List<int>.generate(population.length, (i) => i)
      ..sort((a, b) {
        final c = values[a].compareTo(values[b]);
        return c != 0 ? c : a.compareTo(b);
      });
    final next = [
      for (final i in ranked.take(config.elite)) population[i].copy(),
    ];

    _Individual pick() {
      final group = rng.sampleIndices(
        population.length,
        math.min(config.tournament, population.length),
      );
      return population[_bestIndex(values, group)];
    }

    while (next.length < config.population) {
      final p1 = pick();
      final p2 = pick();
      List<int> order;
      List<int> days;
      if (rng.random() < config.crossoverRate) {
        order = _orderCrossover(rng, p1.order, p2.order);
        days = [
          for (var g = 0; g < n; g++)
            rng.random() < 0.5 ? p1.days[g] : p2.days[g],
        ];
      } else {
        order = [...p1.order];
        days = [...p1.days];
      }
      if (n >= 2 && rng.random() < config.swapRate) {
        final ij = rng.sampleIndices(n, 2);
        final keep = order[ij[0]];
        order[ij[0]] = order[ij[1]];
        order[ij[1]] = keep;
      }
      for (var g = 0; g < n; g++) {
        if (usable.isNotEmpty && rng.random() < dayRate) {
          if (rng.random() < 0.7) {
            final int step = rng.choice(const [-1, 1]);
            final moved = days[g] + step;
            days[g] = math.min<int>(
              math.max<int>(moved, usable.first),
              usable.last,
            );
          } else {
            days[g] = rng.choice(usable);
          }
        }
      }
      next.add(_Individual(order, days));
    }
    population = next;
  }

  final values = [for (final ind in population) fitness(ind).score.total];
  final best = fitness(
    population[_bestIndex(
      values,
      List<int>.generate(population.length, (i) => i),
    )],
  );
  return BalancedPlanResult(decoder.toProposal(best.sessions), best.score);
}

/// GA settings. The defaults were chosen on development test weeks only
/// (see docs/scheduling_evaluation.md) and are what the app uses.
class BalancedPlannerConfig {
  const BalancedPlannerConfig({
    this.population = 40,
    this.generations = 120,
    this.tournament = 3,
    this.crossoverRate = 0.9,
    this.swapRate = 0.3,
    this.elite = 2,
    this.startFromBaseline = true,
  });
  final int population;
  final int generations;
  final int tournament;
  final double crossoverRate;
  final double swapRate;
  final int elite;
  final bool startFromBaseline;
}

/// How much each part of the goal costs. Each level matters far more than
/// the next; the numbers are a design choice, not a fact.
class PlanGoalWeights {
  const PlanGoalWeights({
    this.missedPerMinute = 1000.0,
    this.bufferPerMinute = 20.0,
    this.spreadPerMinuteStd = 5.0,
    this.perSession = 10.0,
    this.laterUnplacedPerMinute = 2.0,
    this.bufferHours = 24,
  });
  final double missedPerMinute;
  final double bufferPerMinute;
  final double spreadPerMinuteStd;
  final double perSession;
  final double laterUnplacedPerMinute;
  final int bufferHours;
}

/// A plan's score on the goal (lower [total] is better) and its parts.
class PlanGoalScore {
  const PlanGoalScore({
    required this.total,
    required this.missedMinutes,
    required this.bufferMinutes,
    required this.daySpreadMinutes,
    required this.sessions,
    required this.laterUnplacedMinutes,
  });
  final double total;

  /// Work due inside the plan period that is not placed.
  final int missedMinutes;

  /// Minutes in sessions ending less than the buffer before the deadline.
  final int bufferMinutes;

  /// Standard deviation of study minutes per usable day (lower is more even).
  final double daySpreadMinutes;
  final int sessions;
  final int laterUnplacedMinutes;
}

class BalancedPlanResult {
  const BalancedPlanResult(this.proposal, this.score);
  final PlanProposal proposal;
  final PlanGoalScore score;
}

/// Scores any plan (for example the rule-based one) on the same goal.
PlanGoalScore scorePlanGoal({
  required PlanProposal proposal,
  required List<AcademicTask> tasks,
  required WeeklyAvailability availability,
  required DateTime now,
  PlannerSettings settings = const PlannerSettings(),
  PlanGoalWeights weights = const PlanGoalWeights(),
}) {
  final ctx = _Context(tasks, availability, now, settings);
  return _evaluate(ctx, [
    for (final s in proposal.sessions)
      (s.taskId!, ctx.minutesOf(s.startsAt), s.minutes),
  ], weights);
}

// ------------------------------------------------------------------ random

/// xorshift32, identical to ai/planova_scheduling/rng.py. Only shifts, XORs
/// and 32-bit masks, so results match in Python, the Dart VM and the web.
class PlanRng {
  PlanRng(int seed) {
    final state = (seed ^ 0x9E3779B9) & _mask;
    _state = state == 0 ? 1 : state;
    for (var i = 0; i < 8; i++) {
      nextU32();
    }
  }
  static const _mask = 0xFFFFFFFF;
  late int _state;

  int nextU32() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x;
    return x;
  }

  /// A double in [0, 1).
  double random() => nextU32() / 4294967296.0;

  /// An integer in [0, n).
  int below(int n) => nextU32() % n;

  T choice<T>(List<T> items) => items[below(items.length)];

  /// Fisher-Yates, from the end.
  void shuffle(List<Object?> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = below(i + 1);
      final keep = items[i];
      items[i] = items[j];
      items[j] = keep;
    }
  }

  /// [k] distinct indices from 0..n-1, in draw order.
  List<int> sampleIndices(int n, int k) {
    final pool = List<int>.generate(n, (i) => i);
    for (var t = 0; t < k; t++) {
      final j = t + below(n - t);
      final keep = pool[t];
      pool[t] = pool[j];
      pool[j] = keep;
    }
    return pool.sublist(0, k);
  }
}

// ------------------------------------------------------------------ goal

typedef _Session = (String taskId, int start, int minutes);

/// Population standard deviation, step by step exactly like the Python copy.
double _plainStd(List<int> values) {
  if (values.isEmpty) return 0.0;
  final mean = values.fold(0, (a, b) => a + b) / values.length;
  var total = 0.0;
  for (final v in values) {
    final d = v - mean;
    total += d * d;
  }
  return math.sqrt(total / values.length);
}

PlanGoalScore _evaluate(
  _Context ctx,
  List<_Session> sessions,
  PlanGoalWeights weights,
) {
  final placed = <String, int>{};
  final perDay = <int, int>{};
  final buffer = weights.bufferHours * 60;
  var inBuffer = 0;
  var count = 0;
  for (final (taskId, start, minutes) in sessions) {
    count++;
    placed[taskId] = (placed[taskId] ?? 0) + minutes;
    final day = start ~/ 1440;
    perDay[day] = (perDay[day] ?? 0) + minutes;
    if (ctx.due[taskId]! - (start + minutes) < buffer) inBuffer += minutes;
  }
  var missed = 0;
  for (final t in ctx.dueInPeriod) {
    final left = ctx.remaining[t]!;
    missed += left - math.min(placed[t] ?? 0, left);
  }
  var later = 0;
  for (final t in ctx.later) {
    later += ctx.remaining[t]! - (placed[t] ?? 0);
  }
  final spread = _plainStd([for (final d in ctx.days) perDay[d.offset] ?? 0]);
  final total =
      weights.missedPerMinute * missed +
      weights.bufferPerMinute * inBuffer +
      weights.spreadPerMinuteStd * spread +
      weights.perSession * count +
      weights.laterUnplacedPerMinute * later;
  return PlanGoalScore(
    total: total,
    missedMinutes: missed,
    bufferMinutes: inBuffer,
    daySpreadMinutes: spread,
    sessions: count,
    laterUnplacedMinutes: later,
  );
}

// ------------------------------------------------------------------ context

class _Day {
  const _Day(this.offset, this.slots);

  /// Days after the plan's first day.
  final int offset;

  /// Free periods in whole minutes from midnight of the first day.
  final List<(int, int)> slots;
}

/// Facts about one planning request, in whole minutes from midnight of the
/// plan's first day.
class _Context {
  _Context(
    this.allTasks,
    WeeklyAvailability availability,
    this.now,
    this.settings,
  ) : firstDay = DateTime(now.year, now.month, now.day),
      hasWindows = availability.windows.isNotEmpty {
    start = minutesOf(planStartFor(now));
    end = settings.horizonDays * 1440;
    for (final task in allTasks) {
      if (task.isCompleted) continue;
      final left = task.estimatedMinutes - task.completedMinutes;
      if (left <= 0) continue;
      final deadline = task.deadline;
      if (deadline == null) {
        needsInput.add(UnplacedWork(task, left, UnplacedReason.needsDueDate));
      } else if (!deadline.isAfter(now)) {
        needsInput.add(UnplacedWork(task, left, UnplacedReason.overdue));
      } else {
        eligible.add(task);
      }
    }
    eligible.sort(comparePlanningPriority);
    for (final t in eligible) {
      due[t.id] = minutesOf(t.deadline!);
      remaining[t.id] = t.estimatedMinutes - t.completedMinutes;
      (due[t.id]! < end ? dueInPeriod : later).add(t.id);
    }
    final slots = freeStudySlots(availability);
    for (var d = 0; d < settings.horizonDays; d++) {
      final weekday = DateTime(
        firstDay.year,
        firstDay.month,
        firstDay.day + d,
      ).weekday;
      if (settings.daysOff.contains(weekday)) continue;
      final free = <(int, int)>[];
      for (final slot in slots) {
        if (slot.weekday != weekday) continue;
        final a = math.max(d * 1440 + slot.startMinute, start);
        final b = d * 1440 + slot.endMinute;
        if (a < b) free.add((a, b));
      }
      if (free.isNotEmpty) days.add(_Day(d, free));
    }
  }

  final List<AcademicTask> allTasks;
  final DateTime now;
  final PlannerSettings settings;
  final DateTime firstDay;
  final bool hasWindows;
  late final int start;
  late final int end;
  final eligible = <AcademicTask>[];
  final needsInput = <UnplacedWork>[];
  final due = <String, int>{};
  final remaining = <String, int>{};
  final dueInPeriod = <String>[];
  final later = <String>[];
  final days = <_Day>[];

  /// Calendar arithmetic, so daylight-saving changes cannot shift minutes.
  int minutesOf(DateTime t) {
    final days = DateTime.utc(
      t.year,
      t.month,
      t.day,
    ).difference(DateTime.utc(firstDay.year, firstDay.month, firstDay.day));
    return days.inDays * 1440 + t.hour * 60 + t.minute;
  }

  DateTime timeAt(int minutes) => DateTime(
    firstDay.year,
    firstDay.month,
    firstDay.day + minutes ~/ 1440,
    (minutes % 1440) ~/ 60,
    minutes % 60,
  );
}

// ------------------------------------------------------------------ decoder

class _Individual {
  _Individual(this.order, this.days);
  final List<int> order;
  final List<int> days;
  _Individual copy() => _Individual([...order], [...days]);
}

class _Evaluated {
  const _Evaluated(this.sessions, this.score);
  final List<_Session> sessions;
  final PlanGoalScore score;
}

class _State {
  _State(_Context ctx, List<String> priority)
    : slots = [
        for (final day in ctx.days) [for (final _ in day.slots) <(int, int)>[]],
      ],
      dayUsed = List<int>.filled(ctx.days.length, 0),
      placed = {for (final t in priority) t: 0},
      lastEnd = {for (final t in priority) t: 0};
  final List<List<List<(int, int)>>> slots;
  final List<int> dayUsed;
  final taskDay = <String, int>{};
  final Map<String, int> placed;
  final Map<String, int> lastEnd;
  final sessions = <_Session>[];
}

/// Turns a chromosome (order of turns + preferred day per turn) into a valid
/// plan. See the Python docstring in ga.py for the full description.
class _Decoder {
  _Decoder(this.ctx) : s = ctx.settings {
    priority = [for (final t in ctx.eligible) t.id];
    for (final task in ctx.eligible) {
      final count =
          (ctx.remaining[task.id]! + s.minSessionMinutes - 1) ~/
          s.minSessionMinutes;
      for (var i = 0; i < count; i++) {
        turns.add(task.id);
      }
    }
    offsets = [for (final d in ctx.days) d.offset];
    for (final t in priority) {
      daysFor[t] = [
        for (var i = 0; i < ctx.days.length; i++)
          if (ctx.days[i].slots.first.$1 < ctx.due[t]!) i,
      ];
    }
  }

  final _Context ctx;
  final PlannerSettings s;
  late final List<String> priority;
  final turns = <String>[];
  late final List<int> offsets;
  final daysFor = <String, List<int>>{};

  int _tryDay(_State st, String task, int i, int want, int need, int after) {
    final due = ctx.due[task]!;
    final cap = [
      want,
      s.dailyLimitMinutes - st.dayUsed[i],
      s.perTaskDailyMinutes - (st.taskDay['$task|$i'] ?? 0),
    ].reduce(math.min);
    if (cap < need || cap <= 0) return 0;
    final brk = s.breakMinutes;
    final daySlots = ctx.days[i].slots;
    for (var k = 0; k < daySlots.length; k++) {
      final (a, b) = daySlots[k];
      final booked = st.slots[i][k];
      final candidates = {
        for (final x in [a, for (final (_, end) in booked) end + brk])
          [x, after, a].reduce(math.max),
      }.toList()..sort();
      for (final c in candidates) {
        // Sessions in the same free period need a break between them.
        if (booked.any((x) => (x.$1 < c && c < x.$2 + brk) || x.$1 == c)) {
          continue;
        }
        final limit = [
          b,
          due,
          for (final (start, _) in booked)
            if (start > c) start - brk,
        ].reduce(math.min);
        final length = math.min(cap, limit - c);
        if (length >= need && length > 0) {
          booked
            ..add((c, c + length))
            ..sort((x, y) => x.$1.compareTo(y.$1));
          st.dayUsed[i] += length;
          st.taskDay['$task|$i'] = (st.taskDay['$task|$i'] ?? 0) + length;
          st.placed[task] = st.placed[task]! + length;
          st.lastEnd[task] = math.max(st.lastEnd[task]!, c + length);
          st.sessions.add((task, c, length));
          return length;
        }
      }
    }
    return 0;
  }

  int _turn(_State st, String task, List<int> dayOrder) {
    final left = ctx.remaining[task]! - st.placed[task]!;
    if (left <= 0) return 0;
    final int want, need, after;
    if (left < s.minSessionMinutes) {
      // A piece shorter than the minimum must be the task's last session.
      (want, need, after) = (left, left, st.lastEnd[task]!);
    } else {
      (want, need, after) = (
        math.min(left, s.maxSessionMinutes),
        s.minSessionMinutes,
        0,
      );
    }
    for (final i in dayOrder) {
      final got = _tryDay(st, task, i, want, need, after);
      if (got > 0) return got;
    }
    return 0;
  }

  List<int> _nearest(String task, int preferred) {
    int offset(int i) => ctx.days[i].offset;
    return [...daysFor[task]!]..sort((x, y) {
      final c = (offset(x) - preferred).abs().compareTo(
        (offset(y) - preferred).abs(),
      );
      return c != 0 ? c : offset(x).compareTo(offset(y));
    });
  }

  List<_Session> decode(List<int> order, List<int> days) {
    final st = _State(ctx, priority);
    for (final gene in order) {
      final task = turns[gene];
      _turn(st, task, _nearest(task, days[gene]));
    }
    for (final task in priority) {
      while (_turn(st, task, daysFor[task]!) > 0) {}
    }
    return st.sessions;
  }

  /// The chromosome whose decoding is [proposal] (the rule-based plan).
  _Individual encode(PlanProposal proposal) {
    final free = {
      for (final t in priority)
        t: [
          for (var g = 0; g < turns.length; g++)
            if (turns[g] == t) g,
        ],
    };
    final order = <int>[];
    final days = List<int>.filled(
      turns.length,
      offsets.isNotEmpty ? offsets.first : 0,
    );
    final sessions = [...proposal.sessions]
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    for (final session in sessions) {
      final gene = free[session.taskId]!.removeAt(0);
      order.add(gene);
      days[gene] = ctx.minutesOf(session.startsAt) ~/ 1440;
    }
    for (final t in priority) {
      order.addAll(free[t]!);
    }
    return _Individual(order, days);
  }

  PlanProposal toProposal(List<_Session> sessions) {
    final ordered = [...sessions]
      ..sort((x, y) {
        final c = x.$2.compareTo(y.$2);
        return c != 0 ? c : x.$1.compareTo(y.$1);
      });
    final byId = {for (final t in ctx.eligible) t.id: t};
    final placed = <String, int>{};
    for (final (task, _, minutes) in ordered) {
      placed[task] = (placed[task] ?? 0) + minutes;
    }
    final unplaced = [...ctx.needsInput];
    for (final task in ctx.eligible) {
      final left = ctx.remaining[task.id]! - (placed[task.id] ?? 0);
      if (left <= 0) continue;
      unplaced.add(
        UnplacedWork(
          task,
          left,
          ctx.due[task.id]! < ctx.end
              ? UnplacedReason.notEnoughTimeBeforeDue
              : UnplacedReason.continuesLater,
        ),
      );
    }
    unplaced.sort((a, b) {
      final reason = a.reason.index.compareTo(b.reason.index);
      return reason != 0 ? reason : comparePlanningPriority(a.task, b.task);
    });
    return PlanProposal(
      from: ctx.timeAt(ctx.start),
      to: ctx.timeAt(ctx.end),
      sessions: [
        for (final (taskId, start, minutes) in ordered)
          StudySession(
            id: planSessionId(ctx.timeAt(start), taskId),
            taskId: taskId,
            title: byId[taskId]!.title,
            subject: byId[taskId]!.subject,
            startsAt: ctx.timeAt(start),
            minutes: minutes,
          ),
      ],
      unplaced: unplaced,
      hasAvailability: ctx.hasWindows,
    );
  }
}

List<int> _orderCrossover(PlanRng rng, List<int> a, List<int> b) {
  final n = a.length;
  if (n < 2) return [...a];
  final ij = rng.sampleIndices(n, 2)..sort();
  final middle = a.sublist(ij[0], ij[1] + 1);
  final taken = middle.toSet();
  final rest = [
    for (final g in b)
      if (!taken.contains(g)) g,
  ];
  return [...rest.sublist(0, ij[0]), ...middle, ...rest.sublist(ij[0])];
}

/// The index with the lowest value; the first one on ties.
int _bestIndex(List<double> values, List<int> indices) {
  int? best;
  for (final i in indices) {
    if (best == null || values[i] < values[best]) best = i;
  }
  return best!;
}

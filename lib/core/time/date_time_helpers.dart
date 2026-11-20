const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const fullWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

DateTime startOfWeek(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);
String formatDuration(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final remainder = minutes % 60;
  return '${minutes ~/ 60}h${remainder == 0 ? '' : ' ${remainder}m'}';
}

/// 570 → "09:30"; 1440 → "24:00".
String formatClock(int minuteOfDay) =>
    '${(minuteOfDay ~/ 60).toString().padLeft(2, '0')}:'
    '${(minuteOfDay % 60).toString().padLeft(2, '0')}';

/// Weekday numbers (Monday = 1) as a short label: "Mon, Wed", "Weekdays".
String formatWeekdays(List<int> days) {
  final sorted = [...days]..sort();
  final key = sorted.join();
  if (key == '1234567') return 'Every day';
  if (key == '12345') return 'Weekdays';
  if (key == '67') return 'Weekends';
  return sorted.map((day) => weekdays[day - 1]).join(', ');
}

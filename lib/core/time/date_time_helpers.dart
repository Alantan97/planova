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

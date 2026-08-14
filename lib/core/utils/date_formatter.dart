import 'package:intl/intl.dart';

class DateFormatter {
  static final _dateTime = DateFormat('MMM d, yyyy • h:mm a');
  static final _date = DateFormat('MMM d, yyyy');
  static final _time = DateFormat('h:mm a');

  static String dateTime(DateTime dt) => _dateTime.format(dt);
  static String date(DateTime dt) => _date.format(dt);
  static String time(DateTime dt) => _time.format(dt);
}

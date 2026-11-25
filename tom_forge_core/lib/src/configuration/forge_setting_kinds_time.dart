import 'forge_configuration_texts.dart';
import 'forge_setting.dart';
import 'forge_setting_kinds.dart';
import 'forge_text.dart';

String _two(int n) => n.toString().padLeft(2, '0');

String _four(int n) => n.toString().padLeft(4, '0');

/// A calendar date as const data (a description's default and bounds are
/// constants; `DateTime` is not). [ForgeDate.none] is no date.
///
/// Stored as `YYYY-MM-DD`; no date as `""`.
class ForgeDate implements Comparable<ForgeDate> {
  const ForgeDate(this.year, this.month, this.day);

  /// [value]'s year, month and day.
  ForgeDate.fromDateTime(DateTime value)
    : year = value.year,
      month = value.month,
      day = value.day;

  /// No date.
  static const none = ForgeDate(0, 0, 0);

  final int year;

  /// 1..12.
  final int month;

  /// 1..31.
  final int day;

  /// Whether this is no date.
  bool get isNone => year == 0 && month == 0 && day == 0;

  /// Whether it names a day of the calendar (not [none], not 31 February).
  bool get isValid {
    if (isNone || month < 1 || month > 12 || day < 1) return false;
    final date = DateTime(year, month, day);
    return date.year == year && date.month == month && date.day == day;
  }

  /// Midnight (local) of the day.
  DateTime toDateTime() => DateTime(year, month, day);

  /// `YYYY-MM-DD`; `""` for [none].
  String toText() => isNone ? '' : '${_four(year)}-${_two(month)}-${_two(day)}';

  /// `YYYY-MM-DD` as a date (`""`: [none]), or null when it is none.
  static ForgeDate? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return none;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (match == null) return null;
    final date = ForgeDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
    return date.isValid ? date : null;
  }

  @override
  int compareTo(ForgeDate other) {
    final byYear = year.compareTo(other.year);
    if (byYear != 0) return byYear;
    final byMonth = month.compareTo(other.month);
    return byMonth != 0 ? byMonth : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is ForgeDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => isNone ? 'ForgeDate.none' : toText();
}

/// A time of day, hours and minutes, as data (Flutter's `TimeOfDay` without
/// Flutter). Stored as `HH:MM` (24 hours).
class ForgeTimeOfDay implements Comparable<ForgeTimeOfDay> {
  const ForgeTimeOfDay(this.hour, this.minute);

  /// 0..23.
  final int hour;

  /// 0..59.
  final int minute;

  /// Whether hour and minute are in range.
  bool get isValid => hour >= 0 && hour < 24 && minute >= 0 && minute < 60;

  /// Minutes since midnight.
  int get minutesOfDay => hour * 60 + minute;

  /// `HH:MM`.
  String toText() => '${_two(hour)}:${_two(minute)}';

  /// `H:MM` or `HH:MM` as a time, or null.
  static ForgeTimeOfDay? parse(String text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final time = ForgeTimeOfDay(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
    return time.isValid ? time : null;
  }

  @override
  int compareTo(ForgeTimeOfDay other) =>
      minutesOfDay.compareTo(other.minutesOfDay);

  @override
  bool operator ==(Object other) =>
      other is ForgeTimeOfDay && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => toText();
}

/// A point in time as const data: a [date], a [time] and a [second], in
/// local time or, with [utc], in UTC. [ForgeDateTime.none] is no point in
/// time.
///
/// Stored as ISO 8601 to the second (`2026-11-25T14:30:00`, with `Z` when
/// [utc]); none as `""`.
class ForgeDateTime implements Comparable<ForgeDateTime> {
  const ForgeDateTime(
    this.date,
    this.time, {
    this.second = 0,
    this.utc = false,
  });

  /// [value] to the second, in its own zone (UTC or local).
  ForgeDateTime.fromDateTime(DateTime value)
    : date = ForgeDate.fromDateTime(value),
      time = ForgeTimeOfDay(value.hour, value.minute),
      second = value.second,
      utc = value.isUtc;

  /// No point in time.
  static const none = ForgeDateTime(ForgeDate.none, ForgeTimeOfDay(0, 0));

  final ForgeDate date;
  final ForgeTimeOfDay time;

  /// 0..59.
  final int second;

  /// Whether it is a UTC time (else local).
  final bool utc;

  bool get isNone => date.isNone;

  /// Whether date, time and second are in range.
  bool get isValid =>
      date.isValid && time.isValid && second >= 0 && second < 60;

  /// The `DateTime` (UTC or local).
  DateTime toDateTime() => utc
      ? DateTime.utc(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          second,
        )
      : DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
          second,
        );

  /// The same moment in UTC ([toUtc]: true) or local time.
  ForgeDateTime inZone({required bool toUtc}) {
    if (isNone || utc == toUtc) return this;
    final moment = toDateTime();
    return ForgeDateTime.fromDateTime(
      toUtc ? moment.toUtc() : moment.toLocal(),
    );
  }

  /// ISO 8601 to the second; `""` for [none].
  String toText() {
    if (isNone) return '';
    final text = '${date.toText()}T${time.toText()}:${_two(second)}';
    return utc ? '${text}Z' : text;
  }

  /// ISO 8601 text as a point in time (`""`: [none]), or null. A text with
  /// `Z` or an offset is a UTC time; without, a local one.
  static ForgeDateTime? parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return none;
    final parsed = DateTime.tryParse(trimmed);
    return parsed == null ? null : ForgeDateTime.fromDateTime(parsed);
  }

  @override
  int compareTo(ForgeDateTime other) =>
      toDateTime().compareTo(other.toDateTime());

  @override
  bool operator ==(Object other) =>
      other is ForgeDateTime &&
      other.date == date &&
      other.time == time &&
      other.second == second &&
      other.utc == utc;

  @override
  int get hashCode => Object.hash(date, time, second, utc);

  @override
  String toString() => isNone ? 'ForgeDateTime.none' : toText();
}

/// A calendar date between [first] and [last] (inclusive, when given),
/// picked with a date picker; [ForgeDate.none] is no date (when
/// [allowNone]). Stored as `YYYY-MM-DD`, no date as `""`.
class ForgeDateSetting extends ForgeSetting<ForgeDate> {
  const ForgeDateSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = ForgeDate.none,
    this.first,
    this.last,
    this.allowNone = true,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The earliest date allowed, or null.
  final ForgeDate? first;

  /// The latest date allowed, or null.
  final ForgeDate? last;

  /// Whether no date is a value.
  final bool allowNone;

  @override
  String get kind => ForgeSettingKinds.date;

  @override
  ForgeDate? decode(Object? stored) {
    if (stored is ForgeDate) return stored;
    if (stored is DateTime) return ForgeDate.fromDateTime(stored);
    if (stored is String) return ForgeDate.parse(stored);
    return null;
  }

  @override
  Object? encode(ForgeDate value) => value.toText();

  @override
  ForgeText? validate(ForgeDate value) {
    if (value.isNone) {
      return allowNone ? null : ForgeConfigurationTexts.required;
    }
    if (!value.isValid) return ForgeConfigurationTexts.wrongType;
    if (first != null && value.compareTo(first!) < 0) {
      return ForgeConfigurationTexts.notBefore(first!.toText());
    }
    if (last != null && value.compareTo(last!) > 0) {
      return ForgeConfigurationTexts.notAfter(last!.toText());
    }
    return null;
  }
}

/// A time of day between [earliest] and [latest] (inclusive, when given),
/// picked with a time picker; stored as `HH:MM`.
class ForgeTimeSetting extends ForgeSetting<ForgeTimeOfDay> {
  const ForgeTimeSetting({
    required super.id,
    required super.storage,
    required super.label,
    required super.defaultValue,
    this.earliest,
    this.latest,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The earliest time allowed, or null.
  final ForgeTimeOfDay? earliest;

  /// The latest time allowed, or null.
  final ForgeTimeOfDay? latest;

  @override
  String get kind => ForgeSettingKinds.time;

  @override
  ForgeTimeOfDay? decode(Object? stored) {
    if (stored is ForgeTimeOfDay) return stored;
    if (stored is String) return ForgeTimeOfDay.parse(stored);
    return null;
  }

  @override
  Object? encode(ForgeTimeOfDay value) => value.toText();

  @override
  ForgeText? validate(ForgeTimeOfDay value) {
    if (!value.isValid) return ForgeConfigurationTexts.wrongType;
    if (earliest != null && value.compareTo(earliest!) < 0) {
      return ForgeConfigurationTexts.notBefore(earliest!.toText());
    }
    if (latest != null && value.compareTo(latest!) > 0) {
      return ForgeConfigurationTexts.notAfter(latest!.toText());
    }
    return null;
  }
}

/// A point in time between [first] and [last] (inclusive, when given),
/// picked as a date and a time; [ForgeDateTime.none] is none (when
/// [allowNone]). Kept in local time, or with [utc] in UTC (a value read or
/// typed in the other zone is converted). Stored as ISO 8601 to the second
/// (`2026-11-25T14:30:00`, `...Z` when [utc]); none as `""`.
class ForgeDateTimeSetting extends ForgeSetting<ForgeDateTime> {
  const ForgeDateTimeSetting({
    required super.id,
    required super.storage,
    required super.label,
    super.defaultValue = ForgeDateTime.none,
    this.first,
    this.last,
    this.utc = false,
    this.allowNone = true,
    super.help,
    super.visibleWhen,
    super.enabledWhen,
    super.actions,
  });

  /// The earliest point in time allowed, or null.
  final ForgeDateTime? first;

  /// The latest point in time allowed, or null.
  final ForgeDateTime? last;

  /// Whether the value is kept in UTC (else local time).
  final bool utc;

  /// Whether none is a value.
  final bool allowNone;

  @override
  String get kind => ForgeSettingKinds.dateTime;

  @override
  ForgeDateTime? decode(Object? stored) {
    ForgeDateTime? value;
    if (stored is ForgeDateTime) value = stored;
    if (stored is DateTime) value = ForgeDateTime.fromDateTime(stored);
    if (stored is String) value = ForgeDateTime.parse(stored);
    if (value == null || value.isNone || !value.isValid) return value;
    return value.inZone(toUtc: utc);
  }

  @override
  Object? encode(ForgeDateTime value) => value.toText();

  @override
  ForgeText? validate(ForgeDateTime value) {
    if (value.isNone) {
      return allowNone ? null : ForgeConfigurationTexts.required;
    }
    if (!value.isValid) return ForgeConfigurationTexts.wrongType;
    if (first != null && value.compareTo(first!) < 0) {
      return ForgeConfigurationTexts.notBefore(first!.toText());
    }
    if (last != null && value.compareTo(last!) > 0) {
      return ForgeConfigurationTexts.notAfter(last!.toText());
    }
    return null;
  }
}

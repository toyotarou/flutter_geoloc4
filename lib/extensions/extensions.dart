import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

///
extension ContextEx on BuildContext {
  TextTheme get textTheme => Theme.of(this).textTheme;

  ColorScheme get colorTheme => Theme.of(this).colorScheme;

  Size get screenSize => MediaQuery.of(this).size;
}

/// DateFormat / NumberFormat / RegExp は生成コストが高いので使い回す（初回アクセス時に1度だけ生成）
/// カレンダー表示などで1画面あたり数百回呼ばれるため効果が大きい
final DateFormat _yyyymmddFormat = DateFormat('yyyy-MM-dd');
final DateFormat _yyyymmFormat = DateFormat('yyyy-MM');
final DateFormat _mmddFormat = DateFormat('MM-dd');
final DateFormat _yyyyFormat = DateFormat('yyyy');
final DateFormat _mmFormat = DateFormat('MM');
final DateFormat _ddFormat = DateFormat('dd');
final DateFormat _dateTimeParseFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
final NumberFormat _currencyFormat = NumberFormat('#,###');
final RegExp _halfAlphanumericRegExp = RegExp(r'^[a-zA-Z0-9]+$');
final RegExp _fullAlphanumericRegExp = RegExp(r'^[Ａ-Ｚａ-ｚ０-９]+$');

///
extension DateTimeEx on DateTime {
  String get yyyymmdd => _yyyymmddFormat.format(this);

  String get yyyymm => _yyyymmFormat.format(this);

  String get mmdd => _mmddFormat.format(this);

  String get yyyy => _yyyyFormat.format(this);

  String get mm => _mmFormat.format(this);

  String get dd => _ddFormat.format(this);

  String get youbiStr {
    final DateFormat outputFormat = DateFormat('EEEE');
    return outputFormat.format(this);
  }
}

///

const int _fullLengthCode = 65248;

extension StringEx on String {
  DateTime toDateTime() => _dateTimeParseFormat.parseStrict(this);

  int toInt() {
    return int.parse(this);
  }

  String toCurrency() => _currencyFormat.format(int.parse(this));

  double toDouble() {
    return double.parse(this);
  }

  String alphanumericToFullLength() {
    final Iterable<String> string = runes.map<String>((int rune) {
      final String char = String.fromCharCode(rune);
      return _halfAlphanumericRegExp.hasMatch(char)
          ? String.fromCharCode(rune + _fullLengthCode)
          : char;
    });
    return string.join();
  }

  String alphanumericToHalfLength() {
    final Iterable<String> string = runes.map<String>((int rune) {
      final String char = String.fromCharCode(rune);
      return _fullAlphanumericRegExp.hasMatch(char)
          ? String.fromCharCode(rune - _fullLengthCode)
          : char;
    });
    return string.join();
  }
}

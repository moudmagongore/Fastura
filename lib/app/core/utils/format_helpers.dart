import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatage des montants et des dates, en `fr_FR`.
///
/// La devise n'est jamais codée en dur : elle vient du tenant courant.
/// Les appelants passent donc [devise], ou utilisent les helpers de
/// `SessionController` qui la fournissent déjà.
abstract class Formats {
  Formats._();

  static final NumberFormat _montant =
      NumberFormat('#,##0.##', AppConstants.defaultLocale);

  static final DateFormat _date = DateFormat('dd/MM/yyyy', AppConstants.defaultLocale);
  static final DateFormat _dateHeure =
      DateFormat('dd/MM/yyyy HH:mm', AppConstants.defaultLocale);
  static final DateFormat _dateLongue =
      DateFormat('d MMMM yyyy', AppConstants.defaultLocale);

  /// `125000` → `125 000 GNF`. Sans devise si [devise] est nul.
  static String montant(num? value, {String? devise}) {
    final v = _montant.format(value ?? 0);
    return devise == null || devise.isEmpty ? v : '$v $devise';
  }

  static String date(DateTime? d) => d == null ? '—' : _date.format(d);

  static String dateHeure(DateTime? d) => d == null ? '—' : _dateHeure.format(d);

  static String dateLongue(DateTime? d) =>
      d == null ? '—' : _dateLongue.format(d);

  /// `18.0` → `18 %`, `7.5` → `7,5 %`.
  static String pourcentage(double taux) {
    final s = taux == taux.roundToDouble()
        ? taux.toStringAsFixed(0)
        : taux.toStringAsFixed(2).replaceAll('.', ',');
    return '$s %';
  }
}

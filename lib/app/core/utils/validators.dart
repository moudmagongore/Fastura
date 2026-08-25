/// Validateurs de formulaire réutilisables. Retournent `null` si la valeur
/// est acceptable, sinon le message affiché sous le champ.
abstract class Validators {
  Validators._();

  static final RegExp _email = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[a-zA-Z]{2,}$');

  static String? requis(String? value, {String champ = 'Ce champ'}) {
    if (value == null || value.trim().isEmpty) return '$champ est obligatoire';
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'L\'email est obligatoire';
    if (!_email.hasMatch(v)) return 'Format d\'email invalide';
    return null;
  }

  static String? motDePasse(String? value, {int min = 6}) {
    final v = value ?? '';
    if (v.isEmpty) return 'Le mot de passe est obligatoire';
    if (v.length < min) return 'Au moins $min caractères';
    return null;
  }

  /// Montant strictement positif. Accepte la virgule décimale.
  static String? montant(String? value, {String champ = 'Le montant'}) {
    final v = (value ?? '').trim().replaceAll(' ', '').replaceAll(',', '.');
    if (v.isEmpty) return '$champ est obligatoire';
    final n = double.tryParse(v);
    if (n == null) return '$champ est invalide';
    if (n <= 0) return '$champ doit être supérieur à 0';
    return null;
  }

  /// Parse un montant saisi (« 12 500,50 ») en `double`.
  static double? parseMontant(String? value) {
    final v = (value ?? '').trim().replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(v);
  }
}

/// Les trois rôles de Fastura, répartis sur deux niveaux (cf. CDC §1.3).
///
/// La valeur persistée dans Firestore est [name] (`superAdmin`, `admin`,
/// `vendeur`) — les rules Firestore comparent sur cette chaîne exacte.
enum UserRole {
  /// Niveau plateforme (Addvalis). Crée et active/désactive les tenants.
  /// N'a AUCUN accès aux données métier d'un tenant (factures, clients).
  superAdmin,

  /// Niveau tenant. Tout ce que fait le vendeur, plus l'annulation et la
  /// gestion complète des référentiels et des paramètres.
  admin,

  /// Niveau tenant. Saisit clients, factures, paiements et dépenses,
  /// consulte tout l'historique, n'annule jamais rien.
  vendeur;

  static UserRole? tryParse(String? value) {
    for (final r in UserRole.values) {
      if (r.name == value) return r;
    }
    return null;
  }

  String get label => switch (this) {
        UserRole.superAdmin => 'Super-Administrateur',
        UserRole.admin => 'Administrateur',
        UserRole.vendeur => 'Vendeur',
      };

  /// Rôles qu'un Administrateur peut attribuer à ses collaborateurs.
  /// Le super-admin n'est jamais créé depuis l'application.
  static const List<UserRole> attribuablesParAdmin = [
    UserRole.admin,
    UserRole.vendeur,
  ];

  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isAdmin => this == UserRole.admin;
  bool get isVendeur => this == UserRole.vendeur;

  /// Rattaché à un tenant (donc `tenantId` obligatoire).
  bool get appartientAUnTenant => this != UserRole.superAdmin;

  /// Seul l'Administrateur peut annuler une facture, un paiement ou une
  /// dépense (cf. CDC §1.3 et §6).
  bool get peutAnnuler => this == UserRole.admin;

  /// Accès aux référentiels : catégories, articles, natures de dépense,
  /// utilisateurs, paramètres du tenant.
  bool get peutGererReferentiels => this == UserRole.admin;

  /// Opérations courantes : clients, factures, paiements, dépenses.
  bool get peutSaisirOperations =>
      this == UserRole.admin || this == UserRole.vendeur;
}

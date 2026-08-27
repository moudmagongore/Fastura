/// Noms des collections et champs Firestore (référence unique).
/// Ne jamais écrire une chaîne de collection en dur ailleurs dans le code :
/// la migration vers Spring/Laravel passera par ce point unique.
abstract class FirestoreKeys {
  FirestoreKeys._();

  // ---- Collections racine ----

  /// Entreprises clientes de Fastura. Doc-id = tenantId.
  static const tenants = 'tenants';

  /// Comptes de connexion. Doc-id = uid Firebase Auth.
  static const users = 'users';

  static const categories = 'categories';
  static const articles = 'articles';
  static const clients = 'clients';
  static const factures = 'factures';
  static const paiements = 'paiements';
  static const naturesDepense = 'naturesDepense';
  static const depenses = 'depenses';

  /// Compteurs de numérotation séquentielle. Doc-id = tenantId,
  /// champs = `factures{YYYY}`. Incrémenté dans la transaction de création
  /// de la facture pour garantir « ni trou ni doublon » (cf. CDC §6).
  static const counters = 'counters';

  // ---- Champs transverses ----

  /// Clé d'isolation multi-tenant, présente sur TOUT document métier.
  /// Chaque query doit porter un `where(tenantId, isEqualTo: ...)` pour
  /// s'aligner sur les rules Firestore, sinon elle est refusée d'office
  /// (PERMISSION_DENIED) — la rule ne peut pas filtrer à notre place.
  static const fieldTenantId = 'tenantId';

  /// Toutes les boutiques d'un compte, la boutique d'origine en tête.
  /// Présent sur `users` uniquement : un document métier n'appartient qu'à
  /// une entreprise, c'est l'utilisateur qui peut en servir plusieurs.
  static const fieldTenantIds = 'tenantIds';

  /// Statut actif/inactif. Aucune entité de référentiel n'est jamais
  /// supprimée physiquement (cf. CDC §2).
  static const fieldActive = 'active';
}

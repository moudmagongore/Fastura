import '../../data/models/tenant_model.dart';
import '../../data/models/user_model.dart';

/// Arguments de la liste des utilisateurs.
///
/// Les mêmes écrans servent à l'administrateur (utilisateurs de son propre
/// tenant, arguments nuls) et au super-administrateur (utilisateurs d'une
/// entreprise qu'il consulte, tenant passé explicitement). Le contrôleur
/// résout le tenant courant à partir de là ou de la session.
class UsersArgs {
  const UsersArgs({required this.tenant});

  final TenantModel tenant;
}

/// Arguments du formulaire utilisateur.
class UserFormArgs {
  const UserFormArgs({
    required this.tenantId,
    this.user,
    this.forcerAdmin = false,
  });

  final String tenantId;

  /// Nul en création.
  final UserModel? user;

  /// Vrai quand le super-administrateur crée l'administrateur initial d'une
  /// entreprise : le rôle est imposé et le sélecteur masqué.
  final bool forcerAdmin;

  bool get estEdition => user != null;
}

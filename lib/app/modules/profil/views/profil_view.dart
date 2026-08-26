import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/session_controller.dart';
import '../../../core/utils/marges_ecran.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/message_banner.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../controllers/profil_controller.dart';

/// Fiche personnelle : ce que l'utilisateur peut changer lui-même.
///
/// Trois blocs, trois boutons. Le nom et le téléphone d'un côté, les
/// identifiants de connexion de l'autre — ces derniers demandent le mot de
/// passe courant, Firebase l'exige pour toute modification sensible.
class ProfilView extends GetView<ProfilController> {
  const ProfilView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon profil'),
        // Comme les autres écrans du tiroir : pas de flèche de retour, le
        // menu à droite.
        automaticallyImplyLeading: false,
        actions: const [DrawerButton()],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 32 + margeBasse(context)),
          children: [
            const _Entete(),
            const SizedBox(height: 24),
            _Identite(controller: controller),
            const SizedBox(height: 28),
            _MotDePasse(controller: controller),
            const SizedBox(height: 28),
            _Email(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _Entete extends StatelessWidget {
  const _Entete();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final u = SessionController.to.user.value;
      if (u == null) return const SizedBox.shrink();

      return Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary(context).withValues(alpha: 0.12),
            child: Text(
              u.initiales,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.primary(context),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  u.nom,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${u.role.label} · ${u.email}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Encadré d'une section : titre, explication, contenu.
class _Section extends StatelessWidget {
  const _Section({
    required this.titre,
    required this.explication,
    required this.enfants,
  });

  final String titre;
  final String explication;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titre, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(explication, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: enfants,
          ),
        ),
      ],
    );
  }
}

class _Identite extends StatelessWidget {
  const _Identite({required this.controller});

  final ProfilController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      titre: 'Mes informations',
      explication: 'Le nom apparaît sur les factures que vous émettez.',
      enfants: [
        Form(
          key: controller.formIdentite,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final message = controller.erreurIdentite.value;
                if (message == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: MessageBanner.erreur(message),
                );
              }),
              TextFormField(
                controller: controller.nomCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom complet *',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => Validators.requis(v, champ: 'Le nom'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.telephoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 18),
              Obx(
                () => ElevatedButton.icon(
                  onPressed: controller.enregistrementIdentite.value
                      ? null
                      : controller.enregistrerIdentite,
                  icon: controller.enregistrementIdentite.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MotDePasse extends StatelessWidget {
  const _MotDePasse({required this.controller});

  final ProfilController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      titre: 'Mot de passe',
      explication:
          'Le mot de passe actuel est redemandé : Firebase l\'exige avant '
          'toute modification des identifiants.',
      enfants: [
        Form(
          key: controller.formMotDePasse,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final message = controller.erreurMotDePasse.value;
                if (message == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: MessageBanner.erreur(message),
                );
              }),
              TextFormField(
                controller: controller.motDePasseActuelCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel *',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: Validators.motDePasse,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.nouveauMotDePasseCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nouveau mot de passe *',
                  helperText: '6 caractères minimum',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: Validators.motDePasse,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.confirmationCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer le nouveau *',
                  prefixIcon: Icon(Icons.lock_reset_outlined),
                ),
                validator: controller.validerConfirmation,
              ),
              const SizedBox(height: 18),
              Obx(
                () => OutlinedButton.icon(
                  onPressed: controller.enregistrementMotDePasse.value
                      ? null
                      : controller.changerMotDePasse,
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: Text(
                    controller.enregistrementMotDePasse.value
                        ? 'Modification…'
                        : 'Changer le mot de passe',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Email extends StatelessWidget {
  const _Email({required this.controller});

  final ProfilController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      titre: 'Adresse de connexion',
      explication:
          'C\'est l\'identifiant avec lequel vous vous connectez. Un lien de '
          'vérification part vers la nouvelle adresse ; tant qu\'il n\'est '
          'pas ouvert, la connexion se fait toujours avec l\'ancienne.',
      enfants: [
        Obx(() {
          final attente = controller.emailEnAttente.value;
          if (attente == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MessageBanner.info(
              'Lien envoyé à $attente. Ouvrez-le depuis cette boîte, puis '
              'reconnectez-vous avec la nouvelle adresse.',
            ),
          );
        }),
        Form(
          key: controller.formEmail,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                final message = controller.erreurEmail.value;
                if (message == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: MessageBanner.erreur(message),
                );
              }),
              Obx(
                () => TextFormField(
                  key: ValueKey(controller.email),
                  initialValue: controller.email,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Adresse actuelle',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.nouvelEmailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Nouvelle adresse *',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: controller.motDePasseEmailCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe actuel *',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: Validators.motDePasse,
              ),
              const SizedBox(height: 18),
              Obx(
                () => OutlinedButton.icon(
                  onPressed: controller.enregistrementEmail.value
                      ? null
                      : controller.changerEmail,
                  icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                  label: Text(
                    controller.enregistrementEmail.value
                        ? 'Envoi…'
                        : 'Envoyer le lien de vérification',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

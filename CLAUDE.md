# Fastura — Contexte projet pour Claude Code

Application mobile de facturation multi-tenant. Le cahier des charges complet est dans
`docs/cahier-des-charges-fastura.md` (à placer dans le repo) — le lire avant toute
implémentation. Ce fichier résume les décisions structurantes pour éviter les allers-retours.

## Stack technique

- **Mobile :** Flutter (Android + iOS, une seule base de code).
- **Backend (V1) :** Firebase — Authentication, Firestore, Cloud Functions, Storage.
- **Backend (cible moyen terme) :** migration prévue vers Spring (Java) ou Laravel (PHP) avec
  base relationnelle. Isoler l'accès aux données derrière un repository pattern dès la V1 pour
  ne pas avoir à réécrire les écrans lors de la bascule.
- **Mode de fonctionnement :** 100 % en ligne — l'app nécessite une connexion (pas de mode
  hors-ligne).

## Architecture multi-tenant

Une installation héberge plusieurs entreprises (tenants), données totalement isolées entre
elles. Toute entité métier (sauf Tenant lui-même et le Super-Administrateur) est rattachée à
un tenant.

## Rôles (3, sur 2 niveaux)

- **Super-Administrateur** (plateforme, Addvalis) : crée/active/désactive les tenants. Aucun
  accès aux données métier d'un tenant (factures, clients).
- **Administrateur** (par tenant) : tout ce que fait le Vendeur, + peut **annuler** une facture,
  un paiement ou une dépense, + gère la totalité des référentiels (catégories, articles,
  natures de dépense, utilisateurs, paramètres devise/TVA/logo/adresse/format d'impression).
- **Vendeur** (par tenant) : enregistre clients, factures, paiements, dépenses ; consulte tout
  l'historique ; **ne peut jamais annuler** ; aucun accès aux référentiels ni aux utilisateurs.

## Modules (ordre de développement recommandé)

1. Socle technique (Flutter + Firebase, structure multi-tenant, auth).
2. Utilisateurs (rôles, création des tenants).
3. Catégories et Articles.
4. Clients (dont le "client divers").
5. Facturation et Paiements (cœur métier).
6. Dépenses (natures paramétrables).
7. Paramètres par tenant (devise, TVA, logo, adresse, format d'impression).

## Règles métier clés à ne pas oublier

- **Activation/désactivation** (Catégorie, Article, Client, Nature de dépense, Utilisateur) :
  jamais de suppression physique. Un élément inactif disparaît des listes de sélection à la
  facturation/saisie de dépense mais reste visible dans l'historique déjà émis. Désactiver une
  catégorie désactive en cascade tous ses articles.
- **Numérotation des factures :** séquentielle par tenant, jamais de trou ni de doublon.
- **Paiement :** direct à la facturation, ou via un menu de paiement dédié avec **lettrage
  automatique FIFO** (la plus ancienne facture impayée d'abord).
- **Impression :** un seul format actif par tenant, choisi parmi **A4 / A5 / Ticket** (petit
  format reçu, imprimante thermique type supermarché). L'en-tête affiche le **logo** et
  l'**adresse** du tenant.
- **Devise et TVA :** paramétrables indépendamment par tenant.
- **Stock :** hors périmètre V1 — le module Articles est un simple catalogue de prix.

## Identité visuelle

Logo et icône Fastura fournis séparément (`Fastura_icone_app.*`, `Fastura_logo_horizontal.*`).
Couleurs de marque : bleu pétrole `#1F4E5F` (primaire), vert `#2E7D6E` (accent).

## Points encore ouverts (à trancher en cours de dev, ne bloquent pas le démarrage)

- Mentions légales additionnelles dans l'en-tête/pied de page des factures imprimées.
- Modalités techniques de connexion à l'imprimante thermique (Bluetooth) pour le format Ticket.
- Calendrier précis de bascule du backend Firebase → Spring/Laravel.

## Structure du code (mise en place au socle)

```
lib/
  main.dart                  services permanents + GetMaterialApp
  firebase_options.dart      PLACEHOLDER — régénéré par `flutterfire configure`
  app/
    core/
      constants/             app_constants, firestore_keys (noms de collections)
      services/              firestore_service, auth_service, session_controller
      utils/                 format_helpers, validators, stream_helpers
      widgets/               app_drawer, module_tile, message_banner, ...
    data/
      models/                tenant_model, user_model, user_role, format_impression
      repositories/          tenant_repository, user_repository
    modules/<rôle>/<feature>/{bindings,controllers,views,widgets}
    routes/                  app_routes, app_pages, route_guards
    theme/                   app_colors, app_theme, theme_controller
firestore.rules              barrière d'isolation multi-tenant (à publier)
```

## Conventions à respecter

- **State management :** GetX. Un module = `bindings` + `controllers` + `views`.
  Les contrôleurs ne touchent jamais Firestore directement, ils passent par un
  repository.
- **Accès aux données :** uniquement via `lib/app/data/repositories/`, qui passent
  eux-mêmes par `FirestoreService`. Aucun `FirebaseFirestore.instance` ailleurs —
  c'est la couture prévue pour la bascule Spring/Laravel.
- **Noms de collections :** toujours via `FirestoreKeys`, jamais de chaîne en dur.
- **Isolation multi-tenant :** tout document métier porte `tenantId`, et **chaque
  query doit porter `where('tenantId', isEqualTo: ...)`**. Les rules Firestore ne
  filtrent pas, elles autorisent ou refusent : une query non scopée est rejetée
  en bloc (PERMISSION_DENIED). Le tenant courant se lit sur
  `SessionController.to.requireTenantId`.
- **Droits :** `SessionController.to.peutAnnuler` / `.peutGererReferentiels` dans
  les vues, `AdminGuard` / `SuperAdminGuard` / `TenantGuard` sur les routes. Les
  guards protègent la navigation, pas les données — `firestore.rules` reste la
  seule barrière non contournable.
- **Suppression :** jamais. `allow delete: if false` partout ; on bascule le
  champ `active`.
- **Couleurs :** via `AppColors` (helpers prenant le `BuildContext`), jamais de
  couleur de fond ou de texte en dur — le thème sombre casserait.
- **Langue :** code et commentaires en français, comme le domaine métier.

## État d'avancement

- [x] **Socle technique** — projet Flutter, thème, GetX, routes + guards par rôle,
  authentification (connexion, mot de passe oublié), `SessionController`
  (profil + tenant en stream, déconnexion forcée si compte ou entreprise
  désactivé), `firestore.rules`, accueils par rôle, création/suspension des
  entreprises côté super-admin.
- [x] **Module Utilisateurs** — liste, création, modification et
  activation/désactivation des comptes d'un tenant ; création de
  l'administrateur initial d'une entreprise par le super-admin.
  `UserCreationService` passe par une **instance Firebase secondaire** :
  `createUserWithEmailAndPassword` connecte le compte créé, ce qui éjecterait
  sinon l'administrateur en pleine saisie. Garde-fous : on ne désactive ni ne
  rétrograde le dernier administrateur actif, ni son propre compte. L'email
  est immuable après création (c'est l'identifiant Firebase Auth).
- [x] **Module Catégories et Articles** — référentiels réservés à
  l'administrateur. Code unique par tenant (normalisé en majuscules, contrôle
  applicatif et non contrainte de base). Désactiver une catégorie désactive
  en cascade ses articles, par lots de 400 pour rester sous le plafond de
  500 écritures d'un batch Firestore ; **réactiver ne propage pas**, un
  article désactivé individuellement doit le rester. Un article ne peut pas
  être réactivé tant que sa catégorie est fermée. Le catalogue n'a aucune
  notion de quantité : le stock est hors périmètre V1.
- [x] **Module Clients** — ouvert à l'administrateur **et** au vendeur (CDC §5,
  qui prime sur la formulation générale du §2). Client divers matérialisé à la
  volée par le premier membre du tenant qui ouvre la liste : le super-admin
  crée l'entreprise mais n'a aucun droit d'écriture sur les données métier. Il
  ne peut être ni renommé ni désactivé. Le champ `solde` appartient aux modules
  Facturation et Paiements, qui le recalculent en transaction — les règles
  Firestore interdisent de le modifier depuis la fiche client, sinon on
  effacerait une créance sans trace.
  **Reste à faire** : l'historique factures/paiements de la fiche client et le
  relevé de compte imprimable, qui dépendent des collections `factures` et
  `paiements`. La place est réservée dans l'écran.
- [x] **Facturation — phase 1** : émission d'une facture, règlement immédiat,
  journal, fiche détaillée, annulation par l'administrateur, historique
  factures/paiements branché sur la fiche client.
  - **Numérotation** : `counters/{tenantId}.factures{AAAA}` incrémenté **dans
    la transaction de création**, ce qui garantit une séquence sans trou ni
    doublon. Ne jamais sortir cet incrément de la transaction.
  - **Instantanés** : nom du client, devise, taux de TVA, code/désignation/prix
    de chaque ligne sont recopiés à l'émission. Une facture est une pièce
    comptable, elle doit rester identique à ce qui a été remis au client.
  - **Solde client** : mis à jour du seul *reste dû* dans la même transaction.
    Une rule Firestore évaluant chaque écriture isolément ne peut pas vérifier
    qu'une écriture sur `clients` accompagne bien une écriture sur `factures` :
    l'intégrité du solde repose donc sur les transactions du repository, pas
    sur les rules. C'est l'une des raisons de la bascule vers un backend
    relationnel.
  - **Annulation** : jamais de suppression, la séquence ne tolère aucun trou.
    La facture sort du solde et son paiement direct est annulé avec elle.
- [x] **Paiements — lettrage FIFO** : menu d'encaissement dédié, journal,
  détail, annulation par l'administrateur.
  - Les factures candidates sont lues **hors transaction** (aucune requête
    n'est possible dedans) puis **relues par identifiant dedans**, pour que le
    lettrage s'appuie sur des montants à jour même si un autre appareil a
    encaissé entre-temps. Plafond : 50 factures par règlement.
  - L'écran rejoue le lettrage en **aperçu** pendant la saisie : sans ça,
    l'automatisme reste une boîte noire au comptoir.
  - Le surplus reste en avance au crédit du client (solde négatif).
  - `FactureModel.paiementIds` existe pour que l'annulation puisse relire les
    règlements par identifiant. Annuler une facture annule son règlement
    direct (même acte de vente) mais **conserve** les règlements enregistrés
    séparément, dont l'imputation bascule en avance. D'où le solde retiré :
    `montantTotal − montantDirect`.
### Design des écrans de vente

La facturation et l'encaissement reprennent la structure de l'application de
référence gongore_App (écrans « vente » et « règlement »), éprouvée au
comptoir :

- **Facture** : barre client compacte en haut, liste des articles au centre
  qui occupe toute la hauteur disponible, bloc TOTAL + bouton de validation en
  bas. Les options de règlement partent dans une feuille — c'est la liste
  qu'on manipule, elle ne doit pas être rognée par un formulaire.
- **Ligne d'article** : carte à bord arrondi, compteur de quantité en pilule
  (la valeur est cliquable pour saisir directement), pastille « Prix » qui
  passe au vert quand le prix s'écarte du catalogue.
- **Encaissement** : deux feuilles enchaînées — choix du client (recherche,
  filtre « avec créance » actif par défaut, tri par montant dû décroissant),
  puis saisie du montant pré-rempli avec la dette, avec l'aperçu du lettrage.
- Helpers communs dans `core/utils/bottom_sheet_helpers.dart` :
  `PoigneeSheet`, `EnteteSheet`, `paddingBasSheet` (clavier ou barre de
  gestes), `androidOnlySafeArea`.

- [x] **Impression A4/A5/Ticket** — facture et reçu de règlement, au format
  retenu par le tenant, avec logo et adresse en en-tête (CDC §6).
  - `pdf_commun.dart` porte format de page, palette, en-tête et pied ;
    `facture_pdf_service.dart` et `recu_pdf_service.dart` les documents.
  - Le **ticket n'est pas un A4 réduit** : hauteur de page infinie (rouleau
    continu, sinon l'imprimante avance du papier vierge), rendu une colonne
    sans tableau ni filets fins, séparateurs en tirets.
  - **A5 et non A3** : le troisième format est le demi-A4 de comptoir, pas
    la grande feuille. L'A3 a existé un temps ; `FormatImpression.parse`
    ramène sur A4 les tenants qui porteraient encore `'a3'` en base.
  - **`MultiPage` et non `Page`** pour A4 et A5 : une `Page` de hauteur
    finie **rogne** le débordement sans lever d'exception. Une facture de
    dix lignes remplit déjà un A5 — le pied de page disparaissait en
    silence. La ligne d'en-tête du tableau porte `repeat: true` et le pied
    numérote les pages. Le ticket garde une `Page` : sa hauteur est infinie,
    rien ne peut y être rogné.
  - `MultiPage` ne contraint pas la largeur de ses enfants : un `Text`
    centré s'y ajuste à sa ligne et retombe à gauche. D'où
    `PdfCommun.pleineLargeur()`.
  - Polices intégrées (Helvetica) : leur encodage WinAnsi couvre les accents
    français, inutile d'embarquer une TTF. En revanche **tout caractère hors
    Latin-1 est purement supprimé au tirage** — tiret cadratin `—`,
    apostrophe courbe `’`, symbole `€`. Seul le texte saisi par
    l'utilisateur (adresse, note, désignation) est concerné ; le jour où
    ça gêne, il faudra embarquer une TTF Unicode.
  - Un document annulé sort avec un bandeau « DOCUMENT ANNULÉ » : une copie
    imprimée avant l'annulation continue sinon de circuler comme valide.
  - L'impression est proposée juste après l'émission d'une facture et après
    un encaissement, en plus du bouton présent sur chaque fiche.
  - `test/facture_pdf_service_test.dart` rend les trois formats et compte
    les pages : le rognage étant silencieux, une facture de quarante lignes
    qui tiendrait sur une seule page est le signe qu'elle a été coupée.
  - **Reste ouvert** : la liaison Bluetooth directe avec l'imprimante
    thermique (CDC §9). Le format Ticket sort aujourd'hui via le dialogue
    d'impression du système ou en partage PDF.
- [ ] **Logo du tenant** : `logoUrl` est lu à l'impression mais aucun écran ne
  permet encore de le téléverser — ça vient avec le module Paramètres.
- [ ] Dépenses · Paramètres par tenant.

## Index Firestore

Toute requête qui combine un `where` et un `orderBy` sur des champs différents
exige un index composite. Ils sont déclarés dans `firestore.indexes.json` et
déployés par `firebase deploy --only firestore:indexes`. Penser à l'ajouter en
même temps que la requête, sinon elle échoue en production.

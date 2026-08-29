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

Un **Administrateur peut tenir plusieurs boutiques** : le super-administrateur affecte un
administrateur existant à une autre entreprise, et celui-ci bascule de l'une à l'autre depuis
son menu, avec le même compte. Il n'en sert qu'une à la fois — l'isolation des données est
inchangée.

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
- **Le client divers ne se crédite jamais.** Il n'a pas de fiche : aucun compte à débiter,
  personne à relancer. Sa facture est réglée intégralement à l'émission — la feuille de
  règlement ne propose ni montant partiel ni « Solder », et le sélecteur d'encaissement ne le
  propose plus (sauf dette héritée, pour qu'elle puisse être soldée). Vendre à crédit exige une
  fiche client, créable d'un bouton depuis le sélecteur de la facture. Il existe par défaut :
  la facturation le matérialise elle-même si la liste des clients n'a jamais été ouverte, et le
  présélectionne. Nom et téléphone de l'acheteur restent saisissables, facultatifs, et
  s'impriment sans ouvrir de fiche.
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
  `SessionController.to.requireTenantId` — c'est la **boutique servie**, pas
  forcément la seule du compte (voir *Administrateur de plusieurs boutiques*).
- **Droits :** `SessionController.to.peutAnnuler` / `.peutGererReferentiels` dans
  les vues, `AdminGuard` / `SuperAdminGuard` / `TenantGuard` sur les routes. Les
  guards protègent la navigation, pas les données — `firestore.rules` reste la
  seule barrière non contournable.
- **Suppression :** jamais. `allow delete: if false` partout ; on bascule le
  champ `active`.
- **Couleurs :** via `AppColors` (helpers prenant le `BuildContext`), jamais de
  couleur de fond ou de texte en dur — le thème sombre casserait.
- **Langue :** code et commentaires en français, comme le domaine métier.

## Parti pris visuel

Du blanc, des filets, et la couleur réservée à ce qui compte. Tout se règle
dans `app_theme.dart` : une vue qui redéfinit une taille de police ou un rayon
est une vue à corriger.

- **Barres de titre claires**, fondues dans le fond, titre sombre et icônes
  d'action en primaire. La bande pleine couleur écrasait le contenu de chaque
  écran. La marque vit au tiroir, sur la carte d'entreprise (`TenantHeader`),
  sur les en-têtes de fiche et sur les actions. Conséquence à ne pas oublier :
  `systemOverlayStyle` bascule les icônes système en sombre, et les surfaces
  de marque qui touchent la barre d'état (en-tête du tiroir, splash) doivent
  poser leur propre `AnnotatedRegion` pour les repasser en clair.
- **Tiroir et bouton à gauche** : le tiroir entre par la gauche (`drawer:`)
  et son bouton ouvre la barre. Chaque écran à tiroir pose
  `automaticallyImplyLeading: false` **et** `leading: const DrawerButton()` :
  la première ligne empêche `Scaffold` de poser sa flèche de retour — on
  circule par le menu — la seconde rend le bouton indépendant de ce qui se
  trouve dans la pile. Un `DrawerButton` dans `actions:` est une survivance
  d'une version où il vivait à droite ; il n'en reste aucun.
- **La marque au titre des accueils** (`MarqueFastura`, `core/widgets/`) :
  « Fast » en primaire, « ura » en accent, comme le logotype. Le **mot et non
  l'image** — `Fastura_logo_horizontal.png` est encré sur fond transparent en
  bleu pétrole, qui disparaît sur la barre du thème sombre ; le mot prend la
  primaire adaptative et reste lisible dans les deux thèmes. La salutation
  du moment a existé à cette place, puis en tête du corps : elle a été
  retirée, avec `Formats.salutation()`.
- **Le tiroir se comporte comme celui de gongore_App** : appui haptique,
  fermeture immédiate, et `Get.offNamed` qui **remplace** l'écran courant.
  La page arrive donc toujours du même côté, en avant. Repartir vers
  l'accueil par un `pop` la faisait glisser à l'envers, et le tiroir encore
  ouvert — il est peint sur l'écran qui part — filait vers la droite avec
  lui avant de se refermer vers la gauche. Rien à attendre : la page sous le
  tiroir ne recule plus. `DrawerOpenGuard` (repris de gongore_App) ignore
  les appuis pendant les 246 ms d'ouverture, sans quoi un appui répété sur
  le bouton du menu active une entrée que personne n'a visée.
- **Le tiroir ne empile pas** : chaque destination *remplace* l'écran
  courant (`Get.offNamed`, `AppDrawer._ouvrir`). Avec `Get.toNamed`, aller de
  Paramètres à l'accueil puis revenir aux Paramètres laissait **deux fois le
  même écran dans la pile** ; GetX rend alors le même contrôleur aux deux
  instances, et avec lui la même `GlobalKey` de formulaire — que Flutter
  refuse (« Duplicate GlobalKey »). Conséquence assumée, comme dans
  gongore_App : la pile reste plate, le bouton retour système ne ramène pas
  d'un écran de menu à l'autre.
- **Trois rayons** et pas un de plus : `AppTheme.radiusSmall` (pastilles),
  `radius` (champs, boutons, cartes, et l'onde d'appui qui doit les épouser),
  `radiusLarge` (feuilles, dialogues, bandeaux de marque).
- **Aucun clavier ne s'ouvre tout seul** : plus un seul `autofocus: true`
  dans l'app. Sur une feuille, le clavier en masque la moitié — liste,
  onglets, aperçu du lettrage — avant qu'on ait vu ce qu'elle contient ; sur
  un dialogue d'annulation, il cache la question posée. Le champ attend
  qu'on le touche.
- **Champs remplis** d'une teinte (`AppColors.surfaceMuted`) plutôt que cernés
  d'un trait ; le contour n'apparaît qu'au focus, en primaire.
- **Aplats teintés sans contour** pour les pastilles de statut et les
  bandeaux : la couleur du texte porte déjà le sens.
- **Aucune ombre**, sauf le bouton flottant.
- `tool/apercu_theme.dart` rend les composants communs dans les deux thèmes en
  deux PNG (`flutter test tool/apercu_theme.dart --update-goldens`). C'est la
  seule façon de juger le thème sans appareil branché — s'en servir avant de
  toucher à la palette.

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
  l'administrateur. Pas de code article : une catégorie n'a qu'un libellé,
  un article qu'une désignation. Le catalogue n'a donc **aucun garde-fou
  contre les doublons** — deux catégories peuvent porter le même libellé.
  `LigneFacture.code` subsiste, vide, pour les factures émises avant le
  retrait : une pièce comptable ne se réécrit pas. Désactiver une catégorie
  désactive
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
  - **Instantanés** : nom du client, devise, taux de TVA,
    code/désignation/catégorie/prix de chaque ligne sont recopiés à
    l'émission. Une facture est une pièce comptable, elle doit rester
    identique à ce qui a été remis au client. La catégorie a sa **colonne**
    dans le tableau (A4 et A5), après la désignation — c'est l'article vendu
    qui ouvre la ligne. Le ticket n'a pas de
    colonnes : elle s'y glisse en gris sous la désignation. Vide sur les
    factures émises avant qu'elle soit reprise — on ne va pas chercher celle
    du catalogue d'aujourd'hui pour combler la case.
  - **Solde client** : mis à jour du seul *reste dû* dans la même transaction.
    Une rule Firestore évaluant chaque écriture isolément ne peut pas vérifier
    qu'une écriture sur `clients` accompagne bien une écriture sur `factures` :
    l'intégrité du solde repose donc sur les transactions du repository, pas
    sur les rules. C'est l'une des raisons de la bascule vers un backend
    relationnel.
  - **Annulation** : jamais de suppression, la séquence ne tolère aucun trou.
    La facture sort du solde et son paiement direct est annulé avec elle.
- [x] **Filtre « Du … au … » sur les journaux** —
  `core/utils/filtre_periode.dart` (état) et `core/widgets/barre_periode.dart`
  (les deux champs de date), partagés par les factures, les paiements et les
  dépenses, qui avaient leur propre énumération de raccourcis avant.
  - **Deux dates posées par l'utilisateur**, pas des raccourcis (« ce mois »,
    « 30 jours ») : une clôture, un contrôle, une relance portent sur des
    bornes précises.
  - **Bornes posées au serveur** (`depuis` / `jusqua` sur `date`, le champ
    qui sert déjà au tri : aucun index composite à ajouter). Borner après
    lecture ferait payer six mois de documents pour en afficher un.
  - **Aucune borne par défaut**, sur les trois journaux : on y cherche une
    pièce ancienne aussi souvent qu'on y fait le point du mois, et la
    recherche ne porte que sur ce qui est chargé. Une croix efface les deux
    bornes. Le plafond de lecture du repository contient le volume tant que
    l'utilisateur n'a rien posé.
  - Le récapitulatif imprimable des dépenses annonce alors la période
    **réellement couverte** — la première et la dernière dépense listées :
    un document sans dates ne se classe pas.
  - Poser un « du » postérieur au « au » pousse l'autre borne : une liste
    vide sans explication est pire qu'un intervalle corrigé.
  - L'état vide distingue « rien n'a jamais été saisi » de « rien sur cette
    période » — sinon un mois creux se lit comme une application vide.
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
  - **Rien ne s'imprime tout seul.** L'aperçu s'ouvrait de lui-même après
    l'émission d'une facture ; il était à refermer à chaque vente, y compris
    les nombreuses où le client ne veut pas de papier. Le tirage part
    maintenant du bouton « Imprimer » de la fiche. Après un encaissement, une
    question — « Imprimer le reçu ? » — reste posée : c'est la preuve que le
    client attend avant de repartir, et elle se décline d'un bouton.
  - **Aperçu plein écran avant tirage** (`core/widgets/apercu_pdf.dart`,
    sur le modèle de gongore_App) : le document se regarde avant de partir
    sur le papier. Fond blanc imposé, thème sombre compris — c'est du papier
    qu'on regarde. La barre d'actions interne de `PdfPreview` est désactivée
    (elle porte sa propre ombre Material) ; « Imprimer » et « Partager »
    vivent en bas de l'écran. `dpi: 200` : un ticket gagnerait à monter plus
    haut, mais la même valeur s'applique à l'A4, où chaque page coûte
    `largeur × hauteur × dpi²` octets en mémoire.
  - `test/pdf_services_test.dart` rend les trois formats et compte
    les pages : le rognage étant silencieux, une facture de quarante lignes
    qui tiendrait sur une seule page est le signe qu'elle a été coupée.
  - **Reste ouvert** : la liaison Bluetooth directe avec l'imprimante
    thermique (CDC §9). Le format Ticket sort aujourd'hui via le dialogue
    d'impression du système ou en partage PDF.
- [x] **Module Dépenses** — nomenclature paramétrable et saisie (CDC §7).
  - **Natures de dépense** : référentiel de l'administrateur, un libellé et
    rien d'autre — pas de code, comme les catégories. Désactiver une nature
    la retire du formulaire de saisie **sans cascade** : une dépense est une
    écriture déjà passée, elle reste dans l'historique et dans les totaux.
  - **Dépenses** : ouvertes au vendeur comme à l'administrateur, annulation
    réservée à l'administrateur. Pas de transaction — une dépense ne met à
    jour aucune contrepartie, ni solde, ni compteur, ni lettrage.
  - Une dépense **ne se modifie pas** après saisie : `depenseFigee()` dans
    les rules verrouille date, nature, montant et description. On corrige
    par annulation puis nouvelle saisie, comme pour une facture.
  - `natureLibelle` est recopié à la saisie, mais l'écran et le PDF
    affichent le libellé **courant** du référentiel quand la nature existe
    encore : une nature renommée doit s'afficher sous son nom d'aujourd'hui,
    une nature disparue ne doit pas rendre la dépense anonyme.
  - **Période côté serveur, nature côté écran** : la période borne le
    volume, la nature filtre une liste déjà réduite au mois. Ajouter
    `natureId` à la requête coûterait un index composite pour rien.
  - Récapitulatif imprimable de la période (`depenses_pdf_service.dart`) :
    répartition par nature puis détail daté. C'est le document du lot qui
    déborde le plus, d'où le `MultiPage`.
  - **Reste ouvert** : le justificatif photo (CDC §7). Le champ
    `justificatifUrl` existe et les rules le laissent modifiable après
    création, mais **Firebase Storage n'est pas provisionné** sur
    `fastura-c05bf` — l'API répond 404. Même blocage que le logo du tenant.
- [x] **Paramètres par tenant** — écran de l'administrateur : identité,
  adresse, logo, devise, TVA, préfixe de facture, format d'impression
  (CDC §7).
  - C'est **le même document Firestore** que le formulaire du super-admin,
    à deux différences : l'administrateur ne voit que son entreprise et ne
    touche jamais au statut actif/inactif. Les rules verrouillent les deux —
    `TenantRepository.update()` réécrit `active` avec sa valeur courante,
    ce qui satisfait la rule sans lui donner de prise dessus.
  - **Aperçu sur facture spécimen** : le format se choisit en le regardant.
    L'aperçu travaille sur la **saisie en cours**, avant enregistrement, et
    la facture porte le numéro littéral « SPÉCIMEN » — un aperçu imprimé
    traîne, il ne doit jamais passer pour une pièce comptable.
  - **Devise, taux de TVA et préfixe ne valent que pour l'avenir** : chaque
    facture recopie les siens à l'émission. Le nom, l'adresse et le logo, en
    revanche, sont lus **au tirage** : renommer l'entreprise change aussi
    l'en-tête d'une facture ancienne réimprimée. C'est voulu — c'est la même
    entité qui réimprime.
  - **Logo référencé, pas téléversé** : le champ attend une URL https, avec
    aperçu à l'écran pour vérifier qu'elle charge. Firebase Storage n'est
    pas provisionné (voir ci-dessous) ; le jour où il le sera, le
    téléversement remplira le même champ.
- [x] **Accueil chiffré** (`modules/accueil/`) — module partagé par les deux
  accueils : le CDC donne au vendeur la consultation de tout l'historique, il
  n'y a rien à cloisonner sur les chiffres. Facturé, encaissé, dépenses, puis
  les cinq dernières factures ; annulations exclues des totaux.
  - **Le jour et le mois s'affichent ensemble**, sans filtre à manipuler : le
    jour en trois cartes détaillées, le mois en résumé de trois lignes.
  - **Un seul jeu de flux.** Les trois abonnements sont bornés au **mois**
    côté serveur, et le jour s'en déduit par filtrage : il est contenu dans
    le mois, deux abonnements liraient deux fois les mêmes documents. La
    borne porte sur le champ qui sert aussi au tri (`date`), donc sans index
    composite supplémentaire.
  - **Plafonds assumés** (400 factures, 400 règlements, 300 dépenses) :
    Firestore facture au document lu. Au-delà, `AccueilController.tronque`
    fait afficher « totaux partiels » — un chiffre faux présenté comme juste
    serait pire qu'un chiffre annoncé incomplet.
  - Le début du jour est figé à la construction du contrôleur : l'app laissée
    ouverte au passage de minuit continue d'afficher la veille.
- [x] **Création de client à la volée** — la feuille « Choisir un client » de
  la facturation porte un bouton « Nouveau ». Le formulaire s'ouvre
  **par-dessus** la feuille et non à sa place : la refermer d'abord rendrait
  `null` à la facture en cours, qui resterait sans client.
  `ClientFormController` renvoie le client créé (`Get.back(result:)`), ce qui
  évite d'attendre que le flux Firestore l'ait rapatrié pour le sélectionner.
- [x] **Profil personnel** (`modules/profil/`) — chacun corrige son nom et son
  téléphone, change son mot de passe et son adresse de connexion, quel que
  soit son rôle. Entrée « Mon profil » dans le tiroir, au-dessus de la
  déconnexion.
  - **Trois blocs, trois boutons** : le nom et le téléphone vont dans
    Firestore, le mot de passe et l'email appartiennent à Firebase Auth et
    exigent chacun le mot de passe courant (`reauthenticateWithCredential`).
    Un bouton unique obligerait à retaper son mot de passe pour corriger une
    faute de frappe dans son nom.
  - **L'email ne change pas sur commande** : `verifyBeforeUpdateEmail` envoie
    un lien à la nouvelle adresse et l'identifiant de connexion ne bascule
    qu'une fois ce lien ouvert. L'écran le dit, sinon l'utilisateur se croit
    enfermé dehors à la connexion suivante. `SessionController._recalerEmail`
    remet le document Firestore au niveau du compte Auth au chargement de
    session suivant.
  - **`firestore.rules` : nouvelle règle `allow update` sur `users/{uid}`**
    pour le titulaire lui-même — jusque-là seul un admin pouvait écrire, un
    vendeur se serait pris un PERMISSION_DENIED. Rôle, tenant et état actif y
    sont figés par égalité, sinon un vendeur se promeut administrateur. **À
    déployer** : `firebase deploy --only firestore:rules`.
- [x] **À propos** (`modules/apropos/`) — ce que fait l'app et les
  coordonnées de l'éditeur, dans le tiroir sous « Mon profil ». Écran sans
  contrôleur : tout vient d'`AppConstants`. Les coordonnées **se copient**
  d'un appui plutôt que de s'ouvrir dans le téléphone ou le courrier — l'app
  n'embarque pas `url_launcher`, et un numéro qu'on ne peut ni composer ni
  copier ne sert à personne.
  - Les mêmes constantes signent le **bas du reçu et de la facture**
    (`PdfCommun.signatureEditeur`). L'en-tête reste celui de l'entreprise,
    seule émettrice ; cette ligne-là est en bas, en gris et en corps 7 — la
    mention de l'outil, pas un second émetteur, et le seul endroit où un
    numéro de support a une chance de servir.
  - Sur la facture A4/A5, elle vit dans le **pied de page du `MultiPage`**
    (`_piedPage`), au-dessus de « Émise par… / Page x/y » : à la suite des
    totaux, sur une facture courte, elle flottait au milieu de la feuille.
    Sur **toutes** les pages et pas seulement la dernière — la hauteur du
    pied est mesurée avant que `pagesCount` soit connu, un pied plus haut sur
    la dernière page mordrait sur son contenu. Le ticket, lui, la garde à la
    suite du corps : sa page n'a pas de bas.
  - Sur le reçu, la signature descend de la même façon dans `_piedPage`.
  - `tool/apercu_facture.dart` et `tool/apercu_recu.dart` écrivent un A5 et
    un ticket dans `build/` pour regarder le rendu
    (`flutter test tool/apercu_recu.dart`, puis `sips -s format png`). C'est
    le seul moyen de juger une composition sans imprimante.
- [x] **Administrateur de plusieurs boutiques** — le super-administrateur
  affecte un administrateur **déjà existant** à une autre entreprise, depuis
  la liste des utilisateurs de celle-ci (action « Affecter un
  administrateur »). Un seul compte, un seul mot de passe, plusieurs
  boutiques.
  - **Deux champs, pas un.** `users.tenantId` reste la **boutique
    d'origine** — celle où le compte a été créé, et le seul champ que
    portent les comptes antérieurs. `users.tenantIds` porte la liste
    complète, boutique d'origine en tête. `UserModel.fromMap` reconstruit
    toujours la liste à partir des deux : un document ancien se lit comme un
    compte mono-boutique, sans migration.
  - **Deux requêtes fusionnées** dans `UserRepository.watchByTenant` :
    Firestore ne sait pas faire un OU entre `tenantId ==` et `tenantIds
    array-contains`. Ne garder que la seconde ferait disparaître de la liste
    tous les comptes existants ; `fusionnerListes` (dans `stream_helpers`)
    recolle les deux et dédoublonne.
  - **Une boutique à la fois.** `SessionController.tenantId` désigne la
    boutique servie, mémorisée par compte dans `GetStorage`. En changer
    repasse par `Get.offAllNamed(routeAccueil)` : tous les contrôleurs de
    module ont des flux liés à l'ancienne, les reconstruire est plus sûr que
    demander à chacun de se rebrancher. Le sélecteur vit dans le tiroir
    (ligne « entreprise ») et sur la carte d'accueil.
  - **Boutique suspendue ≠ session fermée** : si la boutique servie est
    suspendue, la session se replie sur une autre du compte
    (`_ecarterBoutique`) et ne déconnecte qu'à court de boutiques. Les
    boutiques écartées sont mémorisées pour la session, sinon le repli
    ferait la navette entre deux entreprises fermées.
  - **Un compte partagé n'est modifiable que par le super-administrateur.**
    Les rules exigent `mesTenants().hasAll(tenantsDe(cible))` pour écrire, et
    `hasAny` seulement pour lire : l'administrateur de la boutique A voit
    l'administrateur affecté et le reconnaît à sa pastille, mais ne peut ni
    le désactiver ni le rétrograder — il fermerait la porte de la boutique B.
    Les affectations elles-mêmes (`tenantIds`) sont figées pour tout le monde
    sauf lui.
  - **Retirer, ce n'est pas désactiver** : sur une affectation, la liste
    propose « Retirer » (le compte perd cette boutique et garde la sienne).
    La boutique d'origine, elle, ne se retire jamais.
  - **À déployer** : `firebase deploy --only firestore:rules,firestore:indexes`
    — quatre index composites `users` s'ajoutent (`tenantIds` array-contains,
    et `role + nom` pour la feuille d'affectation).
- [x] **Import d'articles par collage** (`modules/articles/import_articles.dart`
  pour l'analyseur, `import_articles_controller/view` pour l'écran) — saisir
  un catalogue de plusieurs centaines d'articles un par un représente des
  milliers de gestes.
  - **Une catégorie par lot**, choisie avant le collage, plus une unité par
    défaut. Gérer les catégories dans le texte obligerait à en créer à la
    volée, avec les fautes de frappe qui vont avec.
  - **Séparateur reconnu, pas demandé** : tabulation (ce que donne un
    copier-coller de deux colonnes d'un tableur — le chemin le plus court
    quand le catalogue existe déjà), `;` ou `|`. La virgule est exclue :
    elle est décimale.
  - **Prix écrits par un humain** : `425 000`, `425.000`, `425000 GNF`,
    `12 500,50`. Le point suivi de trois chiffres est un séparateur de
    milliers, la virgule est toujours décimale. Rien d'exploitable ⇒ ligne
    signalée, jamais d'article créé à un prix inventé.
  - **Aperçu obligatoire avant écriture**, avec le compte « à créer / déjà au
    catalogue / à corriger » : le catalogue ne supprime jamais, un import
    raté ne se rattrape qu'en désactivant les articles un par un. Les
    doublons (dans le catalogue ou répétés dans le collage) sont décochés
    d'office mais forçables — le catalogue tolère les homonymes.
  - **Écriture par lots de 400** (plafond d'un batch Firestore : 500). Les
    lots partent l'un après l'autre : un échec en cours de route laisse les
    précédents créés, et le message le dit.
  - Plafond de 500 lignes par collage, au-delà l'aperçu ne se relit plus.
  - `test/import_articles_test.dart` couvre l'analyseur (séparateurs, prix,
    doublons, lignes vides, troncature) — c'est le seul endroit de l'app qui
    lise du texte écrit ailleurs.
- [ ] **Firebase Storage à provisionner** — console Firebase → Storage →
  Commencer (exige le plan Blaze). Bloque le justificatif photo des dépenses
  et le téléversement du logo depuis le téléphone. Tout le reste du cahier
  des charges est livré.

## Index Firestore

Toute requête qui combine un `where` et un `orderBy` sur des champs différents
exige un index composite. Ils sont déclarés dans `firestore.indexes.json` et
déployés par `firebase deploy --only firestore:indexes`. Penser à l'ajouter en
même temps que la requête, sinon elle échoue en production.

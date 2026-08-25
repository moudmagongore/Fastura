# Fastura — Cahier des charges fonctionnel

**Projet :** e-billing — Application mobile de facturation
**Version :** 1.0
**Date :** 20 août 2026

---

## 1. Présentation générale

Fastura est une application mobile de facturation destinée à des entreprises et commerces souhaitant gérer leurs ventes, leurs clients, leur catalogue d'articles et leurs dépenses depuis un smartphone. L'application est conçue en mode **multi-tenant** : une même installation de Fastura peut héberger plusieurs entreprises clientes, chacune disposant de ses propres utilisateurs, clients, articles, factures et paramètres, de façon totalement isolée des autres.

### 1.1 Objectifs

Fastura doit permettre à une entreprise de créer et suivre ses factures et reçus, d'encaisser les paiements de ses clients avec un rapprochement automatique des créances, de gérer son catalogue d'articles et ses catégories, de conserver l'historique complet de chaque client, et de suivre ses dépenses courantes selon une nomenclature qu'elle définit elle-même.

### 1.2 Choix d'architecture retenus

| Décision | Choix retenu |
|---|---|
| Plateforme mobile | Flutter (Android + iOS avec une seule base de code) |
| Mode de fonctionnement | 100 % en ligne — l'application nécessite une connexion pour fonctionner |
| Backend (phase de démarrage) | Firebase (Authentication, Firestore, Cloud Functions, Storage) |
| Backend (cible à moyen terme) | Migration prévue vers un backend Spring (Java) ou Laravel (PHP) avec base relationnelle, une fois le besoin métier stabilisé |
| Multi-entreprise | Multi-tenant : plusieurs entreprises/boutiques dans une même application, données isolées par tenant |
| Devise et TVA | Paramétrables indépendamment pour chaque tenant (chaque entreprise choisit sa devise et son taux de TVA, ou l'absence de TVA) |
| Gestion de stock | Non incluse dans la V1 : le module Articles est un catalogue de prix, sans suivi de quantités |
| Impression | Choix unique par tenant : chaque boutique sélectionne un seul format d'impression parmi trois — A4, A5 (demi-page), ou Ticket (petit format reçu pour imprimante thermique, comme dans les supermarchés) |

Le choix de démarrer sur Firebase permet de livrer rapidement une première version fonctionnelle sans gérer d'infrastructure serveur. La bascule ultérieure vers Spring ou Laravel se prépare dès maintenant en gardant une couche d'accès aux données isolée dans l'application (repository pattern), afin que le remplacement du backend n'impose pas de réécrire les écrans.

### 1.3 Rôles et utilisateurs

Trois rôles sont prévus, répartis sur deux niveaux :

| Rôle | Niveau | Description |
|---|---|---|
| Super-Administrateur | Plateforme (Addvalis) | Crée, active, désactive et supervise les entreprises (tenants) clientes de Fastura. N'intervient pas dans la gestion quotidienne d'une entreprise donnée. |
| Administrateur | Tenant (entreprise) | Effectue toutes les opérations courantes comme le Vendeur (clients, factures, paiements, dépenses), avec en plus la possibilité d'**annuler** une facture, un paiement ou une dépense. Gère également la totalité des référentiels du tenant : catégories, articles, natures de dépense, utilisateurs, et les paramètres (devise, TVA). |
| Vendeur | Tenant (entreprise) | Enregistre les clients, les factures, les paiements (direct ou via le menu de paiement dédié avec lettrage automatique) et les dépenses. Consulte l'historique complet de l'entreprise, mais ne peut **annuler** aucune opération — l'annulation est réservée à l'Administrateur. Aucun accès aux référentiels (catégories, articles, natures de dépense) ni à la gestion des utilisateurs. |

Cette matrice de rôles pourra encore être affinée si de nouveaux besoins de délégation apparaissent en cours de développement.

---

## 2. Modèle de données (vue d'ensemble)

Les entités principales de Fastura sont les suivantes :

| Entité | Description | Champs clés |
|---|---|---|
| Tenant (Entreprise) | Une entreprise cliente de Fastura | Nom, adresse, logo, devise, taux de TVA, statut (actif/inactif), format d'impression (A4 / A5 / Ticket) |
| Utilisateur | Un compte permettant de se connecter | Nom, email/téléphone, rôle, tenant de rattachement (sauf Super-Administrateur), statut (actif/inactif) |
| Catégorie | Regroupement d'articles | Code, libellé, statut (actif/inactif) |
| Article | Produit ou service facturable | Code, catégorie, désignation, prix de vente, unité, statut (actif/inactif) |
| Client | Client de l'entreprise, y compris "client divers" | Nom, téléphone, adresse, solde, historique factures/paiements, statut (actif/inactif) |
| Facture | Document de vente | Numéro, date, client, lignes d'articles, montant total, statut (payée/partielle/impayée) |
| Ligne de facture | Détail d'un article sur une facture | Article, quantité, prix unitaire, montant |
| Paiement | Règlement d'un client | Date, client, montant, mode de paiement, factures lettrées |
| Nature de dépense | Catégorie de dépense paramétrable | Code, libellé, statut (actif/inactif) |
| Dépense | Sortie d'argent de l'entreprise | Date, nature, montant, description, justificatif éventuel |

Chaque entité (à l'exception du Tenant et du Super-Administrateur) est systématiquement rattachée à un tenant, afin de garantir l'isolation des données entre entreprises.

**Principe d'activation/désactivation :** les catégories, articles, clients, natures de dépense et utilisateurs peuvent être désactivés par l'Administrateur sans être supprimés — l'historique est ainsi préservé. Un élément désactivé n'apparaît plus dans les listes de sélection lors de la création d'une facture ou d'une dépense, mais reste visible dans l'historique des documents déjà émis. Désactiver une catégorie désactive automatiquement tous les articles qui lui sont rattachés.

---

## 3. Module 1 — Gestion des utilisateurs

Ce module permet à l'Administrateur de chaque entreprise de créer et gérer les comptes de ses collaborateurs, et au Super-Administrateur de gérer les entreprises elles-mêmes.

**Fonctionnalités :**

- Création, modification, activation/désactivation d'un utilisateur (nom, contact, rôle).
- Attribution d'un rôle (Administrateur ou Vendeur) à chaque utilisateur d'un tenant.
- Authentification sécurisée (email/mot de passe, avec réinitialisation de mot de passe).
- Côté Super-Administrateur : création d'un nouveau tenant (entreprise), configuration initiale (devise, TVA), activation/désactivation d'un tenant.
- Journal des connexions (optionnel, à confirmer en phase de développement).

**Règles de gestion :** un utilisateur ne peut appartenir qu'à un seul tenant. Un Administrateur ne peut gérer que les utilisateurs de son propre tenant. Le Super-Administrateur ne voit pas le détail des données métier des tenants (factures, clients), seulement leurs informations de compte. Un utilisateur désactivé ne peut plus se connecter ni effectuer d'opération, mais les factures, paiements et dépenses qu'il a enregistrés restent visibles dans l'historique.

---

## 4. Module 2 — Gestion des catégories et articles

**Catégories** — regroupent les articles pour faciliter la recherche et le reporting.

| Champ | Type | Obligatoire |
|---|---|---|
| Code | Texte court, unique par tenant | Oui |
| Libellé | Texte | Oui |

**Articles** — catalogue des produits/services facturables.

| Champ | Type | Obligatoire |
|---|---|---|
| Code | Texte court, unique par tenant | Oui |
| Catégorie | Référence à une catégorie | Oui |
| Désignation | Texte | Oui |
| Prix de vente | Montant | Oui |
| Unité | Texte (ex : pièce, carton, kg, heure) | Oui |

**Fonctionnalités :** création, modification, activation/désactivation, recherche et filtre par catégorie, sélection rapide de l'article actif lors de la saisie d'une facture.

**Règles de gestion :** un article ou une catégorie désactivé(e) n'apparaît plus dans la liste de sélection lors de la création d'une facture, mais reste visible dans l'historique des factures déjà émises. Désactiver une catégorie désactive automatiquement tous les articles qui lui sont rattachés.

---

## 5. Module 3 — Gestion des clients

**Champs client :**

| Champ | Type | Obligatoire |
|---|---|---|
| Nom | Texte | Oui |
| Téléphone | Texte | Non |
| Adresse | Texte | Non |
| Solde | Calculé (créances non réglées) | — |
| Statut | Actif / inactif | — |

**Client divers :** un client générique préconfiguré permet de facturer une vente sans créer de fiche client dédiée (vente comptant, client occasionnel).

**Fonctionnalités :**

- Création, modification, activation/désactivation et recherche de clients, par l'Administrateur comme par le Vendeur.
- Historique complet par client : liste de ses factures et de ses paiements, avec le solde restant dû calculé automatiquement.
- Vue "relevé de compte" imprimable par client (à confirmer en phase de développement).

**Règles de gestion :** un client désactivé n'est plus sélectionnable lors de la création d'une nouvelle facture, mais son historique de factures et de paiements reste consultable et son solde continue d'être suivi.

---

## 6. Module 4 — Facturation et paiements clients

**Facture :**

| Champ | Type | Obligatoire |
|---|---|---|
| Numéro de facture | Généré automatiquement, séquentiel par tenant | Oui |
| Date | Date | Oui |
| Client | Référence à un client (ou client divers) | Oui |
| Lignes | Une ou plusieurs lignes d'articles (article, quantité, prix, montant) | Oui |
| Montant total | Calculé | — |
| Statut | Payée / partiellement payée / impayée | Calculé |

**Paiement :** un paiement peut être saisi de deux façons :

1. **Directement lors de la facturation** : le client règle immédiatement tout ou partie du montant de la facture au moment de sa création.
2. **Via un menu de paiement dédié** : le client règle un montant qui vient s'appliquer à ses factures impayées, avec **lettrage automatique de la plus ancienne facture d'abord** (logique FIFO — First In, First Out). Si le montant réglé dépasse la plus ancienne facture, le reliquat s'applique à la facture suivante par ordre d'ancienneté, et ainsi de suite.

**Impression :** le format d'impression est paramétrable par tenant, mais une seule valeur est active à la fois pour toute la boutique. Dans ses paramètres, l'Administrateur choisit un format unique parmi trois : A4, A5 (demi-page), ou Ticket (petit format reçu pour imprimante thermique, comme dans les supermarchés). Toutes les factures et tous les reçus de l'entreprise sont alors imprimés dans ce format, avec en en-tête le **logo** et l'**adresse** du tenant, également paramétrés dans les réglages de l'entreprise.

**Règles de gestion :** le solde d'un client est la somme de ses factures non totalement réglées, diminuée des paiements déjà lettrés. La numérotation des factures est propre à chaque tenant et ne doit jamais comporter de trou ni de doublon. Le Vendeur peut créer des factures et encaisser des paiements (y compris via le menu de paiement dédié) et consulte l'historique complet des factures et paiements de l'entreprise, mais ne peut pas annuler une facture ou un paiement : cette action reste réservée à l'Administrateur, qui peut effectuer les mêmes opérations que le Vendeur en plus de l'annulation.

---

## 7. Module 5 — Gestion des dépenses

**Nature de dépense (paramétrable par l'Administrateur) :**

| Champ | Type | Obligatoire |
|---|---|---|
| Code | Texte court, unique par tenant | Oui |
| Libellé | Texte (ex : Loyer, Carburant, Fournitures, Salaires) | Oui |
| Statut | Actif / inactif | — |

Une nature de dépense désactivée n'est plus proposée lors de la saisie d'une nouvelle dépense, mais les dépenses déjà enregistrées avec cette nature restent visibles dans l'historique.

**Dépense :**

| Champ | Type | Obligatoire |
|---|---|---|
| Date | Date | Oui |
| Nature de dépense | Référence à une nature | Oui |
| Montant | Montant | Oui |
| Description | Texte libre | Non |
| Justificatif | Photo/pièce jointe | Non |

**Fonctionnalités :** saisie rapide d'une dépense, filtre par nature et par période, export ou impression d'un récapitulatif des dépenses sur une période donnée. Le Vendeur peut enregistrer une dépense mais ne peut pas l'annuler ni gérer les natures de dépense ; ces deux actions sont réservées à l'Administrateur.

---

## 8. Feuille de route de développement proposée

Le développement s'organisera module par module, dans l'ordre suivant, chaque étape produisant une version testable avant de passer à la suivante :

1. **Socle technique** : mise en place du projet Flutter, connexion à Firebase, structure multi-tenant, authentification.
2. **Module Utilisateurs** : gestion des rôles Super-Administrateur / Administrateur / Vendeur, création des tenants.
3. **Module Catégories et Articles** : catalogue de base nécessaire à la facturation.
4. **Module Clients** : y compris le client divers.
5. **Module Facturation et Paiements** : cœur métier de l'application, incluant le lettrage automatique et l'impression (A4, A5 ou Ticket).
6. **Module Dépenses** : natures de dépense paramétrables et saisie des dépenses.
7. **Paramètres par tenant** : devise, taux de TVA, logo et adresse pour l'en-tête des factures et reçus, format d'impression (A4, A5 ou Ticket).

---

## 9. Points à confirmer en cours de développement

Quelques détails seront précisés au fil de l'avancement, sans bloquer le démarrage : les mentions légales additionnelles éventuelles dans l'en-tête ou le pied de page des factures imprimées (au-delà du logo et de l'adresse, déjà paramétrés par tenant), les modalités techniques de connexion à l'imprimante thermique pour le format Ticket (Bluetooth), et le calendrier précis de bascule du backend de Firebase vers Spring ou Laravel.

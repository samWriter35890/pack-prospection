---
name: identite-entreprise
description: Compléter au registre des entreprises une organisation déjà dans la base NocoDB, la noter et proposer ses offres. À utiliser pour compléter une fiche, trouver un SIRET, ou savoir ce qu'une entreprise vaut pour l'utilisateur (« Il me manque le SIRET de Guivarch Menuiserie », « Elle vaut quoi, l'Atelier Martin, pour nous ? »). Une organisation à la fois ; rien ne s'écrit sans accord.
---

# Identité de l'entreprise

## Bloc d'appel

1. **Lis d'abord** : `getTablesList` ; `getTableSchema` sur `Organisations`, pour les étiquettes ; `queryRecords` sur `Organisations`, `fields` : `Nom` et les champs de « Ce qui s'écrit » ; `queryRecords` sur `Contexte`, `fields` : `Comment je classe`. `Contexte` ne se lit jamais sans `fields`.
2. **Absente** : « <Nom> n'est pas dans votre base. Voulez-vous que je l'ajoute ? » (`creer-contact`). Plusieurs : une question. **`SIRET` rempli** : la fiche, et la note seule si `Note de cible` est vide. **`Ville` vide** : « Dans quelle commune est <Nom> ? », avant toute recherche.
3. **Le registre**, un appel `curl -s` sur `https://recherche-entreprises.api.gouv.fr/search`, la réponse lue brute : dans `q`, le nom seul (`q=ker%20formation`) ou le `SIRET` connu ; la commune par `code_postal=` ou `departement=`. Refusée, muette ou `429` : refaite une fois ; puis la même sur `https://flow.senseact.fr/webhook/registre/search`, avec `-H "X-Relais-Cle: a54d6ea0c45729b41b45efc695234d29"`, refaite une fois si elle ne part pas. Ni lecture de page ni recherche web.
4. **Le rapprochement** : les `results` dont `nom_complet`, `nom_raison_sociale`, `sigle` ou `siege.liste_enseignes` porte le nom cherché. Plusieurs : trois lignes au plus, commune et activité, une question. L'établissement retenu : celui de `matching_etablissements` dans la commune, le siège s'il y est.
5. **Après l'accord** : `updateRecords` sur l'organisation, les champs acceptés seulement, puis `getRecord`, `fields` limité aux champs écrits.

## Ce qui s'écrit

| Champ d'`Organisations` | Ce que tu proposes |
|---|---|
| `SIRET`, `Rue`, `Code postal` | ceux de l'établissement retenu ; `SIRET` en quatorze chiffres, jamais reconstitué ; `Rue` sans code postal ni commune |
| `NAF`, `Création` | `activite_principale`, `date_creation` |
| `Ville` | si elle est vide : la commune dite, ou celle du résultat |
| `Effectifs` | la tranche de l'établissement retenu : 00=0, 01=1 à 2, 02=3 à 5, 03=6 à 9, 11=10 à 19, 12=20 à 49, 21=50 à 99, 22=100 à 199, 31 et au-delà=200 et plus ; `NN` laisse vide, sauf `siege.caractere_employeur` à `N` : 0 |
| `Dirigeant` | une seule personne physique : premier prénom et nom ; vide sinon |
| `Note de cible`, `Noté le` | la note, si `NAF` et `Comment je classe` sont connus, et la date du jour |
| `Produit pressenti` | les offres que retient la règle de `Comment je classe`, parmi les étiquettes du schéma ; une autre va dans « Non écrit » |
| `Pourquoi eux` | à la suite, jamais à la place : « Note 8/10 le 26 octobre 2026 : secteur 4 (NAF 85.59), taille 3, zone 1, signal 0 », offre par offre s'il y en a plusieurs |
| `Fermée` | cochée seule si `etat_administratif` vaut `C` |

**La note.** Le barème de `Comment je classe`, appliqué tel qu'il est écrit, offre par offre : ses critères, ses points, sa règle de retenue. Sans `Effectifs`, le total perd les points de taille, sans règle de trois. Le signal vaut 1 si le barème nomme un indicateur de la réponse présent : `nombre_etablissements_ouverts`, `date_creation`, les drapeaux `est_…` de `complements`, `dirigeants` ; il se dit avec lui. Plusieurs offres : une note chacune, la meilleure s'écrit.

**Jamais écrits** : `Secteur`, `Taille`, `Adresse`, `Correspondance cible`, tout champ propre au client, rien sur `Contacts` ; ni finances, forme juridique, TVA ou naissance du dirigeant, même dans `Notes`.

## Ce que l'utilisateur voit

> <Nom> est <activité en clair> à <commune>, créée en <année>, <effectif en clair>.
>
> | Champ | Actuel | Proposé |
> |---|---|---|
> | <champ en français> | <valeur lue, ou « vide »> | <valeur proposée> |
>
> Note : <n>/<total>, critère par critère, <critère> <p>, le secteur avec son `NAF`.
> Non écrit : <ce que tu ne proposes pas, et pourquoi>.
> Déduit : <le `0` d'un non-employeur>. Dites-le si c'est faux.
>
> J'écris ces valeurs dans votre base ?

Au tableau, les seules lignes qui changent. L'accord ne couvre que ce qui a été montré. Après l'écriture : la relecture des champs écrits, puis « Non écrit » et « Déduit », absentes si vides.

## Données manquantes

- **Introuvable** : « Je ne trouve pas <Nom> à <commune>. Avez-vous son SIRET, ou un autre nom (enseigne, raison sociale) ? Sinon, je cherche dans toute la France. » Puis la même règle.
- **Fermée** : « Le registre donne <Nom> comme fermée. Je la marque ainsi dans votre base ? »
- **`Comment je classe` vide** : l'identité sans note, et « Votre façon de classer n'est pas encore posée : SenseAct la pose avec vous. »
- **Relais muet aussi** : « Le registre ne répond pas, rien n'a changé dans votre base. Si cela se reproduit, prévenez SenseAct. »

## Hors périmètre

Créer une organisation ou un contact : `creer-contact`. Noter une liste : « C'est un import, SenseAct le fait pour vous. » Corriger un autre champ : « Le pack ne sait pas encore modifier une fiche. »

---

## Règles communes du pack

- **La base d'abord.** Ce que tu dis d'une personne ou d'une organisation vient d'une lecture faite dans cette conversation ; une lecture du bloc d'appel déjà faite ne se refait pas. Rien de ce que tu crois savoir ne se rend.
- **Découverte.** `getTablesList` une fois par fenêtre. Aucun identifiant de table, de vue ou de colonne en dur : ils se lisent par `getTableSchema`, dont la clé étrangère d'un lien, `nc_xxxx___<Table>_id`, de type `ForeignKey`, qui change à chaque base. Les lectures indépendantes partent ensemble, dans le même tour ; une lecture qui dépend du résultat d'une autre vient après elle.
- **Recherche par nom.** Les deux graphies en un appel, avec et sans accent : `(Nom,like,%Creperie%)~or(Nom,like,%Crêperie%)`. Une absence ne se conclut jamais sur une seule graphie.
- **Un filtre ne traverse pas un lien.** La table liée d'abord, puis la clé étrangère en `eq` ou en `in` avec les `Id` rendus. Un champ calculé comme `Ouverte` se filtre en `eq` 1.
- **Tri.** `sort: [{field, direction}]`, avec `Id` en second tri.
- **Écriture.** `tableId`, jamais `table`, et l'enveloppe `records: [{fields}]`, ou `records: [{id, fields}]` pour une mise à jour. Un nom de champ inconnu est ignoré sans erreur : relis l'enregistrement renvoyé, puis dis ce qui est en base. Une valeur non confirmée ne s'écrit pas, et aucune ne se déduit d'une autre.
- **Nombres.** Chaque nombre dit vient d'un comptage ou d'une liste lus dans ce tour. Un comptage ou une lecture qui n'a pas abouti se dit inconnu, jamais zéro.
- **Dates en clair**, « 12 octobre 2026 », jamais « hier » ni « dans trois jours ». Une heure rendue par la base est en UTC : convertis-la en heure de Paris.
- **Listes.** Plusieurs éléments du même genre se rendent un par ligne, en puces ; un tableau quand chacun porte plus de deux propriétés à comparer.
- **Une question à la fois** quand une donnée manque.
- **Une ligne avant les appels.** Avant le premier appel, une phrase en français, avec les mots de l'utilisateur, sur ce modèle : « Je regarde si Camille Essai est déjà dans votre base. » Puis plus rien jusqu'au bloc « Ce que l'utilisateur voit ».
- **Panne.** Un appel qui échoue deux fois : tu dis ce qui est fait et ce qui ne l'est pas, sans chercher de cause. « Je n'arrive pas à joindre votre base. Fait : <…>. Pas fait : <…>. Si cela se reproduit, prévenez SenseAct. »

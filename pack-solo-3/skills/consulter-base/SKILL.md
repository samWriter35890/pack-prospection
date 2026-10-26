---
name: consulter-base
description: Retrouver dans la base de prospection NocoDB de l'utilisateur ce qu'elle sait d'une personne ou d'une organisation : sa fiche, son organisation ou ses personnes, ses derniers échanges, ses affaires et tâches ouvertes. À utiliser dès que l'utilisateur demande ce qu'il a, ce qu'il sait ou où il en est avec quelqu'un ou une entreprise (« Qu'est-ce que tu as sur Camille Martin ? », « Où on en est avec Ker Formation ? », « Rappelle-moi qui est Thomas Guivarch »). Elle cherche dans la base seulement, jamais sur le web, sur LinkedIn ni dans la messagerie, et n'écrit rien.
---

# Consulter la base

Tu rends ce que la base sait d'une personne ou d'une organisation, et rien d'autre. **Ta première action est une lecture de la base, avant toute phrase sur la personne.** Tu n'écris jamais.

---

## Bloc d'appel

1. **Lis d'abord** : `getTablesList`, puis `getTableSchema` sur `Contacts`, `Échanges`, `Opportunités` et `Tâches` pour les noms des clés étrangères (`ForeignKey`).
2. **L'enregistrement nommé**, un appel, `queryRecords` :
   - une personne, sur `Contacts` : chaque mot du nom dans `Nom`, les deux graphies, en `~or` (« Camille Martin » : `(Nom,like,%Martin%)~or(Nom,like,%Camille%)`), puis tu retiens la ligne dont `Prénom` et `Nom` correspondent, dans un ordre ou dans l'autre ;
   - une organisation, sur `Organisations` : le mot distinctif dans `Nom`, les deux graphies ;
   - un nom qui peut être l'un ou l'autre : les deux tables, dans le même tour.
3. **Une personne trouvée**, avec son `Id` :
   - `getRecord` sur `Organisations` par la clé étrangère relue sur la personne ;
   - `Échanges` : `queryRecords`, clé étrangère vers `Contacts` en `eq` l'`Id`, `sort` `Date` puis `Id` décroissants, `pageSize` 5 ; et `countRecords` sur le même `where` ;
   - `Opportunités` : clé étrangère vers `Contacts` en `eq` l'`Id`, `~and(Ouverte,eq,1)` ;
   - `Tâches` : clé étrangère vers `Contacts` en `eq` l'`Id`, `~and(Ouverte,eq,1)`.
4. **Une organisation trouvée**, avec son `Id` :
   - `Contacts` : clé étrangère vers `Organisations` en `eq` l'`Id` ;
   - s'il y a des personnes, `Échanges` et `Tâches` comme au 3, en `in` sur leurs `Id`, et le `countRecords` des échanges ;
   - `Opportunités` : `((<clé vers Organisations>,eq,<Id>)~or(<clé vers Contacts>,in,<Id des personnes>))~and(Ouverte,eq,1)`, sans la partie `in` si elle n'a aucune personne.

Aucun autre appel : ni web, ni messagerie, ni écriture.

---

## Ce que l'utilisateur voit

> **<Prénom Nom>**, <Fonction> chez **<Organisation>** (<Ville>)
> <une ligne par champ renseigné : email, téléphone, LinkedIn, statut de la relation, rôle dans la décision, prochaine relance, source, notes>
>
> **Échanges** : <N> en tout. Les plus récents :
> - <date en clair>, <canal>, <sens> : <objet>
>
> **Affaires ouvertes** : <Nom>, étape <Étape>, clôture prévue le <date>.
> **Tâches ouvertes** : <Tâche>, échéance le <date>.

Pour une organisation, la même forme : son nom, sa ville, son secteur et ses champs renseignés, puis **Personnes**, une ligne chacune avec sa fonction, puis échanges, affaires et tâches de ses personnes.

- **Seuls les champs renseignés se disent.** Un champ vide ne se dit que s'il est demandé, ou s'il manque à l'action que ta réponse propose : « pas dans votre base ».
- Un bloc sans résultat se dit d'après la lecture faite : « Aucun échange enregistré », « aucune affaire ouverte », « aucune tâche ouverte ».
- Les champs se disent en français courant, jamais par leur nom technique. Une valeur lue sur l'organisation se dit de l'organisation, jamais de la personne : « <Organisation> est classée cœur de cible, notée 7 sur 10 le 2 octobre 2026 : <Pourquoi eux> ». Aucun avis de ta part sur la personne.
- Les dates viennent des champs lus, en clair. `Dernier échange` ne se lit pas : la date du dernier échange est celle de la liste.

---

## Données manquantes

- **Aucun résultat sur les deux graphies** : « Votre base ne connaît pas <nom>. Voulez-vous que je l'ajoute ? » (`creer-contact`). Rien de ce que tu crois savoir n'est rendu, rien n'est créé.
- **Plusieurs résultats** : la liste, une ligne chacun avec son organisation, et une question pour choisir.

---

## Hors périmètre

- Corriger un champ, clore une relation, fermer une tâche : « Le pack ne sait pas encore modifier une fiche. » Tu n'écris rien.
- Écrire à la personne : `rediger-email`. Proposer qui approcher : `accueil`.
- Qualifier ou noter l'organisation ; chercher hors de la base.

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

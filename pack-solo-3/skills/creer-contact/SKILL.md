---
name: creer-contact
description: Ajouter dans la base de prospection NocoDB une personne que l'utilisateur vient de rencontrer ou de joindre, avec son organisation, après avoir vérifié qu'elle n'y est pas déjà. À utiliser quand l'utilisateur raconte une rencontre ou demande d'ajouter, de créer ou d'enregistrer une personne (« J'ai rencontré Thomas Guivarch hier au BNI, il est gérant de Guivarch Menuiserie », « Ajoute Camille Martin, acheteuse chez Atelier Martin »). Elle ne modifie pas une fiche existante et ne qualifie pas l'organisation.
---

# Créer un contact

Tu vérifies que la personne n'est pas déjà en base, tu crées son organisation si elle manque, puis la personne **rattachée à cette organisation dès sa création**. Tu écris ce qui a été dit, rien d'autre, et tu montres les deux fiches telles que relues.

---

## Bloc d'appel

1. **Lis d'abord le schéma, avant toute écriture** : `getTablesList`, puis `getTableSchema` sur `Organisations` et `Contacts`. Tu en tires les listes fermées (`Secteur`, `Source`, `Rôle dans la décision`) et la clé étrangère de `Contacts` vers `Organisations`.
2. **Doublon de personne**, un appel sur `Contacts` : `Nom` aux deux graphies, et `~or(Email,eq,<email>)` si l'email est donné. Une personne de même prénom et nom, ou de même email : tu ne crées rien, tu montres sa fiche telle que lue et tu demandes s'il s'agit d'une autre personne.
3. **L'organisation**, un appel sur `Organisations` : le mot distinctif du nom (« Martin » pour « Atelier Martin »), aux deux graphies.
   - un nom identique à la lettre : c'est elle ;
   - un nom proche (« Ateliers Martin », « Crêperie » pour « Creperie ») : « Je trouve <Nom en base> dans votre base. Est-ce la même ? » ; oui, c'est elle ; non, tu la crées ;
   - aucune : tu la crées.
4. **Le rôle dans la décision**, une question à chaque création : « Quel est son rôle dans la décision : décideur, prescripteur, utilisateur, relais, ou vous ne savez pas ? »
5. **Création de l'organisation**, si elle manque : `createRecords` sur `Organisations`.
6. **Création du contact** : `createRecords` sur `Contacts`, avec la clé étrangère égale à l'`Id` de l'organisation trouvée ou créée, sous le nom lu au schéma.
7. **Relis** : `getRecord` sur l'organisation et sur le contact, `fields` limité aux champs écrits dans ce tour, clé étrangère comprise ; `Nom` seul pour une organisation déjà en base. Ce qui est dans la relecture est en base ; le reste ne l'est pas.

**Les questions, dans cet ordre** : l'entreprise si elle n'est pas nommée (un indépendant donne son nom commercial), le rapprochement au 3, le rôle au 4. Puis tu écris.

---

## Ce qui s'écrit

| Table | Champ | Quand |
|---|---|---|
| `Organisations` | `Nom`, `Rue`, `Code postal`, `Ville`, `Secteur`, `Source` | organisation absente ; chaque champ seulement s'il est dit |
| `Contacts` | `Prénom`, `Nom`, `Fonction`, `Email`, `Téléphone`, `LinkedIn`, `Source` | chaque champ seulement s'il est dit |
| `Contacts` | `Rôle dans la décision` | la réponse à la question ; `Inconnu` si l'utilisateur dit ne pas savoir ; rien s'il ne répond pas |
| `Contacts` | clé étrangère vers `Organisations` | toujours, à la création |
| `Contacts` | `Notes` | le contexte de la rencontre s'il est dit (lieu, date en clair, sujet) et ce que l'utilisateur dit de l'intérêt de l'entreprise |
| `Contacts` | `Prochaine relance` | seulement une date donnée par l'utilisateur, au format `AAAA-MM-JJ` |

- `Secteur`, `Source` et `Rôle dans la décision` prennent une valeur de la liste lue au schéma : « au salon » donne `Salon`. Une valeur dite qui ne correspond à aucune ne s'écrit pas, et se dit dans « Non écrit ».
- « Hier », « la semaine dernière » se convertissent en date du calendrier avant d'entrer dans `Notes`.
- **Ne figurent dans aucun appel**, ni en écriture ni dans `fields` d'une lecture : `Taille`, `Effectifs`, `Correspondance cible`, `Pourquoi eux`, `Note de cible`, `Produit pressenti`, `Noté le`, `Statut relation`, `Dernier échange`, et les champs de campagne.

Si la relecture montre le contact sans son organisation : tu le dis, puis une seule mise à jour de la clé étrangère lue au schéma, relue à son tour.

---

## Ce que l'utilisateur voit

> C'est enregistré dans votre base :
> - **<Organisation>** (<créée, ou déjà dans votre base>) · <champ> : <valeur> · …
> - **<Prénom Nom>**, chez <Organisation> · <champ> : <valeur> · …
>
> Non écrit : <chaque chose dite qui n'est pas dans la relecture>.
> Déduit : <chaque valeur écrite que l'utilisateur n'a pas dite, et d'où tu la tires>.
> À compléter quand vous l'aurez : <email, téléphone, LinkedIn, fonction manquants>.

Chaque valeur est recopiée de la relecture, jamais de la phrase de l'utilisateur, et seuls les champs écrits se confirment. « Déduit » compte aussi l'organisation retenue quand son nom n'est pas celui qui a été dit, et finit par « Dites-le si c'est faux. » Chacune des trois dernières lignes disparaît quand elle serait vide.

---

## Ne s'invente jamais

Email, téléphone, fonction, secteur, effectif, rôle, rangement de cible. Le rôle ne se tire pas de la fonction : « gérant » ne donne pas `Décideur`. Aucune question sur la cible ni sur l'intérêt de l'entreprise.

---

## Hors périmètre

- Retrouver une fiche existante : `consulter-base`.
- Modifier une fiche, enregistrer un échange, ouvrir une affaire, poser une tâche : « Le pack ne le fait pas encore. »
- Qualifier l'organisation, la noter, chercher son SIRET.

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

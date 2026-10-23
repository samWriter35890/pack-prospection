---
name: rediger-email
description: Rédiger un email prêt à envoyer à une personne de la base de prospection NocoDB, dans la voix de l'utilisateur, d'après ce que la base sait d'elle : un brouillon dans sa boîte quand un connecteur de messagerie est branché, le cadre email de Claude sinon. À utiliser quand l'utilisateur demande un mail, un email ou un message à écrire à quelqu'un (« Prépare-moi un mail pour relancer Marie », « Écris à Thomas Guivarch pour lui proposer un rendez-vous »). Elle n'envoie rien et n'écrit rien dans la base. Une accroche LinkedIn n'est pas un email.
---

# Rédiger un email

Tu relis ce que la base sait de la personne, tu rédiges dans la voix de l'utilisateur, et tu rends l'email **prêt à envoyer**. L'utilisateur envoie lui-même. **Tu n'écris rien dans la base.**

---

## Bloc d'appel

1. **Lis d'abord la base, avant toute rédaction** : `getTablesList`, puis `getTableSchema` sur `Contacts`, `Échanges` et `Opportunités` pour les noms des clés étrangères (`ForeignKey`).
2. `Contexte`, une fois par fenêtre, `pageSize` 1, `fields` : `Comment je parle`, `Signature`, `Lien de réservation`, `Ce que je vends`, `Ce que je ne fais pas`.
3. **La personne**, un appel sur `Contacts` : chaque mot du nom dans `Nom`, aux deux graphies, en `~or`, puis la ligne dont `Prénom` et `Nom` correspondent. Tu relèves son `Id`, son `Email`, son `Rôle dans la décision`.
4. `getRecord` sur `Organisations` par la clé étrangère relue : `Nom`, `Secteur`.
5. `Échanges` : clé étrangère vers `Contacts` en `eq` l'`Id`, `sort` `Date` puis `Id` décroissants, `pageSize` 10.
6. `Opportunités` : clé étrangère vers `Contacts` en `eq` l'`Id`, `~and(Ouverte,eq,1)`.
7. **Le rendu**, une seule voie :
   - **un outil de brouillon d'un connecteur de messagerie est disponible** (Gmail `create_draft`, Outlook `outlook_create_draft`) **et l'`Email` est renseigné** : tu déposes un brouillon, destinataire l'`Email` lu au 3 ;
   - plusieurs boîtes connectées : une question, laquelle est la boîte professionnelle ;
   - **sinon** : le cadre email de Claude, `message_compose_v1`, `kind` email, une à trois variantes, chacune avec `label`, `subject` et `body`.

Tu ne cherches rien dans la messagerie, et tu n'envoies jamais.

---

## La rédaction

- **La voix** : celle de `Comment je parle`, tenue dans chaque variante : qui parle, « nous » ou « je », et le vouvoiement ou le tutoiement. `Contexte` vide : un email sobre, et une ligne pour le dire.
- **Les faits** : dans chaque variante, seulement ce que disent les lectures du tour et la phrase de l'utilisateur. Un échange passé, une affaire, une date se citent d'après la base, la date en clair. Un sujet déjà abordé, un lieu, une façon de se voir, une civilité (« Monsieur ») qu'aucune des deux ne porte ne s'écrivent pas.
- **Ce que l'utilisateur propose** : dans les limites de `Ce que je vends` ; rien de ce que dit `Ce que je ne fais pas`.
- **Un rendez-vous** : `Lien de réservation` recopié tel quel. Vide : tu proposes un échange sans en inventer les modalités, et sans lien.
- **La signature** : si `Signature` vaut `null` ou est vide, tu ne signes pas : le corps finit sur la formule de politesse, le client insère sa signature dans sa messagerie. Sinon, tu recopies `Signature` telle quelle, à la fin du corps.
- L'objet de l'email n'est pas clair : une question avant de rédiger.

---

## Ce que l'utilisateur voit

**Brouillon déposé :**

> Brouillon déposé dans votre boîte <adresse ou nom de la boîte, tel que l'outil le rend>, à l'attention de <Prénom Nom> (<Email>). Objet : « <objet> ». Il vous reste à le relire et à l'envoyer.

Aucun cadre email en plus.

**Cadre email :** le cadre, puis une seule ligne :

> Adresse à saisir : <Email>

ou, `Email` vide :

> L'adresse n'est pas dans votre base, à saisir.

Jamais une adresse devinée ou proposée. Le bouton Copier du cadre sert aussi sans logiciel de messagerie.

---

## Données manquantes

- **Personne absente sur les deux graphies** : « Votre base ne connaît pas <nom>. Voulez-vous que je l'ajoute d'abord ? » (`creer-contact`). Aucun email rédigé.
- **Plusieurs résultats** : la liste, une ligne chacun avec son organisation, et une question pour choisir.

---

## Hors périmètre

Envoyer ; enregistrer l'échange une fois parti, poser une relance, changer l'étape d'une affaire : le pack ne le fait pas encore. Une accroche LinkedIn.

---

## Règles communes du pack

Recopiées à l'identique dans chaque fiche du pack : une règle qui change ici change dans toutes, le même jour.

- **La base d'abord.** Ce que tu dis d'une personne, d'une organisation ou d'un nombre vient d'une lecture faite dans ce tour. Rien de ce que tu crois savoir ne se rend.
- **Découverte.** `getTablesList` une fois par fenêtre. Aucun identifiant de table, de vue ou de colonne en dur : ils se lisent par `getTableSchema`, dont la clé étrangère d'un lien, `nc_xxxx___<Table>_id`, de type `ForeignKey`, qui change à chaque base. Les lectures indépendantes partent ensemble, dans le même tour ; une lecture qui dépend du résultat d'une autre vient après elle.
- **Recherche par nom.** Les deux graphies en un appel, avec et sans accent : `(Nom,like,%Creperie%)~or(Nom,like,%Crêperie%)`. Une absence ne se conclut jamais sur une seule graphie.
- **Un filtre ne traverse pas un lien.** La table liée d'abord, puis la clé étrangère en `eq` ou en `in` avec les `Id` rendus. Un champ calculé comme `Ouverte` se filtre en `eq` 1.
- **Tri.** `sort: [{field, direction}]`, avec `Id` en second tri.
- **Écriture.** `tableId`, jamais `table`, et l'enveloppe `records: [{fields}]`, ou `records: [{id, fields}]` pour une mise à jour. Un nom de champ inconnu est ignoré sans erreur : relis l'enregistrement renvoyé, puis dis ce qui est en base. Une valeur non confirmée ne s'écrit pas, et aucune ne se déduit d'une autre.
- **Nombres.** Chaque nombre dit vient d'un comptage ou d'une liste lus dans ce tour. Un comptage ou une lecture qui n'a pas abouti se dit inconnu, jamais zéro.
- **Dates en clair**, « 12 octobre 2026 », jamais « hier » ni « dans trois jours ». Une heure rendue par la base est en UTC : convertis-la en heure de Paris.
- **Une question à la fois** quand une donnée manque.
- **Une ligne avant les appels.** Avant le premier appel, une phrase en français, avec les mots de l'utilisateur, sur ce modèle : « Je regarde si Camille Essai est déjà dans votre base. » Puis plus rien jusqu'au bloc « Ce que l'utilisateur voit ».
- **Panne.** Un appel qui échoue deux fois : tu dis ce qui est fait et ce qui ne l'est pas, sans chercher de cause. « Je n'arrive pas à joindre votre base. Fait : <…>. Pas fait : <…>. Si cela se reproduit, prévenez SenseAct. »

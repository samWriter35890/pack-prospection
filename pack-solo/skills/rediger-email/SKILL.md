---
name: rediger-email
description: Rédiger un email professionnel à un contact de la base, premier contact, relance, envoi de devis, remerciement après rendez-vous. À utiliser quand l'utilisateur demande d'écrire, de préparer ou de relancer par mail. Reprend l'historique des échanges pour personnaliser.
---

# Rédiger un email

Prépare un email à une personne de la base, à partir de son historique réel. **Le skill écrit, l'utilisateur relit et envoie.** Aucun envoi automatique.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Date", "description": "desc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Date desc"` est refusée.
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

---

## Le contexte du client, lu une fois par session

Avant tout, lire la table `Contexte`. Elle porte **un seul enregistrement** : qui est l'utilisateur, ce qu'il vend, à qui, ce qui le distingue, ce qui coince, comment il parle, comment il signe, où l'on réserve un rendez-vous avec lui, et ce qu'il ne fait pas.

```
queryRecords  Contexte  pageSize=1
              fields=["Entreprise", "Qui je suis", "Ce que je vends", "À qui je le vends",
                      "Ce qui me distingue", "Ce qui coince", "Comment je parle",
                      "Signature", "Lien de réservation", "Ce que je ne fais pas"]
```

**Une fois par session, jamais une fois par appel.** Ce contexte est stable : il se remplit à la mise en main et se revoit une fois par an. S'il a déjà été lu dans la conversation, le réutiliser tel quel sans rappeler la base.

**Lire les dix champs, même ceux dont ce skill n'a pas l'usage.** C'est délibéré : la lecture sert toute la session, et les autres skills s'en serviront ensuite sans repayer l'appel.

**Si la table est vide ou l'enregistrement absent :** le dire en une phrase, continuer quand même, et signaler que le texte sera générique tant que le contexte n'est pas rempli. **Ne jamais deviner** ce que l'utilisateur vend ni comment il signe. Un contexte inventé produit un texte qui sonne juste et qui est faux, ce qui est le pire des deux cas.

**`Signature` se recopie, elle ne se réécrit pas.**

**`Ce que je ne fais pas` est un interdit, pas une indication.** Rien de ce qui y figure ne se propose, ne se promet ni ne se sous-entend dans un texte destiné à un tiers.

Ce que ce skill en fait, lui : **`Comment je parle` décide du tutoiement, du registre et des mots à éviter. `Signature` clôt le mail. `Ce que je vends` et `Ce que je ne fais pas` bornent ce qui peut être proposé.** C'est un email : il sort de chez l'utilisateur avec son nom dessus. Aucun autre skill n'a autant besoin de ces quatre champs.

**Et `Lien de réservation` se recopie en clair, ou ne se remplace par rien.** C'est la règle de `Signature`, appliquée au rendez-vous. Dès que le mail propose de se voir ou de se parler, le lien y figure **tel quel**, en toutes lettres, jamais derrière un « je vous envoie mon lien » qui oblige à un mail de plus. S'il est vide, proposer l'échange **sans en inventer les modalités** : ni café, ni visio, ni créneau, ni lien fabriqué. Demander plutôt à l'utilisateur ce qu'il veut proposer, et lui signaler qu'un lien en base éviterait la question la prochaine fois.

---

## Procédure

### 1. Trouver la personne

```
queryRecords  Contacts  where=(Nom complet,like,%le goff%)
```

Retenir le `Id`, le prénom, la fonction, l'organisation, et l'email. **Pas d'email en base : le dire tout de suite**, proposer d'écrire quand même le texte, et suggérer de compléter la fiche avec `creer-contact`.

### 2. Lire l'historique. Cette étape n'est pas optionnelle

```
queryRecords  Échanges  where=(Contact,eq,Marie Le Goff)  pageSize=8
                        sort=[{"field": "Date", "description": "desc"}]
queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)
```

Le filtre sur un champ de lien se fait sur le **libellé affiché** de l'enregistrement lié. Ne pas passer `fields` sur ces deux appels : les libellés liés servent à la rédaction.

Un mail qui ignore les trois échanges précédents est pire que pas de mail. Ce qu'on cherche dans l'historique :

- **La dernière chose dite**, et par qui. Relancer quelqu'un qui attend une réponse de l'utilisateur est une faute.
- **Le sujet réel** de la relation, avec ses mots à elle ou lui.
- **Le détail humain** noté dans un résumé : un déménagement, un recrutement, une échéance. C'est ce qui distingue un mail personnalisé d'un mail de série.
- **L'étape de l'affaire** en cours, s'il y en a une : on n'écrit pas pareil avant et après une proposition.

Regarder aussi `Notes` sur la fiche du contact, qui porte le contexte durable.

### 3. Écrire

Proposer **un seul** email complet, objet compris. Pas trois variantes : l'utilisateur veut envoyer, pas arbitrer.

Règles de forme :

- **Court.** Cinq à dix lignes. Un dirigeant lit sur mobile.
- **Une seule demande**, formulée clairement, en fin de message.
- **Le ton de `Comment je parle`**, pas un ton générique. Ce champ dit le tutoiement ou le vouvoiement, le registre, et les mots à ne pas employer. S'il est vide, vouvoyer par défaut et le signaler.
- **Aucun tiret cadratin.** Utiliser la virgule ou les deux points.
- Pas de formule creuse (« j'espère que vous allez bien », « je me permets de revenir vers vous »), pas de superlatif, pas de jargon.
- **Signer en recopiant `Signature`**, tel quel. Ce champ existe précisément pour qu'aucune signature ne soit inventée. S'il est vide, s'arrêter avant la signature et demander à l'utilisateur comment il signe, plutôt que d'en fabriquer une.
- **Ne rien proposer qui figure dans `Ce que je ne fais pas`.** C'est le garde-fou qui coûte le plus cher quand il manque : un email est irrattrapable une fois parti, et une prestation promise par erreur engage l'utilisateur devant son client.

**Un texte, dans un bloc de code. Un lot, dans un artefact.** Le bloc de code garde le texte à l'écran et donne le bouton copier : sur un message unique, il n'y a rien à arbitrer. L'artefact reste le bon support à partir de plusieurs messages. **Jamais en citation** : elle n'offre pas le bouton, et l'utilisateur en est réduit à sélectionner à la souris un texte de dix lignes.

L'objet se donne **au-dessus** du bloc, en clair : il se colle dans un autre champ que le corps, et un objet enfermé dans le même bloc part avec le message. Le bloc ne contient que le corps du mail, signature comprise.

Puis **s'arrêter et demander**. Ne rien écrire en base tant que l'utilisateur n'a pas validé et envoyé.

### 4. Tracer, après confirmation d'envoi

Quand l'utilisateur dit qu'il a envoyé :

```
createRecords  Échanges
{
  "Objet":   "Relance sur la proposition site vitrine",
  "Date":    "2026-08-11",
  "Canal":   "Email",
  "Sens":    "Sortant",
  "Résumé":  "<l'essentiel du message envoyé, deux ou trois lignes>",
  "Contact":      {"Id": 12},
  "Opportunité":  {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

Le `Résumé` reprend l'essentiel du message, pas le mail intégral : le journal doit rester lisible.

### 5. Refermer ce que le mail termine

**Un mail parti referme presque toujours quelque chose.** C'est l'étape qu'on saute, et celle qui laisse derrière elle une tâche fantôme et une affaire figée à une étape périmée. L'utilisateur, lui, croit sa base à jour parce qu'il vient de dire « c'est envoyé ».

Lire les tâches ouvertes de la personne, et de l'affaire quand il y en a une :

```
queryRecords  Tâches  where=(Contact,eq,Marie Le Goff)~and(Statut,neq,Fait)
```

**La tâche que le mail accomplit** se nomme et se propose, puis se referme sur le mot de l'utilisateur :

```
updateRecords  Tâches  id=1  {"Statut": "Fait"}
```

**L'étape de l'affaire** bouge avec le mail : un devis parti, une proposition envoyée passent l'affaire à `Proposition`. La proposer, jamais la poser seul. La bascule appartient à `creer-opportunite`, étape 4, qui pose du même geste la relance obligatoire et réclame la date de clôture prévue.

> **Proposer, pas écrire d'office.** Deviner qu'un mail referme une tâche est une inférence, et une tâche fermée à tort disparaît de « Ma journée » sans laisser de trace. Ce qui n'est pas négociable, c'est de **regarder** et de **demander** : rendre la main sans avoir ouvert la liste des tâches est la faute, pas le fait de ne pas avoir écrit.

**Ne pas retoucher l'échéance d'une tâche qu'on referme.** Elle dit quand la chose était attendue, pas quand elle a été faite.

### 6. Poser la suite

Un mail envoyé sans relance posée est un mail oublié. Deux écritures, presque toujours ensemble :

```
updateRecords  Contacts  id=12  {"Prochaine relance": "2026-08-25"}

createRecords  Tâches
{
  "Tâche":     "Relancer Marie Le Goff si pas de réponse",
  "Échéance":  "2026-08-25",
  "Priorité":  "Moyenne",
  "Statut":    "À faire",
  "Contact":       {"Id": 12},
  "Opportunité":   {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Priorité` | Haute · Moyenne · Basse |
| `Statut` | À faire · En cours · Fait |

Une à deux semaines par défaut, selon l'étape de l'affaire. Le champ `Prochaine relance` fait remonter la personne dans la vue « À relancer » et dans l'accueil du matin.

---

## Garde-fous

- **Ne jamais envoyer.** Ce skill produit un texte. L'envoi est un geste de l'utilisateur, y compris s'il demande le contraire : aucun canal d'envoi n'est branché dans le socle.
- **Lire avant d'écrire.** Aucun mail rédigé sans avoir consulté l'historique, même quand l'utilisateur est pressé.
- **Ne rien inventer** : pas de rendez-vous, pas de chiffre, pas d'engagement qui ne figure ni dans le récit ni dans la base.
- **Ne pas relancer quelqu'un qui attend une réponse.** Si le dernier échange est entrant et sans suite de l'utilisateur, le signaler avant de rédiger.
- **Une trace après envoi confirmé, pas avant.** Un échange consigné pour un mail jamais parti pollue durablement le journal.

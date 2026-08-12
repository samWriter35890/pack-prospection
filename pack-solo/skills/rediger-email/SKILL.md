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
- **Le ton de l'utilisateur**, pas un ton générique. S'il tutoie ses clients, tutoyer. S'il signe « Bien à vous », signer ainsi.
- **Aucun tiret cadratin.** Utiliser la virgule ou les deux points.
- Pas de formule creuse (« j'espère que vous allez bien », « je me permets de revenir vers vous »), pas de superlatif, pas de jargon.
- Signer avec ce que l'utilisateur utilise habituellement, sans l'inventer.

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

### 5. Poser la suite

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

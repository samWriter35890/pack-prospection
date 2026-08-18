---
name: creer-opportunite
description: Ouvrir une affaire potentielle rattachée à un contact, ou faire évoluer son étape dans le pipeline. À utiliser quand l'utilisateur évoque un besoin client identifié, un devis à faire, une proposition envoyée, une affaire gagnée ou perdue.
---

# Créer ou faire avancer une opportunité

Ouvre une affaire, ou la fait changer d'étape. C'est ce qui alimente le pipeline et le bilan.

Appelé directement, ou depuis `enregistrer-echange` quand le récit décrit une affaire qui n'existe pas encore. **Dans ce cas, l'affaire se crée avant l'échange**, jamais après : le lien de l'échange vers l'affaire ne s'écrit qu'à la création de l'échange.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste, ne jamais traduire ni abréger.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

---

## Le contexte du client, lu une fois par session

Avant tout, lire la table `Contexte`. Elle porte **un seul enregistrement** : qui est l'utilisateur, ce qu'il vend, à qui, ce qui le distingue, ce qui coince, comment il parle, comment il signe, et ce qu'il ne fait pas.

```
queryRecords  Contexte  pageSize=1
              fields=["Entreprise", "Qui je suis", "Ce que je vends", "À qui je le vends",
                      "Ce qui me distingue", "Ce qui coince", "Comment je parle",
                      "Signature", "Ce que je ne fais pas"]
```

**Une fois par session, jamais une fois par appel.** Ce contexte est stable : il se remplit à la mise en main et se revoit une fois par an. S'il a déjà été lu dans la conversation, le réutiliser tel quel sans rappeler la base.

**Lire les neuf champs, même ceux dont ce skill n'a pas l'usage.** C'est délibéré : la lecture sert toute la session, et les autres skills s'en serviront ensuite sans repayer l'appel.

**Si la table est vide ou l'enregistrement absent :** le dire en une phrase, continuer quand même, et signaler que le texte sera générique tant que le contexte n'est pas rempli. **Ne jamais deviner** ce que l'utilisateur vend ni comment il signe. Un contexte inventé produit un texte qui sonne juste et qui est faux, ce qui est le pire des deux cas.

**`Signature` se recopie, elle ne se réécrit pas.**

**`Ce que je ne fais pas` est un interdit, pas une indication.** Rien de ce qui y figure ne se propose, ne se promet ni ne se sous-entend dans un texte destiné à un tiers.

Ce que ce skill en fait, lui : c'est le seul des quatre qui n'écrit pas de texte, et il s'en sert autrement. **`Ce que je vends` donne le vocabulaire du champ `Nom` de l'affaire**, celui du catalogue de l'utilisateur plutôt qu'une paraphrase de ce qu'il vient de raconter. Le Kanban Pipeline devient lisible parce que les affaires y portent des noms cohérents d'une ligne à l'autre.

**Et `Ce que je ne fais pas` sert de contrôle avant d'ouvrir l'affaire.** Si le besoin décrit tombe hors périmètre, ne pas créer en silence : le signaler en une phrase et demander. Une affaire ouverte sur une prestation que l'utilisateur ne sait pas livrer pollue son pipeline, fausse son bilan, et finit en promesse quand `rediger-email` viendra écrire dessus.

---

## Procédure

### 1. Créer, ou faire évoluer ? La question à trancher en premier

Une même personne peut porter plusieurs affaires. Avant d'écrire, regarder ce qui existe déjà :

```
queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)
```

Le filtre sur un champ de lien se fait sur le **libellé affiché** de l'enregistrement lié, ici le nom complet du contact. Ne pas passer `fields` : le nom du contact et de l'organisation sont utiles à la restitution.

- **Rien d'ouvert, ou un sujet clairement différent** : créer une affaire (étape 3).
- **Une affaire ouverte sur le même sujet** : ne pas en créer une seconde. Faire évoluer l'étape (étape 4).
- **Doute** : montrer les affaires trouvées avec leur étape et leur montant, et demander. Un pipeline en doublon fausse tous les chiffres du bilan.

Si le contact n'existe pas encore, passer par `creer-contact` avant. **Une opportunité sans contact n'a pas d'interlocuteur** : la base l'accepte, ce skill non.

### 2. Retenir les identifiants

Le `Id` du contact, et celui de son organisation. L'organisation se lit sur la fiche du contact, elle se recopie sur l'affaire pour permettre le filtrage par entreprise.

### 3. Créer l'affaire

```
createRecords  Opportunités
{
  "Nom":              "Site vitrine + base contacts",
  "Étape":            "Identifiée",
  "Montant estimé":   3200,
  "Clôture prévue":   "2026-09-30",
  "Notes":            "<le contexte du besoin, dans les mots de l'utilisateur>",
  "Contact":       {"Id": 12},
  "Organisation":  {"Id": 7}
}
```

| Champ | Valeurs admises |
|---|---|
| `Étape` | Identifiée · Contactée · RDV · Proposition · Gagnée · Perdue |

- `Nom` : ce qui sera vendu, pas le nom du client. « Site vitrine + base contacts », pas « Affaire Le Goff ». C'est ce qui s'affiche dans le Kanban Pipeline.
- `Montant estimé` : un nombre nu, sans symbole ni espace. Le champ est en euros. **Ne jamais l'inventer** : si l'utilisateur n'a pas de chiffre en tête, laisser vide, il se complétera au devis.
- `Clôture prévue` : la date de décision espérée, pas la date de livraison. C'est elle qui fait apparaître l'affaire dans le bilan du mois.
- **Aucun tiret cadratin.**

> **`Contact` et `Organisation` se posent ici ou jamais.** Les deux liens ne s'écrivent qu'à la création, voir les conventions ci-dessus. Une affaire créée sans contact restera sans interlocuteur, et le filtre par entreprise du bilan l'ignorera.

### 4. Faire évoluer l'étape

```
updateRecords  Opportunités  id=4  {"Étape": "Proposition", "Montant estimé": 2950}
```

Un devis chiffré est l'occasion de corriger le montant estimé. Le faire dans le même appel.

**Un passage à `Proposition` réclame `Clôture prévue` si le champ est vide.** C'est le moment où une date de décision existe : on vient d'envoyer un chiffre, on sait quand on espère la réponse. La demander en une phrase, « quand espérez-vous une réponse ? », et l'écrire dans le même appel :

```
updateRecords  Opportunités  id=4  {"Étape": "Proposition", "Montant estimé": 2950,
                                    "Clôture prévue": "2026-09-15"}
```

Si l'utilisateur ne sait pas, **proposer une date et le dire**, plutôt que de laisser vide. Ce n'est pas une invention : le champ s'appelle « prévue », et une prévision se corrige. Le laisser vide, en revanche, ne se corrige jamais tout seul : les deux compétences de bilan filtrent le conclu sur ce champ, et **une affaire sans date de clôture n'est comptée nulle part, même gagnée**. Elle ne produit aucune erreur, elle produit un zéro crédible.

**Un passage à `Proposition` crée systématiquement une tâche de relance datée** : une proposition sans relance posée est une affaire perdue par oubli.

```
createRecords  Tâches
{
  "Tâche":     "Relancer sur la proposition site vitrine",
  "Échéance":  "2026-08-25",
  "Priorité":  "Haute",
  "Statut":    "À faire",
  "Contact":       {"Id": 12},
  "Opportunité":   {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Priorité` | Haute · Moyenne · Basse |
| `Statut` | À faire · En cours · Fait |

Sans délai annoncé, proposer une semaine plutôt que de laisser le champ vide : une tâche sans échéance ne remonte jamais dans « Ma journée ».

### 5. Clore une affaire

`Gagnée` ou `Perdue` : **toujours demander la raison et la consigner en `Notes`**, à la suite de ce qui s'y trouve déjà. Une ligne suffit : « Perdue, budget reporté à 2027 », « Gagnée, la recommandation de Pierre a fait la différence ».

C'est la matière du bilan annuel, et la seule qui ne se reconstitue pas après coup. Sur une affaire perdue, poser aussi la question de la relance à distance : si l'utilisateur y croit encore, renseigner `Prochaine relance` sur le contact.

### 6. Confirmer

Une phrase. « L'affaire site vitrine passe en proposition à 2 950 €, relance posée au 25 août. »

---

## Garde-fous

- **Une affaire par sujet vendu, pas une par échange.** Le pipeline doit rester lisible en un coup d'oeil.
- **Ne rien inventer** : ni montant, ni étape. Une affaire « Identifiée » sur laquelle rien n'est sûr vaut mieux qu'une affaire « Proposition » optimiste.
- **Une affaire sans `Clôture prévue` n'apparaît dans aucun bilan, même gagnée.** Le champ se pose au plus tard au passage en `Proposition`. C'est la seule date qui se propose plutôt que de rester vide, et proposer une prévision datée n'est pas l'inventer : c'est la seule à porter « prévue » dans son nom.
- **Ne pas reculer une étape en silence.** Si l'affaire régresse, le dire et demander confirmation : c'est une information commerciale, pas une correction de saisie.
- **Le récit de l'échange ne va pas ici**, il va dans `enregistrer-echange`. `Notes` porte le contexte durable de l'affaire, pas son journal.

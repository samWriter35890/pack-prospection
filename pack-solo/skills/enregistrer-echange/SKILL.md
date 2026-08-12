---
name: enregistrer-echange
description: Consigner une interaction avec un contact, appel, email reçu ou envoyé, message LinkedIn, rendez-vous, SMS. À utiliser dès que l'utilisateur raconte un échange qui vient d'avoir lieu, ou dicte un compte rendu. Crée la trace dans le journal et la tâche de suite si nécessaire.
---

# Enregistrer un échange

Transforme un récit parlé en une trace propre dans le journal : un Échange daté, rattaché à la bonne personne et, quand c'est clair, à la bonne affaire. Crée la tâche de suite s'il y en a une.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste, ne jamais traduire ni abréger.
- **Filtrer côté requête**, jamais en rapatriant la table. Syntaxe `(champ,opérateur,valeur)`, combinée par `~and` et `~or`.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.

---

## Procédure

### 1. Identifier la personne

```
queryRecords  Contacts  where=(Nom complet,like,%legoff%)
```

La recherche ne tient pas compte de la casse. Si le nom entendu est incertain, chercher aussi sur les deux champs séparés : `(Nom,like,%goff%)~or(Prénom,like,%marie%)`.

- **Aucun résultat** : la personne n'est pas dans la base. Passer la main à `creer-contact`, puis revenir ici. **Ne jamais écrire un Échange sans contact** : la base l'accepte, et l'échange devient introuvable.
- **Plusieurs résultats** : demander lequel, en citant fonction et organisation. Ne pas deviner.
- **Un résultat** : retenir son `Id`.

### 2. Rattacher à une affaire, si le contexte est clair

```
queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)  fields=["Nom","Étape","Clôture prévue"]
```

Le filtre sur un champ de lien se fait sur le **libellé affiché** de l'enregistrement lié, ici le nom complet du contact.

- Une seule affaire ouverte et le récit la désigne : rattacher.
- Plusieurs affaires, ou récit ambigu : demander laquelle en une phrase, plutôt que de laisser le lien vide.
- Le récit décrit une affaire qui n'existe pas encore : **passer par `creer-opportunite` d'abord**, puis revenir écrire l'échange avec les deux liens.

> **Cette étape se règle maintenant, elle ne se rattrape pas.** Le lien vers l'affaire ne s'écrit qu'à la création de l'échange : un échange consigné sans son affaire reste orphelin pour toujours, du moins depuis l'assistant. Deux conséquences visibles pour l'utilisateur : l'affaire affiche `Échanges = 0` et `tableau-de-bord` la classe à tort parmi les dormantes.
>
> Si l'utilisateur ne sait pas et ne veut pas trancher, écrire l'échange sans lien et **le dire** : « je le rattache à la personne seulement, l'affaire se rattachera à la main dans NoCoDB si besoin ». Ne pas laisser croire que l'assistant le corrigera plus tard.

### 3. Écrire l'échange

```
createRecords  Échanges
{
  "Objet":   "Appel de relance sur le devis",
  "Date":    "2026-08-10",
  "Canal":   "Appel",
  "Sens":    "Sortant",
  "Résumé":  "<le récit de l'utilisateur, reformulé, pas résumé à l'os>",
  "Contact":      {"Id": 12},
  "Opportunité":  {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

- `Objet` : une phrase courte et reconnaissable, c'est ce qui s'affiche dans le journal.
- `Date` : celle de l'échange, pas celle de la saisie. « Hier » se convertit.
- `Résumé` : garder ce que l'utilisateur a dit, y compris les détails humains qui serviront dans six mois. C'est la valeur du journal.
- **Aucun tiret cadratin.**

### 4. Créer la tâche de suite, s'il y en a une

Si l'échange appelle une action, elle va dans **Tâches**, jamais dans le résumé sous forme de « à faire ». Source unique.

```
createRecords  Tâches
{
  "Tâche":     "Envoyer le devis révisé",
  "Échéance":  "2026-08-12",
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

Sans échéance annoncée, en proposer une plutôt que de laisser le champ vide : une tâche sans date ne remonte jamais dans « Ma journée ».

### 5. Reporter la prochaine relance

Si une date de rappel est évoquée, la porter sur le contact :

```
updateRecords  Contacts  id=12  {"Prochaine relance": "2026-08-17"}
```

C'est ce champ qui fait remonter la personne dans la vue « À relancer » et dans l'accueil du matin. Ne pas l'oublier quand l'utilisateur dit « je le rappelle la semaine prochaine ».

### 6. Confirmer

Une phrase, pas un tableau. « C'est noté : appel du 10 août avec Marie Le Goff sur le devis, relance posée au 17, et une tâche pour envoyer le devis révisé mercredi. »

---

## Garde-fous

- **Un Échange sans Contact est un échange perdu.** La base ne l'interdit pas, ce skill si.
- **Une chose à faire va dans Tâches**, jamais dans le texte du résumé.
- **Ne rien inventer** : ni montant, ni date, ni intention que l'utilisateur n'a pas énoncés. Si un champ manque, le laisser vide ou demander.
- **Plusieurs échanges dans un même récit** (« j'ai appelé trois personnes ce matin ») : un enregistrement par personne, pas un fourre-tout. `createRecords` accepte plusieurs enregistrements en un appel.
- **Ne jamais modifier ou supprimer un échange existant** pour « corriger » : en créer un nouveau, sauf demande explicite de correction.

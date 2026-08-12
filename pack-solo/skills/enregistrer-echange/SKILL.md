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
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre**, l'organisation avant le contact, l'affaire avant l'échange qui la vise. Un lien oublié ne se corrige qu'en supprimant et recréant l'enregistrement, ce qui est sans risque pour un échange et destructeur pour un contact.
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

> **Cette étape se règle de préférence maintenant, mais elle se rattrape.** Le lien vers l'affaire ne s'écrit qu'à la création : `updateRecords` sur le champ `Opportunité` échoue toujours. Un échange consigné sans son affaire a donc deux conséquences visibles, l'affaire affiche `Échanges = 0` et `tableau-de-bord` la classe à tort parmi les dormantes.
>
> Si l'utilisateur ne sait pas et ne veut pas trancher, écrire l'échange sans lien et **le dire** : « je le rattache à la personne seulement, on rattachera l'affaire quand tu sauras ». C'est une promesse tenable, voir ci-dessous.

#### Rattacher après coup un échange à une affaire

**Un échange est une feuille : rien ne pointe vers lui.** Il se supprime donc et se recrée avec les bons liens sans rien perdre. *Vérifié pour de vrai le 12 août 2026, sur la base de référence : mise à jour du lien refusée, puis suppression et recréation avec les deux liens, et l'affaire est bien repassée à `Échanges = 1`.*

1. **Relire l'échange en entier, sans `fields`.** C'est ce qui va être recopié : tout champ oublié est perdu.
2. `deleteRecords` sur son `Id`.
3. `createRecords` en repassant **tous** les champs relus, plus les deux liens `Contact` et `Opportunité`.
4. Relire la réponse et vérifier que les deux liens sont là.

L'identifiant de l'échange change, ce qui est sans conséquence puisque rien ne le référence. Sa date de création, en revanche, devient celle de la correction : conserver la vraie `Date` de l'échange, qui est le champ qui compte pour le journal.

> **Ce raccommodage ne vaut que pour les échanges.** Un contact, lui, est un **parent** : ses échanges, ses affaires et ses tâches pointent vers lui, et le supprimer les casserait. **Un échange sans affaire est rattrapable, un contact sans organisation ne l'est pas.** D'où la différence de posture entre les deux skills : ici on propose et on accepte un « je ne sais pas encore », dans `creer-contact` on demande le nom de l'entreprise et on insiste.

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
- **Ne jamais modifier ou supprimer un échange existant** pour « corriger » un contenu : en créer un nouveau, sauf demande explicite de correction. **Une seule exception, le rattachement à une affaire**, qui n'a pas d'autre voie : la procédure de suppression et recréation est décrite à l'étape 2, et elle recopie tous les champs.

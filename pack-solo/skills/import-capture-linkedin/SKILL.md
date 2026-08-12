---
name: import-capture-linkedin
description: Mettre à jour la base à partir d'une capture d'écran LinkedIn, liste de relations, invitations acceptées, résultats de recherche. À utiliser quand l'utilisateur colle une image de LinkedIn et veut en récupérer les personnes. Lit l'image, rapproche des contacts existants, crée les manquants.
---

# Importer une capture LinkedIn

Fait entrer en base les personnes visibles sur une capture d'écran LinkedIn, sans doublon, après validation de l'utilisateur.

C'est le mode d'alimentation courant du Pack : robuste par construction, une refonte de l'interface LinkedIn ne casse rien. L'export natif LinkedIn, lui, ne sert **qu'une fois**, à la reprise du stock initial.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`.

---

## Procédure

### 1. Lire l'image

Extraire, pour chaque ligne visible : **prénom, nom, fonction, organisation**. Rien d'autre. Ce que LinkedIn appelle le « titre » mélange souvent fonction et société : les séparer.

Demander d'abord à l'utilisateur ce que montre la capture, car cela change ce qu'on écrira :

| Capture | Ce qu'on en fait |
|---|---|
| Invitations acceptées | Créer les contacts et **tracer un Échange « Invitation acceptée »** |
| Liste de relations | Créer les contacts, sans échange |
| Résultats de recherche | Créer les contacts en `Source: LinkedIn`, sans échange : ce ne sont pas encore des relations |

**Ne rien deviner sur une ligne coupée en bord d'image.** La signaler et l'écarter, plutôt que de compléter un nom au jugé.

### 2. Rapprocher de l'existant

Pour chaque personne, chercher le doublon avant toute écriture :

```
queryRecords  Contacts       where=(Nom complet,like,%le goff%)
queryRecords  Organisations  where=(Nom,like,%odyssee%)
```

La recherche ne tient pas compte de la casse. Quand la lecture du nom est incertaine, élargir sur le seul nom de famille. Rapprocher sur **nom plus organisation**, jamais sur le nom seul.

Sur une capture d'une dizaine de lignes, regrouper les recherches plutôt que d'enchaîner vingt appels : un `like` par nom de famille suffit.

### 3. Afficher le tableau de contrôle. Étape obligatoire

Avant toute écriture, montrer ce qui va se passer, en trois blocs :

| | Personne | Organisation | Décision |
|---|---|---|---|
| À créer | Marie Le Goff, Gérante | Odyssée 29 | Nouveau contact |
| À compléter | Pierre Autret | Super Super | Fonction manquante, sera ajoutée |
| Doublon probable | M. Legoff | Odyssee 29 | Même personne que Marie Le Goff ? |

**N'écrire qu'après validation explicite.** La lecture d'image se trompe sur les noms rares, les particules et les accents, et une base polluée ne se nettoie jamais. Cette étape n'est pas une politesse, c'est le garde-fou du skill.

### 4. Écrire

Les organisations d'abord, puisque les contacts pointent dessus.

```
createRecords  Organisations
{ "Nom": "Odyssée 29", "Source": "LinkedIn" }
```

Puis les personnes, plusieurs en un seul appel :

```
createRecords  Contacts
[
  {
    "Prénom": "Marie", "Nom": "Le Goff", "Fonction": "Gérante",
    "Statut relation": "Nouveau", "Source": "LinkedIn",
    "Organisation": {"Id": 7}
  },
  { ... }
]
```

| Champ | Valeurs admises |
|---|---|
| `Statut relation` | Nouveau · À contacter · En discussion · Client · Dormant · Perdu |
| `Source` (Contacts) | LinkedIn · Email · Salon · Réseau · Recommandation · Import Datablist |
| `Source` (Organisations) | Réseau · Salon · Recommandation · LinkedIn · Web · Import Datablist |

- **`Nom complet` ne s'écrit pas** : c'est une formule.
- **Pas d'email, pas de téléphone** : une capture LinkedIn n'en montre pas, et un email déduit d'un modèle `prenom.nom@` est un email faux.
- Sur une fiche existante, compléter avec `updateRecords`, **sans jamais écraser une valeur renseignée** par une valeur lue sur l'image. L'organisation fait exception : elle ne se rattache pas après coup, voir les conventions ci-dessus.
- **Les organisations d'abord, les personnes ensuite**, dans cet ordre : le lien vers l'organisation ne s'écrit qu'à la création de la fiche. Sur un lot, cela veut dire un premier appel `createRecords` sur Organisations, puis un second sur Contacts avec les `Id` obtenus.

### 5. Tracer les invitations acceptées

Uniquement pour une capture d'invitations acceptées, un échange par personne :

```
createRecords  Échanges
{
  "Objet":   "Invitation acceptée",
  "Date":    "2026-08-11",
  "Canal":   "LinkedIn",
  "Sens":    "Entrant",
  "Contact": {"Id": 12}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

C'est ce qui permettra plus tard de mesurer le rendement réel de la prospection LinkedIn.

### 6. Enchaîner les captures

Une capture montre une dizaine de lignes : accepter plusieurs images à la suite dans la même session, et **dédoublonner aussi entre les captures**, pas seulement contre la base. Deux images d'une même liste se recouvrent presque toujours d'une ou deux lignes.

### 7. Conclure

Un compte rendu court : combien créés, combien complétés, combien écartés et pourquoi. Puis proposer la suite utile : `accroche-linkedin` pour écrire aux nouvelles relations.

---

## Garde-fous

- **Aucune écriture avant validation du tableau de contrôle.**
- **Cadre RGPD.** N'entrent en base que nom, fonction, organisation et coordonnées professionnelles. Ce qui a été lu sur un profil pour personnaliser un message reste transitoire, jamais stocké.
- **Ne rien compléter au jugé** : un nom coupé, une société illisible, une ligne floue sont écartés et signalés.
- **Ne jamais écraser une donnée saisie** par une donnée lue sur une image. La base fait foi, l'image est une source.
- **Une invitation envoyée n'est pas une invitation acceptée.** Ne tracer un échange que sur une capture qui montre effectivement une acceptation.

---
name: creer-contact
description: Créer une nouvelle personne dans la base, ou compléter une fiche existante, nom, fonction, entreprise, email, téléphone, LinkedIn. À utiliser quand l'utilisateur mentionne quelqu'un d'absent de la base, transmet une carte de visite, une signature d'email ou un profil.
---

# Créer un contact

Fait entrer une personne dans la base, sans doublon, rattachée à son organisation.

Appelé directement, ou depuis `enregistrer-echange` quand la personne racontée est inconnue. Dans ce cas, créer la fiche puis **rendre la main** au skill appelant.

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

### 1. Chercher le doublon. Toujours, avant d'écrire

```
queryRecords  Contacts  where=(Nom complet,like,%le goff%)
```

Si le nom est mal orthographié ou entendu de travers, élargir sur le seul nom de famille, puis sur l'organisation :

```
queryRecords  Contacts       where=(Nom,like,%goff%)
queryRecords  Organisations  where=(Nom,like,%odyssee%)
```

- **La personne existe** : ne pas créer. Compléter la fiche avec `updateRecords`, en n'écrasant jamais une valeur renseignée par une valeur devinée. Une exception : si la fiche n'a **pas d'organisation**, l'assistant ne sait pas la rattacher après coup, voir les conventions ci-dessus. Le dire simplement, et indiquer que le rattachement se fait à la main dans NoCoDB.
- **Homonyme probable** : montrer les deux fiches, fonction et organisation comprises, et demander.

### 2. Rattacher ou créer l'organisation

Le nom de la société **ne se recopie jamais** dans la fiche du contact. Il vit dans Organisations, et le contact pointe dessus.

```
queryRecords  Organisations  where=(Nom,like,%super super%)  fields=["Nom","Ville","Taille"]
```

Si elle n'existe pas :

```
createRecords  Organisations
{ "Nom": "Super Super", "Ville": "Rennes", "Taille": "TPE", "Source": "Réseau" }
```

| Champ | Valeurs admises |
|---|---|
| `Taille` | Solo · TPE · PME · Grand compte |
| `Source` | Réseau · Salon · Recommandation · LinkedIn · Web · Import Datablist |

`Secteur` est une liste **adaptée à chaque client** : lire les valeurs disponibles avec `getTableSchema` avant d'écrire, ne pas en inventer une.

Une personne indépendante sans structure : créer quand même l'organisation à son nom si elle facture, sinon laisser le lien vide.

> **L'ordre compte, et il ne se rattrape pas.** L'organisation se crée **avant** le contact, parce que le lien ne s'écrit qu'à la création de la fiche. Au moindre doute, créer l'organisation : une fiche rattachée à tort se corrige dans NoCoDB en deux clics, une fiche jamais rattachée demande de la retrouver plus tard.

### 3. Créer la personne

```
createRecords  Contacts
{
  "Prénom":          "Marie",
  "Nom":             "Le Goff",
  "Fonction":        "Gérante",
  "Email":           "m.legoff@example.fr",
  "Téléphone":       "06 12 34 56 78",
  "LinkedIn":        "https://www.linkedin.com/in/...",
  "Statut relation": "Nouveau",
  "Source":          "Réseau",
  "Organisation":    {"Id": 7}
}
```

| Champ | Valeurs admises |
|---|---|
| `Statut relation` | Nouveau · À contacter · En discussion · Client · Dormant · Perdu |
| `Source` | LinkedIn · Email · Salon · Réseau · Recommandation · Import Datablist |

`Étiquettes` est une liste multiple **adaptée à chaque client** : lire les valeurs avec `getTableSchema` avant d'écrire.

- **`Nom complet` ne s'écrit pas.** C'est une formule, calculée à partir du prénom et du nom. C'est aussi le libellé qui s'affichera partout où le contact est lié.
- **Renseigner `Source`.** C'est ce qui permettra plus tard de mesurer ce qui fonctionne. « Je ne sais plus » est une réponse acceptable, une valeur inventée ne l'est pas.
- `Prochaine relance` : la poser si une échéance est évoquée. C'est ce champ qui fera remonter la personne dans « À relancer ».
- `Notes` : le contexte durable sur la personne. Le récit d'un échange, lui, va dans `enregistrer-echange`.

### 4. Confirmer, et rendre la main

Une phrase. Si le skill a été appelé depuis `enregistrer-echange`, revenir à l'échange à consigner sans faire répéter l'utilisateur.

---

## Garde-fous

- **Chercher le doublon avant chaque création.** Une base à doublons devient inutilisable en trois mois, et personne ne la nettoie ensuite.
- **Cadre RGPD.** N'entrent en base que les coordonnées professionnelles que l'utilisateur gère légitimement : nom, fonction, organisation, coordonnées de travail. Tout élément de profil servant à personnaliser un message reste **transitoire, jamais stocké**.
- **Ne rien inventer** : pas d'email déduit d'un modèle `prenom.nom@`, pas de fonction supposée, pas de ville devinée. Un champ vide se complète plus tard, un champ faux se propage.
- **Plusieurs personnes d'un coup** : `createRecords` accepte plusieurs enregistrements en un appel, mais le dédoublonnage se fait pour chacune, et aussi entre elles.

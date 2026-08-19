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
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

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

### 4. Confirmer, et demander les coordonnées dans la même réponse

Une phrase pour dire ce qui a été créé. Si le skill a été appelé depuis `enregistrer-echange`, revenir à l'échange à consigner sans faire répéter l'utilisateur.

**La confirmation porte la question.** Si `Email`, `Téléphone` ou `LinkedIn` sont vides, la demande part **avec** la phrase de confirmation, au même endroit que les points tranchés sans certitude, sous la même forme. Ce n'est pas une étape de plus, c'est une puce de plus :

> C'est fait : la fiche de Charlotte Le Bedel est créée, rattachée à Perfhomme Rennes, avec l'échange du rendez-vous d'hier.
> Deux points où j'ai tranché sans certitude : le canal de l'échange est en RDV, dis-moi si c'était plutôt un appel ; le statut de la relation est en En discussion.
> Et il manque ses coordonnées : email, téléphone, profil LinkedIn ? Donne-moi ce que tu as, je complète la fiche.

Une question posée dans la même réponse repart avec le reste et obtient une réponse. Une question repoussée à plus tard n'est jamais posée : la fiche reste vide, et personne ne s'en aperçoit avant le jour où il faut relancer.

**Ne rien inventer ne veut pas dire ne rien demander.** Un email absent d'une capture d'écran n'est pas un email inconnu : l'utilisateur l'a souvent sous la main, il ne pense pas à le donner parce qu'on ne le lui a pas demandé. Le lien LinkedIn en est le cas le plus net, puisqu'il est dans la barre d'adresse de la page dont il vient de faire la capture. Demander coûte une question, un champ vide coûte une relance qui n'aura pas lieu.

**Créer d'abord, demander ensuite. « Ensuite » veut dire dans la même réponse**, pas un jour plus tard. La règle interdit de retenir la création derrière un formulaire : une fiche partielle vaut mieux qu'un formulaire abandonné, et sur un lot de profils, une question par personne est intenable. Elle n'a jamais dispensé de la question, et c'est ainsi qu'elle a été lue jusqu'ici. Sur un lot, une seule question à la fin, pour tous ceux qui manquent.

> **Ne jamais renvoyer l'utilisateur vers NoCoDB pour compléter une coordonnée.** Le pack se vend sur « vous n'ouvrez pas la base ». Lui dire d'aller saisir un email à la main lui rend précisément le travail qu'il nous paie pour éviter, et la fiche restera vide. Le complément se fait ici, par `updateRecords`, sur ce qu'il dicte. NoCoDB n'est le recours que pour ce que l'assistant **ne peut techniquement pas faire**, c'est-à-dire rattacher un lien après coup.

---

## Garde-fous

- **Chercher le doublon avant chaque création.** Une base à doublons devient inutilisable en trois mois, et personne ne la nettoie ensuite.
- **Cadre RGPD.** N'entrent en base que les coordonnées professionnelles que l'utilisateur gère légitimement : nom, fonction, organisation, coordonnées de travail. Tout élément de profil servant à personnaliser un message reste **transitoire, jamais stocké**.
- **Ne rien inventer** : pas d'email déduit d'un modèle `prenom.nom@`, pas de fonction supposée, pas de ville devinée. Un champ vide se complète plus tard, un champ faux se propage.
- **Plusieurs personnes d'un coup** : `createRecords` accepte plusieurs enregistrements en un appel, mais le dédoublonnage se fait pour chacune, et aussi entre elles.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « vous ne m'avez pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un.
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.
- **Un champ vide se demande, il ne s'abandonne pas.** Créer sans email est normal, conclure sans avoir demandé l'email ne l'est pas. Et la demande vit dans la phrase de confirmation, jamais dans un « on verra plus tard ».

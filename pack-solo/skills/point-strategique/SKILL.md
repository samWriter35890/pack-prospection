---
name: point-strategique
description: Comparer l'avancement réel aux objectifs que l'utilisateur s'est fixés dans sa base. À utiliser quand il parle de ses objectifs, de sa cible, de ce qu'il s'était fixé, demande s'il est dans les clous, s'il est en retard, ou s'il va y arriver. Compare ce qui est visé à ce qui est mesuré, et ne remplit jamais un objectif absent.
---

# Point stratégique

Répond à **« où j'en suis de ce que je m'étais fixé »**. Lit les objectifs posés par l'utilisateur dans la table `Objectifs`, mesure le réel dans la base, et donne l'écart entre les deux.

**C'est la seule compétence qui a besoin de deux nombres pour dire quelque chose** : une cible et une mesure. Sans cible, elle n'a rien à dire, et le dire est sa bonne réponse.

## Ce qui n'est pas ici

| La demande | Le skill |
|---|---|
| « Par quoi je commence aujourd'hui ? » | `accueil` |
| « Où en sont mes affaires ? », « combien de rendez-vous ce mois-ci ? » | `tableau-de-bord` |
| « Est-ce que je suis dans les clous ? », « j'en suis où de mes 4 RDV par mois ? » | **ici** |

**Le test qui tranche, en cas de doute : la demande garde-t-elle un sens sur une base qui ne porte aucun objectif ?** Si oui, elle est pour `tableau-de-bord`. Si elle perd tout sens, elle est ici.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Échéance", "description": "asc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Échéance asc"` est refusée.
- **Filtrer et compter côté requête**, jamais en rapatriant la table pour compter soi-même.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.

> ### Une fenêtre de dates ne s'écrit pas avec `btw`, malgré la documentation de l'outil
>
> **`(Date,btw,2026-08-01,2026-08-31)` échoue**, sur un champ `Date` comme sur un champ `CreatedTime`, avec `Error: '2026-08-01' is not supported.` La forme est pourtant celle que l'aide du connecteur donne en exemple. Vérifié le 17 août 2026 sur les deux types de champ.
>
> **La forme qui marche encadre la période avec deux comparaisons `exactDate` :**
>
> ```
> (Date,gte,exactDate,2026-08-01)~and(Date,lte,exactDate,2026-08-31)
> ```
>
> **La borne haute inclut la journée entière**, y compris sur un champ horodaté : un enregistrement créé le 13 août à 12h44 est bien compté par `(Créé le,lte,exactDate,2026-08-13)`. Vérifié aux deux bornes. C'est ce qui rend un mois calendaire mesurable sans perdre son dernier jour.
>
> **C'est un échec bruyant, donc sans danger**, à la différence du silence de `aggregate` sur un titre de colonne. Il n'empêche pas de se tromper, il empêche de se tromper sans le savoir.

---

## Ce qu'on lit, dans l'ordre

### 1. Les objectifs, toujours en premier

```
queryRecords  Objectifs  where=(Statut,eq,En cours)
              sort=[{"field": "Échéance", "description": "asc"}]
              fields=["Objectif","Indicateur","Cible","Période","Début","Échéance","Statut","Notes"]
```

**Si la réponse est vide, s'arrêter là.** Ne pas aller mesurer quoi que ce soit, ne pas se rabattre sur un bilan d'activité. Voir « Le cas de la table vide » plus bas, qui est le cas le plus important de cette compétence.

Quand l'utilisateur vise un objectif précis (« mes rendez-vous »), ne traiter que celui-là. Quand il demande un point général, les traiter tous, dans l'ordre d'échéance.

### 2. La fenêtre de mesure de chaque objectif

`Période` donne la forme de la fenêtre, `Début` et `Échéance` la bornent.

| `Période` | Fenêtre mesurée |
|---|---|
| Mensuel | le mois calendaire en cours |
| Trimestriel | le trimestre calendaire en cours |
| Annuel | l'année calendaire en cours |
| Ponctuel | de `Début` à `Échéance`, en entier |

**La fenêtre se rabote toujours sur `Début` et `Échéance`.** Trois cas à traiter explicitement, et à dire à l'utilisateur plutôt qu'à masquer :

- **Aujourd'hui est avant `Début`** : l'objectif n'a pas commencé. Le dire, ne rien mesurer. Un zéro sur un objectif qui démarre le mois prochain n'est pas un retard, c'est une lecture fausse.
- **Aujourd'hui est après `Échéance`** : la période est close. Mesurer sur la fenêtre complète et présenter un résultat définitif, pas un avancement.
- **La fenêtre est en cours** : c'est le cas courant. Annoncer aussi **où l'on en est dans la fenêtre**, parce que c'est ce qui donne son sens au chiffre. 2 rendez-vous sur 4 le 17 du mois, c'est dans les clous ; le 30, non.

### 3. La mesure, et elle est imposée

**Chaque valeur d'`Indicateur` a un comptage et un seul.** Ce tableau est un contrat, pas une suggestion. Ne jamais mesurer un indicateur autrement, ne jamais en mesurer un qui n'y figure pas.

| `Indicateur` | Appel |
|---|---|
| Chiffre signé | `aggregate` Opportunités, `sum` sur `Montant estimé`, où `(Étape,eq,Gagnée)` et `Clôture prévue` dans la fenêtre |
| Affaires ouvertes | `countRecords` Opportunités, où `Créé le` dans la fenêtre |
| Propositions en cours | `countRecords` Opportunités, où `(Étape,eq,Proposition)`. **Sans fenêtre**, voir ci-dessous |
| Rendez-vous | `countRecords` Échanges, où `(Canal,eq,RDV)` et `Date` dans la fenêtre |
| Échanges sortants | `countRecords` Échanges, où `(Sens,eq,Sortant)` et `Date` dans la fenêtre |
| Nouveaux contacts | `countRecords` Contacts, où `Créé le` dans la fenêtre |
| Autre (non mesuré) | **aucun appel.** Voir « L'objectif qualitatif » |

Exemple complet, pour un objectif de rendez-vous mensuel mesuré sur août 2026 :

```
countRecords  Échanges
  where=(Canal,eq,RDV)~and(Date,gte,exactDate,2026-08-01)~and(Date,lte,exactDate,2026-08-31)
```

Et pour le chiffre signé, seul indicateur qui soit une somme :

```
getTableSchema  Opportunités        → retenir l'id de « Montant estimé » et celui de « Nom »
aggregate  Opportunités
  aggregations = [ { field: "<id de Montant estimé>", type: "sum" },
                   { field: "<id de Nom>",            type: "count_filled" } ]
  filterGroups = [ { alias: "gagnees",
                     where: "(Étape,eq,Gagnée)~and(Clôture prévue,gte,exactDate,2026-08-01)~and(Clôture prévue,lte,exactDate,2026-08-31)" } ]
```

> **`aggregate` ne comprend que les identifiants de colonne, jamais les titres.** Un titre renvoie `{}`, **sans message d'erreur** : c'est la seule réponse silencieuse de ce connecteur. Lire `getTableSchema` une fois par session sur Opportunités, et ne s'en servir que pour l'indicateur « Chiffre signé ». Les six autres passent par `countRecords`, qui n'a besoin d'aucun identifiant de colonne.

> **« Propositions en cours » est un stock, pas un flux, et cela se dit à l'utilisateur.** La base ne garde **aucun historique d'étape** : une affaire passée de Proposition à Gagnée n'a laissé aucune trace de son passage. On sait donc combien d'affaires sont en proposition **aujourd'hui**, jamais combien en ont été émises dans le mois. Formuler au présent, toujours : « vous avez 3 propositions en cours », jamais « vous avez fait 3 propositions ce mois-ci ». La seconde phrase serait une invention, et elle passerait inaperçue.

---

## Le cas de la table vide, qui est le cas important

**Le risque de cette compétence n'est pas de ne pas se déclencher. C'est de se déclencher et de devenir `tableau-de-bord`.**

Appelée sans aucun objectif en base, elle sera tentée de rendre service en récitant l'activité du mois. Elle produirait alors un bilan que personne n'a demandé, sous un nom qui laisse croire qu'il est mesuré contre quelque chose. C'est la faute la plus grave possible ici, parce qu'elle ne se voit pas : les chiffres sont justes, c'est leur sens qui est faux.

La réponse juste tient en trois temps :

1. **Le dire.** « Vous ne m'avez pas donné de cible, je ne peux donc pas vous dire si vous êtes dans les clous. »
2. **Proposer d'en poser une**, en une question simple, et laisser l'utilisateur formuler la sienne.
3. **Proposer l'autre porte** : « si vous voulez seulement voir votre activité du mois, je peux vous faire le point », et passer la main à `tableau-de-bord`.

**Jamais combler.** Un objectif absent se dit, il ne se déduit pas de l'activité passée, il ne se remplace pas par une valeur ronde plausible.

Même règle sur un objectif présent mais incomplet : une `Cible` vide sur un indicateur mesurable est une saisie inachevée, à signaler et à faire compléter, jamais à estimer.

## L'objectif qualitatif

`Autre (non mesuré)` porte un objectif qui n'a volontairement pas de chiffre : « être identifié comme la référence sur mon secteur ». Sa `Cible` est vide, et c'est normal.

**Le restituer en toutes lettres, et ne jamais le chiffrer.** Ne pas lui inventer un pourcentage d'avancement, ne pas lui trouver un indicateur de remplacement, ne pas dire qu'il est « en bonne voie » sur la foi de l'activité. Le rappeler à l'utilisateur suffit : c'est un objectif qu'il a posé pour s'en souvenir, pas pour qu'on le mesure.

Ce qui est permis, et utile : citer un fait de la base qui s'y rapporte, sans en tirer de score. « Sur votre objectif de notoriété, rien de mesurable par nature. Je note quand même deux recommandations reçues ce mois-ci. »

---

## Restituer

Un objectif par bloc, court. Pour chacun :

1. **L'objectif dans ses mots à lui**, repris du champ `Objectif`, pas reformulé.
2. **Les deux nombres**, cible et mesure, et l'écart. « 2 rendez-vous sur les 4 visés. »
3. **Où l'on en est dans la période.** « À mi-parcours du mois. » C'est ce qui fait la différence entre un constat et un jugement.
4. **Le verdict, prudent et explicite.** Dans les clous, en retard, atteint, hors d'atteinte. Un seul mot, pas un paragraphe.

Puis, une fois pour l'ensemble : **une recommandation actionnable, une seule**, et le skill qui la porte. « Le plus rentable : relancer les deux propositions en attente. Je peux préparer les mails. »

Nommer les affaires et les personnes quand elles expliquent un écart. Un solo reconnaît des noms, pas des totaux.

**Ne pas dérouler les sept indicateurs** quand l'utilisateur n'a posé que deux objectifs. On mesure ce qui est visé, rien d'autre.

---

## Poser ou clore un objectif

Cette compétence lit et compare. Elle **écrit deux choses, et seulement sur demande explicite de l'utilisateur**, parce que sans cela la table ne serait tenable qu'en ouvrant NoCoDB, ce que le pack promet d'éviter.

**Créer un objectif**, quand l'utilisateur en formule un :

```
createRecords  Objectifs
{
  "Objectif":    "4 rendez-vous de découverte par mois",
  "Indicateur":  "Rendez-vous",
  "Cible":       4,
  "Période":     "Mensuel",
  "Début":       "2026-09-01",
  "Échéance":    "2026-12-31",
  "Statut":      "En cours"
}
```

| Champ | Valeurs admises |
|---|---|
| `Indicateur` | Chiffre signé · Affaires ouvertes · Propositions en cours · Rendez-vous · Échanges sortants · Nouveaux contacts · Autre (non mesuré) |
| `Période` | Mensuel · Trimestriel · Annuel · Ponctuel |
| `Statut` | En cours · Atteint · Manqué · Abandonné |

- `Objectif` se recopie **dans les mots de l'utilisateur**, sans être réécrit en langage de tableau de bord.
- **`Indicateur` ne se devine pas.** Si la formulation ne tombe pas clairement dans la liste, montrer les options et demander. Un mauvais indicateur produit un chiffre juste sur la mauvaise chose, ce qui est pire qu'un refus.
- **Si rien dans la liste ne convient, prendre `Autre (non mesuré)` et le dire.** C'est fait pour, et c'est toujours mieux que de forcer un objectif dans un indicateur voisin.
- **`Cible` ne s'invente jamais.** Sans chiffre annoncé par l'utilisateur, poser la question ou laisser vide.

**Changer le `Statut`**, quand une échéance est passée et que l'utilisateur tranche :

```
updateRecords  Objectifs  id=1  {"Statut": "Atteint",
                                 "Notes": "<ce qui s'y trouvait déjà, plus la raison>"}
```

**Proposer le statut, ne jamais le poser soi-même.** Même quand la mesure est sans ambiguïté, « atteint » et « manqué » sont des jugements de l'utilisateur sur son année, pas des conclusions de calcul. Annoncer le chiffre, proposer le statut qui semble correspondre, et attendre le mot de l'utilisateur.

---

## Garde-fous

- **Comparer, jamais inventer.** C'est la règle de fond, et toutes les autres en découlent. Les objectifs viennent du client, le réel vient de la base, et rien ne vient d'ailleurs.
- **Un objectif absent se dit.** Il ne se déduit pas, il ne s'estime pas, il ne se remplit pas d'une valeur plausible.
- **Ne jamais se rabattre sur un bilan d'activité** faute d'objectif. C'est le travail de `tableau-de-bord`, et lui donner le nom d'un point stratégique trompe l'utilisateur sur ce qu'il lit.
- **Ne jamais chiffrer un objectif `Autre (non mesuré)`**, ni par un pourcentage, ni par un indicateur de substitution.
- **Ne jamais présenter un chiffre calculé de tête.** Tout nombre annoncé sort d'un appel. En cas de doute, recouper par un `countRecords` plutôt qu'arrondir.
- **Un seul comptage par indicateur**, celui du tableau. Deux mesures différentes du même objectif d'un mois sur l'autre valent moins que pas de mesure du tout.
- **`Propositions en cours` se dit au présent.** C'est un stock : la base ne porte pas d'historique d'étape.
- **Ne pas modifier `Objectif` ni `Cible`** sans que l'utilisateur les redonne lui-même. Corriger une cible pour qu'elle colle au réel vide la compétence de tout son sens.
- **Aucun tiret cadratin**, dans le texte produit comme dans les phrases dites autour. Le remplacer par une virgule ou deux points. C'est une signature d'écriture automatique, et l'utilisateur la lit.

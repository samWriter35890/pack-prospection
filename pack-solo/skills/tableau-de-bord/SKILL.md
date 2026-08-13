---
name: tableau-de-bord
description: Faire le point commercial, pipeline, chiffre en cours, relances en retard, activité de la période, affaires dormantes. À utiliser quand l'utilisateur demande où il en est, veut un bilan de semaine ou de mois, ou s'interroge sur un chiffre. Commente les chiffres, n'affiche pas que des compteurs.
---

# Tableau de bord

Fait le point **périodique** : bilan de semaine ou de mois, état du pipeline, affaires gagnées et perdues, affaires dormantes.

Le quotidien n'est pas ici : les relances du jour, les réponses reçues et les échanges récents relèvent de `accueil`. Ce skill répond à « où j'en suis », pas à « par quoi je commence ».

**Il n'écrit rien.** Il lit, il calcule, il interprète.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Date", "description": "desc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Date desc"` est refusée.
- **Filtrer et compter côté requête**, jamais en rapatriant la table pour compter soi-même. C'est la règle qui rend ce skill tenable sans dashboard natif.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Un champ de **compteur de liens**, lui, survit à `fields`.

---

## L'outil `aggregate`, et ses deux pièges

`aggregate` calcule sommes et comptages côté serveur, sur **plusieurs filtres en un seul appel**. C'est lui qui rend un bilan complet possible en deux ou trois allers-retours. Il a deux comportements à connaître, tous deux vérifiés sur la base de référence.

> **1. `aggregate` ne comprend que les identifiants de colonne, jamais les titres.** Un titre de champ renvoie `{}`, **sans message d'erreur**. C'est la seule réponse silencieuse observée sur ce MCP : partout ailleurs un nom approché échoue bruyamment. Lire donc `getTableSchema` sur les tables concernées, une fois par session, et retenir les `id` des colonnes utiles.

> **2. Le résultat est indexé par le titre du champ.** Deux agrégations sur le **même** champ dans un même appel s'écrasent donc, et la dernière gagne, silencieusement. Une agrégation par champ et par appel. Plusieurs champs différents dans un appel, en revanche, fonctionnent, et plusieurs `filterGroups` aussi.

Forme réelle d'un appel, avec les identifiants lus dans le schéma :

```
aggregate  Opportunités
  aggregations = [
    { field: "<id de Montant estimé>",  type: "sum" },
    { field: "<id de Nom>",             type: "count_filled" }
  ]
  filterGroups = [
    { alias: "en_cours",    where: "(Étape,in,Identifiée,Contactée,RDV,Proposition)" },
    { alias: "proposition", where: "(Étape,eq,Proposition)" },
    { alias: "gagnees",     where: "(Étape,eq,Gagnée)~and(Clôture prévue,isWithin,pastNumberOfDays,30)" },
    { alias: "perdues",     where: "(Étape,eq,Perdue)~and(Clôture prévue,isWithin,pastNumberOfDays,30)" },
    { alias: "tout" }
  ]
```

Réponse : un objet par alias, chaque valeur indexée par titre de champ.

```
{ "en_cours": { "Montant estimé": 5000, "Nom": 3 }, "gagnees": { ... } }
```

Un `filterGroups` sans `where` porte sur toute la table. `count_filled` sur le champ titre est le comptage d'enregistrements le plus fiable. Pour les périodes, `countRecords` reste plus simple quand un seul chiffre suffit.

---

## Ce qu'on va chercher

Cinq blocs, dans cet ordre. Ne pas tout sortir à chaque fois : suivre la question posée.

### 1. Le pipeline

Un `aggregate` sur Opportunités, comme ci-dessus : montant et nombre d'affaires en cours, dont celles en proposition. C'est le chiffre que l'utilisateur attend en premier.

### 2. Ce qui s'est conclu sur la période

Gagnées et perdues, filtrées sur `Clôture prévue`. Toujours **les deux**, jamais les gagnées seules : un taux de transformation se lit sur les deux nombres.

### 3. L'activité

```
countRecords  Échanges  where=(Date,isWithin,pastNumberOfDays,7)
countRecords  Échanges  where=(Date,isWithin,pastNumberOfDays,7)~and(Sens,eq,Entrant)
```

Le rapport entrant sur sortant dit si la prospection prend. Adapter la fenêtre à la question : 7 jours pour une semaine, 30 pour un mois.

### 4. Ce qui traîne

```
countRecords  Tâches    where=(Statut,neq,Fait)~and(Échéance,lt,today)
countRecords  Contacts  where=(Prochaine relance,lt,today)
```

Deux nombres, pas de liste : `accueil` s'occupe du détail du jour.

### 5. Les affaires dormantes

Deux cas, dans cet ordre.

**Jamais d'échange.** Le champ `Échanges` d'une opportunité est un compteur de liens, filtrable directement, et il survit à `fields` :

```
queryRecords  Opportunités  where=(Étape,in,Identifiée,Contactée,RDV,Proposition)~and(Échanges,eq,0)
                            fields=["Nom","Étape","Échanges"]
```

**Plus d'échange depuis longtemps.** NoCoDB ne sait pas filtrer sur « date du dernier échange lié ». La reconstruire en deux appels :

```
queryRecords  Opportunités  where=(Étape,in,Identifiée,Contactée,RDV,Proposition)
queryRecords  Échanges      where=(Date,isWithin,pastNumberOfDays,30)~and(Opportunité,notblank)
                            sort=[{"field": "Date", "description": "desc"}]  pageSize=100
```

Les affaires en cours qui n'apparaissent dans aucun de ces échanges sont les dormantes. Ne pas passer `fields` sur le second appel : c'est le libellé de l'opportunité liée qui permet le rapprochement, et il disparaît dès qu'on filtre les champs.

---

## Restituer

**Un tableau seul est un échec.** La valeur de ce skill est l'interprétation, c'est le différenciant de l'offre.

Structure :

1. **Deux ou trois phrases de constat**, en langage de dirigeant. « Tu as 12 400 € en cours sur cinq affaires, dont deux propositions envoyées il y a plus de trois semaines. »
2. **Un petit tableau**, si et seulement s'il éclaire. Cinq lignes maximum.
3. **Ce qui a bougé**, par rapport à la période précédente quand l'information existe. Un chiffre sans variation ne dit rien.
4. **Ce qui coince**, nommément. « Les affaires Kervella et Autret n'ont plus bougé depuis un mois. »
5. **Une recommandation actionnable**, une seule, et le skill qui la porte. « Le plus rentable aujourd'hui : relancer les deux propositions. Je peux préparer les mails. »

Nommer les personnes et les affaires. Un solo reconnaît des noms, pas des totaux.

Sur une base presque vide, le dire en une phrase et s'arrêter. Un bilan sur trois enregistrements n'a pas de sens, et gonfler la restitution ferait perdre confiance.

---

## Garde-fous

- **Aucune écriture.** Même une tâche qui semblerait évidente : la proposer, laisser le skill concerné la créer.
- **Compter côté requête.** Jamais de rapatriement de table pour compter soi-même : c'est lent, coûteux, et faux dès que la base grossit.
- **Ne pas recopier les vues NoCoDB.** « À relancer », « Ma journée », « Pipeline » et « Journal » restent consultables sur mobile sans IA. Ce skill apporte l'analyse, pas la liste.
- **Ni graphique, ni prévisionnel pondéré, ni probabilité.** Ils relèvent de l'option payante « Dashboard avancé », et le socle ne porte pas de champ probabilité.
- **Ne jamais présenter un chiffre calculé de tête.** Tout nombre annoncé sort d'un appel. En cas de doute sur un résultat, le recouper par un `countRecords` plutôt que l'arrondir.
- **Aucun tiret cadratin**, dans le texte produit comme dans les phrases dites autour. Le remplacer par une virgule ou deux points. C'est une signature d'écriture automatique, et l'utilisateur la lit.

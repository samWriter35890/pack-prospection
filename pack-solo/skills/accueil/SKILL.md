---
name: accueil
description: Point de départ d'une session de travail commercial. À utiliser quand l'utilisateur ouvre une session sans demande précise, dit bonjour, demande par quoi commencer, ce qu'il a à faire aujourd'hui, ou où il en est. Lit l'état de la base et propose les routines du jour.
---

# Accueil

Ouvre la journée de travail commercial. Ce skill **lit** la base, restitue l'essentiel en trois lignes, puis propose deux à quatre routines.

**Il n'écrit jamais rien. Il ne contient aucune procédure métier.** Dès que l'utilisateur choisit une routine ou arrive avec une demande précise, passer la main au skill nommé et s'effacer.

---

## Lire l'état, en trois appels

Résoudre d'abord les identifiants de table avec `getTablesList`, une seule fois par session. Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.

| Ce qu'on cherche | Table | `where` | `sort` |
|---|---|---|---|
| Ce qui est à faire aujourd'hui ou en retard | Tâches | `(Statut,neq,Fait)~and(Échéance,lte,today)` | `Rang priorité` asc, puis `Échéance` asc |
| Les personnes à relancer | Contacts | `(Prochaine relance,lte,today)` | `Prochaine relance` asc |
| Les réponses reçues récemment | Échanges | `(Sens,eq,Entrant)~and(Date,isWithin,pastNumberOfDays,7)` | `Date` desc |

`pageSize` 25 sur les deux premiers, 10 sur le troisième. **Trois appels, pas quatre.** Si les trois listes sont vides, le dire en une phrase et proposer de prospecter, ne pas aller chercher ailleurs.

Sur Contacts, demander `fields` : `["Nom complet", "Prochaine relance", "Statut relation"]`. Sur Tâches et Échanges, **ne pas passer `fields`** : le nom du contact lié est nécessaire à la restitution, et il disparaît dès qu'on filtre les champs (voir la note ci-dessous).

> **Un tri s'écrit `sort=[{"field": "Rang priorité", "description": "asc"}, {"field": "Échéance", "description": "asc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Date desc"` est refusée.

> **Le tri des tâches passe par `Rang priorité`, jamais par `Priorité`.** NoCoDB trie un select par ordre alphabétique de la valeur : un tri sur `Priorité` donnerait Basse avant Haute. `Rang priorité` est le champ technique qui porte le bon ordre.

> **`fields` supprime le bruit technique mais vide le libellé des liens.** Un champ de lien demandé dans `fields` revient sous la forme `{"id": 1, "fields": {}}` : on perd le nom. Sans `fields`, le lien revient avec son libellé, au prix des colonnes techniques (`CreatedAt`, `nc_..._id`). Choisir selon qu'un nom lié est utile ou non. La forme `Contact.Nom complet` dans `fields` est refusée.

---

## Restituer

Trois lignes maximum, en langage de dirigeant, jamais en compteurs bruts.

- « Trois personnes attendent une relance, dont Mme Le Goff depuis lundi. »
- Pas : « Contacts : 3. Tâches : 5. Échanges : 2. »

Nommer les personnes et les affaires. Un solo reconnaît des noms, pas des totaux.

---

## Proposer

Deux à quatre routines, numérotées, classées par urgence, formulées comme des actions. **Jamais dix propositions** : l'utilisateur veut savoir quoi faire maintenant, pas arbitrer un menu.

| Routine | Quand la proposer | Skill à appeler |
|---|---|---|
| Traiter les relances du jour | Des contacts sont à relancer | `rediger-email`, ou `enregistrer-echange` après un appel |
| Consigner un échange | L'utilisateur revient d'un appel ou d'un rendez-vous | `enregistrer-echange` |
| Suivre les invitations LinkedIn | En début de semaine | `import-capture-linkedin` |
| Préparer un rendez-vous | Un rendez-vous est proche | `rediger-email`, `tableau-de-bord` pour le contexte |
| Rattraper les affaires dormantes | Rien à faire d'urgent aujourd'hui | `tableau-de-bord` |
| Faire le point de la semaine | Vendredi, ou sur demande | `tableau-de-bord` |

Sur le choix de l'utilisateur, enchaîner **immédiatement** vers le skill. Ne pas commencer le travail ici.

---

## Règles

- **Aucune écriture.** Pas de création de tâche, pas de mise à jour de relance, même si cela semble utile.
- **Aucune procédure d'un autre skill recopiée ici.** Citer le nom, c'est tout.
- Une demande précise dès la première phrase : ne pas dérouler l'accueil, aller directement au skill concerné.
- Une page suffit. Si ce skill grossit, c'est qu'il empiète sur un autre.
- **Aucun tiret cadratin**, dans le texte produit comme dans les phrases dites autour. Le remplacer par une virgule ou deux points. C'est une signature d'écriture automatique, et l'utilisateur la lit.

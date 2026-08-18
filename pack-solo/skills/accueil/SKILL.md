---
name: accueil
description: Point de départ d'une session de travail commercial. À utiliser quand l'utilisateur ouvre une session sans demande précise, dit bonjour, demande par quoi commencer, ce qu'il a à faire aujourd'hui, ou où il en est. Lit l'état de la base et propose les routines du jour.
---

# Accueil

Ouvre la journée de travail commercial. Ce skill **lit** la base, restitue l'essentiel en trois lignes, puis propose deux à quatre routines.

**Il n'écrit jamais rien. Il ne contient aucune procédure métier.** Dès que l'utilisateur choisit une routine ou arrive avec une demande précise, passer la main au skill nommé et s'effacer.

---

## Le contexte du client, lu une fois par session

Avant tout, lire la table `Contexte`. Elle porte **un seul enregistrement** : qui est l'utilisateur, ce qu'il vend, à qui, ce qui le distingue, ce qui coince, comment il parle, comment il signe, où l'on réserve un rendez-vous avec lui, et ce qu'il ne fait pas.

```
queryRecords  Contexte  pageSize=1
              fields=["Entreprise", "Qui je suis", "Ce que je vends", "À qui je le vends",
                      "Ce qui me distingue", "Ce qui coince", "Comment je parle",
                      "Signature", "Lien de réservation", "Ce que je ne fais pas"]
```

**Une fois par session, jamais une fois par appel.** Ce contexte est stable : il se remplit à la mise en main et se revoit une fois par an. S'il a déjà été lu dans la conversation, le réutiliser tel quel sans rappeler la base.

**Lire les dix champs, même ceux dont ce skill n'a pas l'usage.** C'est délibéré : la lecture sert toute la session, et `rediger-email`, `accroche-linkedin` ou `creer-opportunite` s'en serviront ensuite sans repayer l'appel. Un skill qui n'en lirait que trois obligerait le suivant à tout relire.

**Si la table est vide ou l'enregistrement absent :** le dire en une phrase, continuer quand même, et signaler que les textes produits dans cette session seront génériques tant que le contexte n'est pas rempli. **Ne jamais deviner** ce que l'utilisateur vend ni comment il signe. Un contexte inventé produit un texte qui sonne juste et qui est faux, ce qui est le pire des deux cas.

**`Signature` se recopie, elle ne se réécrit pas.**

**`Ce que je ne fais pas` est un interdit, pas une indication.** Rien de ce qui y figure ne se propose, ne se promet ni ne se sous-entend dans un texte destiné à un tiers.

Ce que ce skill en fait, lui : s'adresser à l'utilisateur par son prénom et sur son registre, tutoiement ou vouvoiement compris, et **proposer des routines qui ont un sens pour son métier**. Un solo qui vend de la formation et un loueur de matériel n'ouvrent pas la même journée.

---

## Lire l'état, en quatre appels

Résoudre d'abord les identifiants de table avec `getTablesList`, une seule fois par session. Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.

| Ce qu'on cherche | Table | `where` | `sort` |
|---|---|---|---|
| Ce qui est à faire aujourd'hui ou en retard | Tâches | `(Statut,neq,Fait)~and(Échéance,lte,today)` | `Rang priorité` asc, puis `Échéance` asc |
| Les personnes à relancer | Contacts | `(Prochaine relance,lte,today)` | `Prochaine relance` asc |
| Les réponses reçues récemment | Échanges | `(Sens,eq,Entrant)~and(Date,isWithin,pastNumberOfDays,7)` | `Date` desc |
| Les affaires ouvertes | Opportunités | `(Étape,in,Identifiée,Contactée,RDV,Proposition)` | `Clôture prévue` asc |

`pageSize` 25 sur les deux premiers, 10 sur les deux autres. **Quatre appels pour l'état, pas cinq** : celui du contexte ci-dessus ne compte pas, il est payé une fois pour toute la session.

Sur Contacts, demander `fields` : `["Nom complet", "Prochaine relance", "Statut relation"]`. Sur Tâches, Échanges et Opportunités, **ne pas passer `fields`** : le nom du contact lié est nécessaire à la restitution, et il disparaît dès qu'on filtre les champs (voir la note ci-dessous).

> **Les affaires ouvertes se lisent, elles ne se devinent pas.** Ce quatrième appel existe pour une raison précise : sans lui, le briefing parle de l'état d'une affaire à partir du résumé d'un échange, et il se trompe dès que l'affaire a bougé depuis. Le filtre est écrit par valeurs retenues, `in`, et non par exclusion : le connecteur n'a pas d'opérateur `nin`.

> **Un état vide se dit vide.** Si les quatre listes ne rendent rien, le dire en une phrase, proposer de prospecter ou d'ouvrir le tableau de bord, et **s'arrêter là**. Le vide est une information, ce n'est pas un manque à combler : ne jamais aller chercher de la matière ailleurs pour remplir le briefing.

> **Un tri s'écrit `sort=[{"field": "Rang priorité", "description": "asc"}, {"field": "Échéance", "description": "asc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Date desc"` est refusée.

> **Le tri des tâches passe par `Rang priorité`, jamais par `Priorité`.** NoCoDB trie un select par ordre alphabétique de la valeur : un tri sur `Priorité` donnerait Basse avant Haute. `Rang priorité` est le champ technique qui porte le bon ordre.

> **`fields` supprime le bruit technique mais vide le libellé des liens.** Un champ de lien demandé dans `fields` revient sous la forme `{"id": 1, "fields": {}}` : on perd le nom. Sans `fields`, le lien revient avec son libellé, au prix des colonnes techniques (`CreatedAt`, `nc_..._id`). Choisir selon qu'un nom lié est utile ou non. La forme `Contact.Nom complet` dans `fields` est refusée.

> **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient. Ici, une base injoignable veut dire qu'on n'ouvre pas la journée : le dire en une phrase et s'arrêter, plutôt que de proposer des routines sur un état qu'on n'a pas lu.

---

## Restituer

Trois lignes maximum, en langage de dirigeant, jamais en compteurs bruts.

- « Trois personnes attendent une relance, dont Mme Le Goff depuis lundi. »
- Pas : « Contacts : 3. Tâches : 5. Échanges : 2. »

Nommer les personnes et les affaires. Un solo reconnaît des noms, pas des totaux.

> **Ce qui reste à faire vit dans `Tâches`, et nulle part ailleurs.** Un échange raconte le passé, il ne prescrit pas le présent. **Une intention lue dans le résumé ou l'objet d'un échange ne devient jamais une action proposée** : « un devis est attendu sous trois jours », écrit le 12, ne dit rien de ce qui a été fait depuis. Si un échange semble appeler une suite qu'aucune tâche ne porte, **poser la question en citant la date de l'échange**, jamais l'affirmer au présent. « L'échange du 12 août parlait d'un devis attendu, aucune tâche ne le porte : est-ce parti ? » et non « Thomas attend un devis ».

> **Ne jamais présenter un chiffre calculé de tête. Tout nombre annoncé sort d'un appel.** Et **un compte et la liste qui l'accompagne sortent du même appel** : si on peut nommer les lignes, on les compte ; si on ne peut pas les nommer, on ne donne pas de nombre. Annoncer sept invitations puis en énumérer six est une erreur que l'utilisateur voit, et qui abîme tout le reste du briefing.

> **Une date se dit telle qu'elle est en base.** Pas de « cette semaine », de « il y a quelques jours » ni de « depuis un mois » calculés au jugé : donner la date, ou vérifier le calcul contre la date lue. Le jour de la semaine se déduit de la date, il ne se suppose pas.

---

## Proposer

Deux à quatre routines, numérotées, classées par urgence, formulées comme des actions. **Jamais dix propositions** : l'utilisateur veut savoir quoi faire maintenant, pas arbitrer un menu.

| Routine | Quand la proposer | Skill à appeler |
|---|---|---|
| Traiter les relances du jour | Des contacts sont à relancer | `rediger-email`, ou `enregistrer-echange` après un appel |
| Consigner un échange | L'utilisateur revient d'un appel ou d'un rendez-vous | `enregistrer-echange` |
| Marquer une tâche comme faite | Une tâche du jour est accomplie, avec ou sans échange à raconter | `enregistrer-echange` |
| Suivre les invitations LinkedIn | En début de semaine | `import-capture-linkedin` |
| Préparer un rendez-vous | Un rendez-vous est proche | `rediger-email`, `tableau-de-bord` pour le contexte |
| Rattraper les affaires dormantes | Rien à faire d'urgent aujourd'hui | `tableau-de-bord` |
| Faire le point de la semaine | Vendredi, ou sur demande | `tableau-de-bord` |
| Voir où en sont ses objectifs | Début ou fin de mois, **et seulement si la table `Objectifs` en porte** | `point-strategique` |

Sur le choix de l'utilisateur, enchaîner **immédiatement** vers le skill. Ne pas commencer le travail ici.

> **Ne jamais proposer `point-strategique` sans avoir vu un objectif.** Le proposer sur une table vide envoie l'utilisateur vers une compétence qui n'aura rien à lui dire. Si aucun objectif n'existe, la bonne proposition est de lui demander s'il veut s'en fixer un, ce qui est une conversation, pas un skill.

---

## Règles

> **Plusieurs demandes dans un message se traitent toutes. Règle transverse, elle vaut pour toute la session, y compris après le passage de main.** Une pièce jointe ne remplace pas la phrase qui l'accompagne : une image capte l'attention, et la demande écrite juste à côté tombe. Reformuler les demandes lues, les exécuter dans l'ordre où elles sont écrites, et **si l'une est écartée, le dire**. Une demande exécutée en silence et une demande oubliée en silence se ressemblent trop : l'utilisateur ne peut distinguer ni l'une ni l'autre d'un travail fait.

- **Aucune écriture.** Pas de création de tâche, pas de mise à jour de relance, même si cela semble utile. **Une tâche à clore part vers `enregistrer-echange`, avec son `Id`** : c'est lui qui écrit `Statut: Fait`, y compris quand il n'y a aucun échange à consigner.
- **Aucune procédure d'un autre skill recopiée ici.** Citer le nom, c'est tout.
- Une demande précise dès la première phrase : ne pas dérouler l'accueil, aller directement au skill concerné.
- Une page suffit. Si ce skill grossit, c'est qu'il empiète sur un autre.
- **Aucun tiret cadratin**, dans le texte produit comme dans les phrases dites autour. Le remplacer par une virgule ou deux points. C'est une signature d'écriture automatique, et l'utilisateur la lit.

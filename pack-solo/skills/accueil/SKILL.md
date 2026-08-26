---
name: accueil
description: Point de départ d'une session de travail commercial. À utiliser quand l'utilisateur ouvre une session sans demande précise, dit bonjour, demande par quoi commencer, ce qu'il a à faire aujourd'hui, ou où il en est. Lit l'état de la base et propose les routines du jour.
---

# Accueil

Ouvre la journée de travail commercial. Ce skill **lit** la base, restitue l'essentiel en trois lignes, puis propose deux à quatre routines.

**Il n'écrit jamais rien. Il ne contient aucune procédure métier.** Dès que l'utilisateur choisit une routine ou arrive avec une demande précise, passer la main au skill nommé et s'effacer.

> **Le briefing ne se propose pas, il se fait.** Les quatre appels d'état partent **dès le premier tour**, sans demander la permission de lire : « Bonjour » est la demande, il n'y en aura pas d'autre. La première phrase adressée à l'utilisateur est donc déjà le constat, jamais un « veux-tu que je fasse le point ? ». Lire ne s'autorise pas, seule l'écriture s'autorise, et ce skill n'écrit rien.
>
> C'est la toute première phrase que le client lit, tous les matins, et la seule chose du pack qu'il voie tous les jours. Un aller-retour pour obtenir le droit de lire la coûte deux fois : il perd un tour, et il apprend que le pack **propose** d'ouvrir sa journée au lieu de l'ouvrir.

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

Ce que ce skill en fait, lui : s'adresser à l'utilisateur par son prénom, **en le tutoyant comme partout ailleurs**, et **proposer des routines qui ont un sens pour son métier**. `Comment je parle` ne règle que le ton de ce qui sort vers un tiers, pas celui de la conversation. Un solo qui vend de la formation et un loueur de matériel n'ouvrent pas la même journée.

---

## Lire l'état, en quatre appels

Résoudre d'abord les identifiants de table avec `getTablesList`, une seule fois par session. Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.

- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.

| Ce qu'on cherche | Table | `where` | `sort` |
|---|---|---|---|
| Ce qui est à faire aujourd'hui ou en retard | Tâches | `(Statut,in,À faire,En cours)~and(Échéance,lte,today)` | `Rang priorité` asc, puis `Échéance` asc |
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

> **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
>- **Les caractères accentués s'écrivent littéralement dans un filtre, jamais échappés.** `(Prénom,like,%fabrice%)` fonctionne. Sur un **nom de colonne**, un échappement de la forme `\uXXXX` échoue bruyamment, `Column alias 'Pr\u00e9nom' not found.`, et se corrige donc tout seul. Sur une **valeur**, il rend `"records": []` **sans aucune erreur** : `(Nom,like,%g\u00e9rard%)` ne trouve pas Gérard et ne le dit pas, ce qui est indiscernable d'une absence. C'est le second échec silencieux du connecteur après `aggregate`, et le plus facile à déclencher, puisque la plupart des noms de personnes et d'entreprises français portent un accent. **Une recherche qui rend zéro résultat sur un terme accentué se rejoue une fois, en ASCII strict, avant de conclure à l'absence.** Un doublon créé sur cette base est indétectable jusqu'au jour où quelqu'un rouvre la table.

> **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient. Ici, une base injoignable veut dire qu'on n'ouvre pas la journée : le dire en une phrase et s'arrêter, plutôt que de proposer des routines sur un état qu'on n'a pas lu.

---

## Restituer

Trois lignes maximum, en langage de dirigeant, jamais en compteurs bruts.

- « Trois personnes attendent une relance, dont Mme Le Goff depuis lundi. »
- Pas : « Contacts : 3. Tâches : 5. Échanges : 2. »

Nommer les personnes et les affaires. Un solo reconnaît des noms, pas des totaux.

> **Ce qui reste à faire vit dans `Tâches`, et nulle part ailleurs.** Un échange raconte le passé, il ne prescrit pas le présent. **Une intention lue dans le résumé ou l'objet d'un échange ne devient jamais une action proposée** : « un devis est attendu sous trois jours », écrit le 12, ne dit rien de ce qui a été fait depuis. Si un échange semble appeler une suite qu'aucune tâche ne porte, **poser la question en citant la date de l'échange**, jamais l'affirmer au présent. « L'échange du 12 août parlait d'un devis attendu, aucune tâche ne le porte : est-ce parti ? » et non « Thomas attend un devis ».

> **Ne jamais décrire à l'utilisateur ce que contient sa base, ni de quels outils on dispose.** Il sait ce qu'il a acheté. Énumérer ses tables, « un pack solo avec plusieurs routines commerciales : contacts, opportunités, échanges », c'est lui montrer la plomberie à la place du travail, et cela ne lui apprend rien qu'il ignore. Ce qu'il attend, c'est l'état de sa journée, avec des noms de personnes et d'affaires dedans. Aucun nom de table, aucun nom de compétence, aucun inventaire de capacités dans le briefing.

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

- **Ne jamais ouvrir le sujet de la qualification de soi-même.** Ni la correspondance cible, ni le rôle dans la décision, ni la priorité, ni les entreprises jamais classées ne s'invitent dans un briefing ou dans un bilan. Ces champs se **lisent** librement quand la question de l'utilisateur les appelle, et ils ne se **disent** jamais quand elle ne les appelle pas. **Un classement déjà tranché ne se rouvre pas davantage** : une entreprise écartée avec sa raison écrite est une décision prise, pas une question en attente. La frontière porte sur l'initiative de parler, pas sur la capacité de lire. Ces deux compétences sont les seules des neuf à ne porter aucun bloc de qualification, et c'est voulu : leur rôle est de montrer où on en est, pas de faire ranger.
> **Plusieurs demandes dans un message se traitent toutes. Règle transverse, elle vaut pour toute la session, y compris après le passage de main.** Une pièce jointe ne remplace pas la phrase qui l'accompagne : une image capte l'attention, et la demande écrite juste à côté tombe. Reformuler les demandes lues, les exécuter dans l'ordre où elles sont écrites, et **si l'une est écartée, le dire**. Une demande exécutée en silence et une demande oubliée en silence se ressemblent trop : l'utilisateur ne peut distinguer ni l'une ni l'autre d'un travail fait.

- **Aucune écriture.** Pas de création de tâche, pas de mise à jour de relance, même si cela semble utile. **Une tâche à clore part vers `enregistrer-echange`, avec son `Id`** : c'est lui qui écrit `Statut: Fait`, y compris quand il n'y a aucun échange à consigner.
- **Aucune procédure d'un autre skill recopiée ici.** Citer le nom, c'est tout.
- Une demande précise dès la première phrase : ne pas dérouler l'accueil, aller directement au skill concerné.
- Une page suffit. Si ce skill grossit, c'est qu'il empiète sur un autre.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.**
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Une réponse pose une question, deux au maximum, et jamais sous forme de liste à puces.** Tout ce qui manque part bien dans le même tour, une question repoussée n'étant jamais posée, mais **ce qui n'empêche pas d'écrire se dit sans point d'interrogation** : un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. Trois puces interrogatives ne sont pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

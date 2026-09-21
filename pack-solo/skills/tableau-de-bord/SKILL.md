---
name: tableau-de-bord
description: Faire le point commercial, affaires en cours, chiffre en cours, relances en retard, activité de la période, affaires dormantes. À utiliser quand l'utilisateur demande où il en est, veut un bilan de semaine ou de mois, ou s'interroge sur un chiffre. Commente les chiffres, n'affiche pas que des compteurs.
---

# Tableau de bord

Fait le point **périodique** : bilan de semaine ou de mois, état des affaires en cours, affaires gagnées et perdues, affaires dormantes.

Le quotidien n'est pas ici : les relances du jour, les réponses reçues et les échanges récents relèvent de `accueil`. **La frontière, en une question : la demande porte-t-elle sur aujourd'hui, ou sur une période ?** Ce skill répond à « où j'en suis sur la semaine, sur le mois, depuis la dernière fois » ; `accueil` répond à « ce que je fais aujourd'hui ». **Ce n'est pas le mot employé qui décide, c'est le sujet** : une demande qui contient « cette semaine » mais qui veut savoir par qui commencer est une question du jour, et elle part là-bas. **Ce qui ne sépare pas les deux : recommander une action.** Les deux le font, et ce skill le fait en dernier point de sa restitution.

**Les objectifs ne sont pas ici non plus.** Dès que l'utilisateur parle de sa cible, de ce qu'il s'était fixé, ou demande s'il est dans les clous, c'est `point-strategique` qui répond, parce qu'il faut lire la table `Objectifs` pour lui répondre. La frontière, en une question : la demande garde-t-elle un sens sur une base qui ne porte aucun objectif ? Si oui, elle est ici.

**Il n'écrit rien.** Il lit, il calcule, il interprète.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par fenêtre.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Une écriture voyage dans `records`, et chaque enregistrement dans `fields`.** `createRecords` attend `{"records": [{"fields": {…}}]}`, `updateRecords` attend `{"records": [{"id": n, "fields": {…}}]}`, et `deleteRecords` attend `{"records": [{"id": n}]}`. Un enregistrement envoyé à plat échoue **en entier** sur `MCP error -32602: Input validation error`, `"path": ["records"]` puis `["records", 0, "fields"]` : deux blocs rouges sous les yeux de l'utilisateur avant que l'écriture parte, mesurés le 16 septembre 2026. Les blocs écrits plus bas montrent les champs à plat pour se lire, c'est `records[].fields` qui les reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **`Dernier échange` et `Étape depuis` ressemblent à des champs calculés, et ce sont des champs que les compétences écrivent.** `Contacts.Dernier échange` porte la date du dernier échange consigné, `Opportunités.Étape depuis` la date du dernier changement d'étape. **La base ne les remplit pas** : le schéma v1.8 les voulait en rollup, l'instance ne le permet pas, la fonction `max` d'un rollup y étant réservée à un plan payant. Deux conséquences, et aucune n'est facultative : **toute écriture d'un échange réécrit `Dernier échange`**, toute écriture de `Étape` réécrit `Étape depuis`, dans le même appel et à la date de l'événement, pas à celle de la saisie ; et **une valeur vide veut dire « jamais écrit », pas « jamais d'échange »**, donc un filtre `lt` sur ces champs rend une liste incomplète tant que le parc n'est pas repassé une fois.
- **`Ouverte` dit si une tâche ou une affaire est en cours, et il se lit avec `eq`, jamais avec `in`.** C'est une colonne **calculée par la base** : elle vaut `1` tant qu'une tâche n'est ni `Fait` ni `Annulée`, et `1` tant qu'une affaire n'est ni `Gagnée` ni `Perdue`. Elle remplace depuis le schéma v1.8 les filtres par énumération, `(Statut,in,À faire,En cours)` et `(Étape,in,Identifiée,Contactée,RDV,Proposition)`, qui se mettaient à mentir en silence dès qu'une valeur était ajoutée à la liste. **Deux règles vont avec, et aucune n'est facultative :** l'opérateur `in` échoue bruyamment sur une colonne calculée, `(Ouverte,in,1)` compris, donc `(Ouverte,eq,1)` est la seule forme valide ; et **`Ouverte` ne s'écrit jamais**, c'est `Statut` ou `Étape` qu'on écrit, la base recalcule.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Date", "direction": "desc"}]`.** La clé qui porte le sens s'appelle `direction`, et c'est la seule admise : `description`, l'ancien nom, est refusé par le connecteur, `Required at sort[0].direction`. Une chaîne comme `"Date desc"` est refusée aussi.
- **Filtrer et compter côté requête**, jamais en rapatriant la table pour compter soi-même. C'est la règle qui rend ce skill tenable sans dashboard natif.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Un champ de **compteur de liens**, lui, survit à `fields`.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
- **Les caractères accentués s'écrivent littéralement dans un filtre, jamais échappés.** `(Prénom,like,%fabrice%)` fonctionne. Sur un **nom de colonne**, un échappement de la forme `\uXXXX` échoue bruyamment, `Column alias 'Pr\u00e9nom' not found.`, et se corrige donc tout seul. Sur une **valeur**, il rend `"records": []` **sans aucune erreur** : `(Nom,like,%g\u00e9rard%)` ne trouve pas Gérard et ne le dit pas, ce qui est indiscernable d'une absence. C'est le second échec silencieux du connecteur après `aggregate`, et le plus facile à déclencher, puisque la plupart des noms de personnes et d'entreprises français portent un accent. **Une recherche qui rend zéro résultat sur un terme accentué se rejoue une fois, en ASCII strict, avant de conclure à l'absence.** Un doublon créé sur cette base est indétectable jusqu'au jour où quelqu'un rouvre la table.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.
- **`countRecords` peut manquer, et son repli s'écrit ici plutôt que de s'improviser.** Les appels de comptage ci-dessous le nomment, et il a déjà été annoncé indisponible en séance. **S'il manque, le repli est `aggregate` avec `count_filled` sur un champ toujours rempli, et sur son identifiant de colonne, jamais son titre** : c'est le seul appel du connecteur qui rend `{}` sans erreur, donc le seul où un repli mal écrit rend un zéro crédible au lieu de planter. Le repli se prend **en silence** : l'utilisateur n'a pas à savoir quel outil a servi.

> **Une fenêtre de dates ne s'écrit pas avec `btw`, malgré la documentation de l'outil.** `(Date,btw,2026-08-01,2026-08-31)` échoue, sur un champ `Date` comme sur un champ `CreatedTime` : `Error: '2026-08-01' is not supported.` La forme qui marche encadre la période avec deux comparaisons : `(Date,gte,exactDate,2026-08-01)~and(Date,lte,exactDate,2026-08-31)`. **La borne haute inclut la journée entière**, même horodatée. Vérifié le 17 août 2026 aux deux bornes.
>
> C'est ce qui rend un **mois calendaire** mesurable. Les fenêtres `isWithin,pastNumberOfDays,30` utilisées plus bas sont des fenêtres **glissantes** : elles conviennent à « ces trente derniers jours », pas à « le mois d'août ». Quand l'utilisateur demande un mois, il pense au mois calendaire : employer alors la forme `exactDate`.

---

## L'outil `aggregate`, et ses deux pièges

`aggregate` calcule sommes et comptages côté serveur, sur **plusieurs filtres en un seul appel**. C'est lui qui rend un bilan complet possible en deux ou trois allers-retours. Il a deux comportements à connaître, tous deux vérifiés sur la base de référence.

> **1. `aggregate` ne comprend que les identifiants de colonne, jamais les titres.** Un titre de champ renvoie `{}`, **sans message d'erreur**. C'est la seule réponse silencieuse observée sur ce MCP : partout ailleurs un nom approché échoue bruyamment. Lire donc `getTableSchema` sur les tables concernées, une fois par fenêtre, et retenir les `id` des colonnes utiles.

> **2. Le résultat est indexé par le titre du champ.** Deux agrégations sur le **même** champ dans un même appel s'écrasent donc, et la dernière gagne, silencieusement. Une agrégation par champ et par appel. Plusieurs champs différents dans un appel, en revanche, fonctionnent, et plusieurs `filterGroups` aussi.

Forme réelle d'un appel, avec les identifiants lus dans le schéma :

```
1. getTableSchema  Opportunités   ← toujours, une fois par fenêtre, avant tout aggregate.
                                    Lu plus tôt dans la même fenêtre, il ne se relit pas
                                    Retenir les id de « Montant estimé » et de « Nom »
2. aggregate       Opportunités
   aggregations = [
     { field: "<id de Montant estimé>",  type: "sum" },
     { field: "<id de Nom>",             type: "count_filled" }
   ]
   filterGroups = [
     { alias: "en_cours",    where: "(Ouverte,eq,1)" },
     { alias: "proposition", where: "(Étape,eq,Proposition)" },
     { alias: "gagnees",     where: "(Étape,eq,Gagnée)~and(Clôture prévue,isWithin,pastNumberOfDays,30)" },
     { alias: "perdues",     where: "(Étape,eq,Perdue)~and(Clôture prévue,isWithin,pastNumberOfDays,30)" },
     { alias: "tout" }
   ]
```

> **Un `aggregate` qui rend `{}`, `null` ou un total à zéro ne se publie pas.** C'est la seule réponse silencieuse du connecteur, et un zéro crédible est plus dangereux qu'une erreur. Le repli est `countRecords` sur le même filtre, pris **en silence** : l'utilisateur n'a pas à savoir quel outil a servi. **Un chiffre publié vient de l'appel qui l'a rendu, jamais d'un calcul de rattrapage sur une liste déjà lue.**

Réponse : un objet par alias, chaque valeur indexée par titre de champ.

```
{ "en_cours": { "Montant estimé": 5000, "Nom": 3 }, "gagnees": { ... } }
```

Un `filterGroups` sans `where` porte sur toute la table. `count_filled` sur le champ titre est le comptage d'enregistrements le plus fiable. Pour les périodes, `countRecords` reste plus simple quand un seul chiffre suffit.

---

## Ce qu'on va chercher

Cinq blocs, dans cet ordre. Ne pas tout sortir à chaque fois : suivre la question posée.

### 1. Les affaires en cours

Un `aggregate` sur Opportunités, comme ci-dessus : montant et nombre d'affaires en cours, dont celles en proposition. C'est le chiffre que l'utilisateur attend en premier.

### 2. Ce qui s'est conclu sur la période

Gagnées et perdues, filtrées sur `Clôture prévue`. Toujours **les deux**, jamais les gagnées seules : un taux de transformation se lit sur les deux nombres.

**Puisque ce bloc filtre sur `Clôture prévue`, compter aussi ce qu'il ne verra jamais :**

```
countRecords  Opportunités  where=(Ouverte,eq,1)~and(Clôture prévue,blank)
```

**Ce comptage n'est pas facultatif, et il ne va pas dans les commentaires : il fait partie du bloc 2.** Dès qu'il est supérieur à zéro, il se dit, en une ligne : « deux affaires en cours n'ont pas de date de clôture prévue, elles ne compteront dans aucun bilan tant qu'elle manque. » Le 19 août 2026, l'appel a été fait, le résultat n'a pas été dit, et une affaire à 4 000 € est restée invisible. Ces affaires-là seraient signées demain sans rien apporter au chiffre du mois, et rien ne le signalerait : le bilan resterait juste au sens du calcul et faux au sens du réel. **Un trou de mesure se signale, il ne se comble pas tout seul** : la date se pose dans `creer-opportunite`, qui la propose à toutes les étapes.


**Deux jumeaux, comptés dans le même bloc et soumis à la même obligation :**

```
countRecords  Opportunités  where=(Ouverte,eq,1)~and(Montant estimé,blank)
countRecords  Opportunités  where=(Ouverte,eq,1)~and(Clôture prévue,lt,today)
```

**Ces deux comptages ne sont pas facultatifs et ils ne vont pas dans les commentaires.** Dès que l'un est supérieur à zéro, il se dit, en une ligne :

- **Affaires en cours sans `Montant estimé`** : « deux des sept affaires n'ont pas de montant, le total ne les compte pas. »
- **Affaires en cours dont `Clôture prévue` est passée** : « une affaire a dépassé sa date de clôture prévue sans être fermée, elle est à trancher. »

Le premier est le jumeau exact du comptage ci-dessus : un total annoncé sur sept affaires dont deux sans montant est un total juste au sens du calcul et faux au sens du réel, et c'est la même erreur, sur l'autre champ. Le second ne signale pas un trou de mesure mais une décision en retard, et il se dit de la même façon, sans commentaire.

**Nommer les affaires concernées, jamais les compter seulement.** Le compte et la liste sortent du même appel : c'est `queryRecords` avec le même `where` s'il faut les nommer, pas `countRecords` suivi d'une liste écrite de mémoire. Signaler à tort une affaire datée comme non datée coûte la même confiance que d'en oublier une.

### 3. L'activité

```
countRecords  Échanges  where=(Date,isWithin,pastNumberOfDays,7)
countRecords  Échanges  where=(Date,isWithin,pastNumberOfDays,7)~and(Sens,eq,Entrant)
```

Le rapport entrant sur sortant dit si la prospection prend. Adapter la fenêtre à la question : 7 jours pour une semaine, 30 pour un mois.

> **La répartition entrants/sortants ne se commente pas tant que les invitations acceptées y comptent.** Une invitation acceptée est consignée comme un échange entrant, et elle gonfle le compte des entrants sans qu'une seule personne ait écrit ni appelé. Soit elles sont exclues du comptage et la phrase le dit, soit le bilan donne les nombres sans en tirer de conclusion sur la prospection. **Une statistique qu'on ne sait pas interpréter ne se commente pas.**
>
> **Aucun filtre simple ne les isole** : elles partagent le canal `LinkedIn` avec de vraies conversations. Tant que rien ne les distingue en base, c'est la seconde branche qui s'applique, les nombres sans le commentaire.

### 4. Ce qui traîne

```
countRecords  Tâches    where=(Ouverte,eq,1)~and(Échéance,lt,today)
countRecords  Contacts  where=(Prochaine relance,lt,today)
```

Deux nombres, pas de liste : `accueil` s'occupe du détail du jour.

**Et quand la question porte sur l'ancienneté d'une relance, deux appels de plus, qui rendent une liste nommée :**

```
queryRecords  Contacts  where=(Dernier échange,lt,exactDate,<date du jour moins N jours>)
                        sort=[{"field":"Dernier échange","direction":"asc"}]
countRecords  Contacts  where=(Dernier échange,blank)
```

> **Une question d'ancienneté de relance se répond sur `Dernier échange`, en un appel, jamais en rapprochant la table des échanges.** Le champ existe pour cela, et chaque consignation d'échange le tient à jour. Cinq appels qui refont le rapprochement à la main rendent une liste **plus courte** que la vraie, tout en donnant l'impression d'un travail approfondi.
>
> **Le second appel n'est pas facultatif, et sa réponse se dit.** Un filtre `lt` ne retient jamais une valeur vide : les contacts dont `Dernier échange` n'a jamais été écrit sont **invisibles par construction**, et ce sont précisément les plus anciens. **Le compte des contacts sans date se donne dans la même réponse que la liste**, sur le modèle de la tranche du point stratégique, dont il ne se sépare pas : « voici les sept que je vois, et douze autres n'ont aucune date d'échange en base, je ne peux rien dire de ceux-là. »
>
> **Le périmètre de la question est celui de la question.** Si la réponse se restreint aux contacts en discussion ou déjà clients, **cette restriction s'annonce avant la liste**, et elle ne s'invente pas : rien dans « qui n'ai-je pas relancé » ne l'autorise. **« Personne » est une réponse qui ferme un sujet**, et elle ne s'écrit que lorsque la lecture complète, trou de mesure déclaré, ne rend rien.
>
> **Deux contacts qui portent la même date sortent tous les deux.** Le 1er septembre 2026, l'un des deux a été nommé comme « le plus proche de la limite » et l'autre omis, alors qu'il portait le même jour et qu'il était le contact de l'affaire que la même fenêtre venait de signaler trois fois comme la plus urgente.

### 5. Les affaires dormantes

Deux cas, dans cet ordre.

**Jamais d'échange.** Le champ `Échanges` d'une opportunité est un compteur de liens, filtrable directement, et il survit à `fields`. **La borne d'âge n'est pas facultative** : une affaire ouverte aujourd'hui n'a évidemment aucun échange, et ce zéro-là ne dit rien.

```
queryRecords  Opportunités  where=(Ouverte,eq,1)~and(Échanges,eq,0)~and(CreatedAt,lt,daysAgo,7)
                            fields=["Nom","Étape","Échanges"]
```

**Une affaire n'est dormante qu'après un délai.** En dessous de sept jours, le zéro dit qu'elle vient de naître, pas qu'elle coince. La présenter comme « ce qui coince » est un reproche adressé à un travail qu'on vient de faire, et c'est la façon la plus rapide de rendre un bilan inutile. Si l'utilisateur s'étonne de ne pas y voir une affaire toute neuve, le dire en une phrase : « elle est trop récente pour que ça veuille dire quelque chose ».
**Plus d'échange depuis longtemps.** NoCoDB ne sait pas filtrer sur « date du dernier échange lié », et l'instance ne peut pas la calculer non plus : la fonction `max` d'un rollup y est réservée à un plan payant. **Sur une affaire, elle se reconstruit donc en deux appels.**

```
queryRecords  Opportunités  where=(Ouverte,eq,1)
queryRecords  Échanges      where=(Date,isWithin,pastNumberOfDays,30)~and(Opportunité,notblank)
                            sort=[{"field": "Date", "direction": "desc"}]  pageSize=100
```

Les affaires en cours qui n'apparaissent dans aucun de ces échanges sont les dormantes. Ne pas passer `fields` sur le second appel : c'est le libellé de l'opportunité liée qui permet le rapprochement, et il disparaît dès qu'on filtre les champs.

**Sur une personne, un seul appel suffit, et c'est nouveau.** `Contacts.Dernier échange` porte la date, écrite par les compétences à chaque échange consigné. Ne pas reconstruire ici ce qui est déjà dans un champ.

```
queryRecords  Contacts  where=(Statut relation,in,En discussion,Client)~and(Dernier échange,lt,daysAgo,45)
                        fields=["Nom complet","Statut relation","Dernier échange"]
```

> **Un contact sans `Dernier échange` du tout ne sort pas de ce filtre, et ce n'est pas un contact frais.** Le champ n'existe que depuis le 31 août 2026 : tout ce qui a été consigné avant est vide, et un `lt` ne retient jamais une valeur vide. Les vieux dossiers silencieux passeront donc à travers pendant quelques semaines, le temps que chacun repasse par un échange. **Le dire une fois si l'utilisateur s'étonne d'une liste courte**, ne pas en faire un avertissement permanent, et ne surtout pas combler le trou en écrivant une date de dernier échange qu'aucun échange ne porte.

---

## Restituer

**Un tableau seul est un échec.** La valeur de ce skill est l'interprétation, c'est le différenciant de l'offre.

Structure :

1. **Deux ou trois phrases de constat**, en langage de dirigeant. « Tu as 12 400 € en cours sur cinq affaires, dont deux propositions envoyées il y a plus de trois semaines. »
2. **Un petit tableau**, si et seulement s'il éclaire. Cinq lignes maximum. **Une colonne se nomme d'après ce qu'elle contient, pas d'après ce qu'on espère.** Une colonne « Client » qui porte des prospects, dont deux affaires perdues, est fausse à chaque ligne : elle s'appelle « Personne ». Le même test vaut pour toutes les autres, et il se fait sur le contenu réel du tableau, une fois les lignes écrites. **Un tableau est une suite de chiffres annoncés, il obéit à la même règle qu'une phrase** : chaque cellule sort de l'appel qui a produit la ligne, jamais d'un souvenir de la conversation, y compris pour une valeur écrite une heure plus tôt dans la même session. **Et le tableau se recoupe avec le total avant d'être affiché** : si la somme des montants affichés ne fait pas le total annoncé, l'un des deux est faux, et c'est presque toujours le tableau. Un tableau qui contredit son propre total n'éclaire pas, il abîme la confiance dans le chiffre qui, lui, était juste.
3. **Ce qui a bougé**, par rapport à la période précédente quand l'information existe. Un chiffre sans variation ne dit rien.
4. **Ce qui coince**, nommément. « Les affaires Kervella et Autret n'ont plus bougé depuis un mois. »
5. **Une recommandation actionnable**, une seule, et le skill qui la porte. « Le plus rentable aujourd'hui : relancer les deux propositions. Je peux préparer les mails. »

> **Une recommandation est une affirmation sur l'état de la base : elle obéit aux mêmes règles qu'un chiffre.** Toute affaire, tâche ou personne **nommée** dans la conclusion se relit **par un appel, dans le tour où la phrase s'écrit**. Jamais depuis un état lu plus tôt dans la conversation, même de quelques minutes : entre-temps, la même session a pu écrire. La conclusion est la seule partie de ce skill qui ne sorte d'aucun appel, donc la seule qui puisse mentir pendant que les chiffres, eux, restent justes.
>
> Le cas réel, le 19 août 2026 : « chiffrer et dater la clôture prévue des deux affaires en RDV » a été conseillé sur une affaire qui portait son montant et sa date depuis vingt-six minutes, écrits dans la même session. Un client qui suit le conseil refait un travail déjà fait, un client qui vérifie cesse de lire la conclusion.
>
> **Et la règle vaut d'abord contre la session elle-même.** Un comptage de qualification, de vivier ou de reste à faire se relit intégralement au moment où il est dit, **surtout** quand la session vient d'écrire les lignes qu'il compte : ce qu'elle croit avoir écrit n'est pas ce que la base porte. Le 25 août 2026, un chiffre annoncé de bonne foi était faux d'une unité pour cette seule raison, et 11 sur 23 était parfaitement crédible.

Nommer les personnes et les affaires. Un solo reconnaît des noms, pas des totaux.

> **Une date affichée se recopie, elle ne se raconte pas.** Quand une échéance ou une date d'échange est nommée dans la réponse, elle reprend la valeur lue en base, au format que l'utilisateur reconnaîtra, « le 24 août » plutôt que « hier » ou « mercredi ». Les repères relatifs se calculent à partir de la date du jour **relue**, jamais estimée. Le jour de la semaine se déduit de la date, il ne se suppose pas.
>
> **Et cela vaut pour toute date lue dans un texte, pas seulement pour un champ de date.** Une note de classement, un résumé d'échange, une observation datée se citent avec leur date en clair, jamais en relatif. **Une date stockée franchit minuit, une date racontée en relatif ne le franchit pas** : une fenêtre ouverte la veille garde en tête un « aujourd'hui » périmé. C'est le piège propre aux sessions qui durent plus d'une journée, et il n'existe pas en démonstration.
>
> **Une durée est un calcul entre deux dates lues, jamais une impression.** « Depuis plus d'un mois », « ça fait longtemps », « il y a plusieurs semaines » ne s'écrivent que si la date de départ a été lue dans ce tour et soustraite de la date du jour, elle aussi relue. **Dans le doute, on donne la date plutôt que la durée** : « son dernier échange date du 26 août » est toujours vrai et toujours utile, là où « depuis plus d'un mois » est faux dès qu'on se trompe d'un facteur cinq. **Une durée fausse est invisible à la relecture quand elle voisine avec des chiffres justes** : le lecteur qui a vérifié les quatre premiers ne recompte pas le cinquième.

> **Une tâche n'est pas un événement.** Une tâche dont l'intitulé décrit une préparation reste une préparation : elle se rappelle comme du travail en attente, pas comme un rendez-vous tenu. **Rien ne dit qu'un rendez-vous a eu lieu tant qu'un échange de canal `RDV` ne le porte pas.**

Sur une base presque vide, le dire en une phrase et s'arrêter. Un bilan sur trois enregistrements n'a pas de sens, et gonfler la restitution ferait perdre confiance.

> **Un bilan de période produit un artéfact, la restitution dans le fil restant ce qu'elle est.** L'artéfact est la trace que l'utilisateur garde et rouvre ; le fil porte le constat, ce qui coince et la recommandation. **Il ne part que sur un bilan de période**, jamais sur une question rapide du type « où en sont mes affaires » : une question d'une ligne à laquelle on répond par une page devient une question qu'on ne pose plus.
>
> **Trois graphiques, et rien d'autre.** Des barres en HTML et CSS, **aucune librairie externe** : ce qui doit rester lisible dans six mois ne dépend d'aucun chargement.
>
> 1. **Les affaires ouvertes par étape**, une barre par étape, avec le compte et le montant. **Les affaires sans montant forment leur propre bande, nommée « montant non renseigné »**, jamais fondue dans les autres et jamais comptée pour zéro.
> 2. **L'activité de la période**, une barre par semaine, entrants et sortants empilés. **La réserve sur les invitations LinkedIn s'écrit dans le graphique**, pas seulement dans le fil : elles gonflent le compte des entrants sans être de vrais échanges, et un graphique se relit sans son commentaire.
> 3. **L'âge des affaires ouvertes**, une barre par affaire, en jours depuis `Étape depuis`. Les affaires dont le champ est vide se listent **sous** le graphique, nommées, avec la mention que leur âge n'est pas mesurable.
>
> **Aucune courbe de progression, jamais.** La base ne garde aucun historique des montants ni des étapes : un chiffre d'affaires qui monte au fil des semaines, un entonnoir qui évolue, une comparaison avec le mois précédent seraient **reconstitués**, c'est-à-dire inventés. Ce qui se dessine est un état à une date, jamais une trajectoire. C'est le piège naturel d'une demande de graphique, et il se refuse d'avance.
>
> **L'artéfact porte en tête sa date de génération, la période couverte et le nombre d'enregistrements lus par graphique.** Une trace rouverte trois mois plus tard sans ces trois lignes ment sur son propre âge, et c'est le seul défaut qu'un artéfact peut avoir et qu'une réponse dans le fil n'a pas.
>
> **Ce qui manque se dessine, il ne se cache pas.** Un trou de mesure a sa bande, avec son nom, dans le graphique où il tombe. Un graphique qui n'affiche que ce qui est renseigné se lit comme s'il affichait tout.
>
> **Un chiffre du graphique et un chiffre du fil sortent du même appel.** La règle du tableau vaut pour la barre : si la somme des barres ne fait pas le total annoncé dans le fil, l'un des deux est faux.

---

## Garde-fous

- **Ne jamais ouvrir le sujet de la qualification de soi-même.** Ni la correspondance cible, ni le rôle dans la décision, ni la priorité, ni les entreprises jamais classées ne s'invitent dans un briefing ou dans un bilan. Ces champs se **lisent** librement quand la question de l'utilisateur les appelle, et ils ne se **disent** jamais quand elle ne les appelle pas. **Un classement déjà tranché ne se rouvre pas davantage** : une entreprise écartée avec sa raison écrite est une décision prise, pas une question en attente. La frontière porte sur l'initiative de parler, pas sur la capacité de lire. Ces deux compétences sont les seules des neuf à ne porter aucun bloc de qualification, et c'est voulu : leur rôle est de montrer où on en est, pas de faire ranger.
- **Aucune écriture.** Même une tâche qui semblerait évidente : la proposer, laisser le skill concerné la créer. **Une tâche à clore part vers `enregistrer-echange`, avec son `Id`** : c'est lui qui écrit `Statut: Fait`, même sans échange à consigner. Rendre ce service ici serait violer la règle, et le rendre nulle part serait pire : il a sa porte, elle est nommée.
- **Compter côté requête.** Jamais de rapatriement de table pour compter soi-même : c'est lent, coûteux, et faux dès que la base grossit.
- **Un compteur de liens ne répond pas à une question qui porte un statut.** `Opportunités.Échanges` et `Opportunités.Tâches` comptent des liens, pas des échanges récents ni des tâches ouvertes. Le compteur convient au bloc 5, « jamais d'échange », parce que zéro lien veut bien dire zéro échange. Partout où un statut ou une date entre en jeu, c'est une requête filtrée.
- **Ne pas recopier les vues NoCoDB.** « À relancer », « Ma journée », « Pipeline » et « Journal » restent consultables sur mobile sans IA. Ce skill apporte l'analyse, pas la liste.
- **Ni graphique, ni prévisionnel pondéré, ni probabilité.** Ils relèvent de l'option payante « Dashboard avancé », et le socle ne porte pas de champ probabilité.
- **Ne jamais présenter un chiffre calculé de tête.** Tout nombre annoncé sort d'un appel. En cas de doute sur un résultat, le recouper par un `countRecords` plutôt que l'arrondir.
- **Une recommandation se relit avant de s'écrire, exactement comme un chiffre se recompte.** Elle nomme des enregistrements, donc elle affirme quelque chose de leur état, donc elle se vérifie par un appel dans le tour même. Une règle qui ne parle que des chiffres laisse passer les conseils, et c'est le conseil que l'utilisateur suit.
- **Une date se dit telle qu'elle est en base.** « hier », « la semaine dernière », « il y a un mois » sont des calculs, et ils tombent faux exactement comme un total : les poser contre la date du jour avant de les écrire, ou citer la date. Une date fausse dans une phrase juste passe inaperçue.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre. **Et la règle porte sur le parcours, pas sur le mode d'emploi.** Quand l'utilisateur interroge la construction de sa base, compare deux champs, ou demande pourquoi une valeur plutôt qu'une autre, il pose une question d'outil et attend une réponse d'outil : les noms de champs et les valeurs se disent. **Le basculement est marqué par la question, jamais par la compétence.** Dès le tour suivant qui parle d'une personne ou d'une entreprise, on revient au français ordinaire.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.** **Tout ce qui s'affiche entre deux appels d'outil est une réponse.** Même langue, même vocabulaire, mêmes interdits que la phrase finale : le français, aucun nom de table ni de champ, aucune annonce de ce qui va être appelé. **Si rien n'a besoin d'être dit entre deux écritures, rien ne se dit.** **Un enchaînement ne se raconte pas davantage qu'un outil.** Ni « Historique : », ni « Maintenant, l'échange de ce matin », ni aucun titre de section qui décrive l'étape où l'on se trouve. Ce sont des étiquettes de procédure, et « journal » est un nom d'objet interne. **Ce qui vient d'être écrit se dit une fois, en français, dans la phrase de confirmation prévue pour cela**, et pas une seconde fois en tête du geste suivant.
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **Le jargon commercial anglais ne se dit pas davantage.** `pipeline`, `lead`, `funnel`, `closing` ne se disent pas. On dit « tes affaires en cours », « ta plus grosse affaire », « ce que tu as en discussion ». C'est la règle du vocabulaire de la base élargie d'un cran : le nom d'une colonne trahit le schéma, un mot de jargon trahit le métier de celui qui a écrit l'outil. **`pipeline` est un mot d'outil et ne sort jamais vers l'utilisateur.** Ce qu'il désigne se dit « tes affaires en cours ». **Le mot est ressorti dans une phrase entière une passe après avoir été corrigé, trois fois** : il ne se retire donc pas d'une liste de mots interdits, il se remplace par sa traduction, écrite juste à côté de lui. **Et depuis la v2.7.0 il ne figure plus nulle part dans les fiches**, ni dans une `description`, ni dans un titre de section, ni dans une phrase de travail : il n'y reste que dans cette règle qui le nomme pour l'interdire, et dans `Kanban Pipeline`, qui est un nom d'écran NoCoDB et pas un mot de vocabulaire. **Une interdiction est innocente, un modèle est coupable** : les huit fiches qui portaient la règle sans le modèle ne l'ont jamais dit.
- **On tutoie l'utilisateur, dans les dix compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Ce qu'on demande et ce qu'on restitue n'obéissent pas à la même règle de forme, et c'est la question qui décide, jamais la compétence.**
  - **Ce qu'on demande : trois questions au maximum, et numérotées dès qu'il y en a deux.** Une question seule reste dans la phrase, sans numéro. Deux ou trois se détachent, chacune sur sa ligne, numérotées, de sorte que l'utilisateur puisse répondre à la 1 et à la 2, n'en traiter qu'une, et **voir laquelle il n'a pas traitée**. Deux questions noyées dans une phrase, il en manque une sans savoir qu'il en a manqué une. Ce qui reste proscrit, c'est la liste de puces interrogatives sans numéro et sans fin : ce n'est pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais.
  - **Ce qu'on restitue se structure** : une liste numérotée pour ce qu'il y a à faire, un tableau quand les lignes ont plus de deux attributs à comparer. Une restitution n'a pas de plafond de trois, elle a la longueur de ce qu'elle rend.
  - **Une puce qui se termine par un point d'interrogation est une question et retombe sous la première règle.** C'est le seul test qui tranche, et il se fait sur le texte écrit, pas sur l'intention.
- **Ce qui n'empêche pas d'écrire se dit sans point d'interrogation, et ne compte donc pas dans les trois.** Un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.
- **Une phrase de l'utilisateur qui supporte deux lectures se rend à l'utilisateur, avec les deux lectures nommées, et la base ne bouge pas.** Pas « je pense que tu veux dire », pas un choix silencieux : les deux lectures écrites côte à côte, et on attend. C'est déjà ce que la compétence fait quand elle attrape un lapsus sur un prénom ; une ambiguïté de sens ne mérite pas moins qu'une ambiguïté d'orthographe.
- **Avant de dire qu'une information manque, la relire.** « Cette boîte n'a jamais été classée », « je n'ai pas de montant », « rien n'est noté là-dessus » sont des affirmations sur l'état de la base : elles se disent après un appel, jamais depuis le fil de la conversation. **Un classement écrit par la compétence elle-même dans la même fenêtre reste un classement écrit**, et l'affirmer absent est le seul cas où la compétence se contredit à voix haute devant l'utilisateur.

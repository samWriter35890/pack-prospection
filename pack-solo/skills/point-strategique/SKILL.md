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
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Échéance", "description": "asc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Échéance asc"` est refusée.
- **Filtrer et compter côté requête**, jamais en rapatriant la table pour compter soi-même.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.
- **`countRecords` peut manquer, et son repli s'écrit ici plutôt que de s'improviser.** Les appels de comptage ci-dessous le nomment, et il a déjà été annoncé indisponible en séance. **S'il manque, le repli est `aggregate` avec `count_filled` sur un champ toujours rempli, et sur son identifiant de colonne, jamais son titre** : c'est le seul appel du connecteur qui rend `{}` sans erreur, donc le seul où un repli mal écrit rend un zéro crédible au lieu de planter. Le repli se prend **en silence** : l'utilisateur n'a pas à savoir quel outil a servi.

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

## Les quatre repères de qualification

Quatre champs disent ce qui mérite le temps de l'utilisateur. Sur l'organisation : `Correspondance cible`, cœur de cible, périphérie, hors cible ou à qualifier, et `Pourquoi eux`, pourquoi cette entreprise est dans la base, en une ligne. Sur le contact : `Rôle dans la décision`, décideur, prescripteur, utilisateur, relais ou inconnu, et `Priorité`, haute, moyenne, basse ou en veille.

- **On juge la pertinence de l'affaire, jamais la personne.** `Correspondance cible` juge une **entreprise** contre le champ `À qui je le vends` du contexte. `Rôle dans la décision` décrit une **position dans un achat**, celle que l'intéressé assume lui-même en réunion, jamais un trait de caractère. `Priorité` dit dans quel ordre l'utilisateur rappelle, pas ce que les gens valent. Le test qui tranche : ne rien écrire qu'on ne serait pas prêt à lui lire s'il demandait à voir sa fiche.
- **Rien ne s'écrit sans un mot de l'utilisateur.** Ces quatre champs se **proposent**, ils ne se posent jamais d'office, et une proposition non confirmée ne s'écrit pas. Un rôle déduit d'une fonction est une inférence, pas un fait, et elle a le défaut de toutes les inférences : elle sonne juste. Ce qui est obligatoire, c'est de proposer quand on a de quoi le faire, pas d'écrire.
- **Vide et « à qualifier » ne disent pas la même chose.** Vide veut dire qu'on n'a jamais demandé. `À qualifier` et `Inconnu` veulent dire qu'on a demandé et que ce n'est pas tranché. **Ne jamais reposer une question déjà posée** : un champ qui porte l'une de ces deux valeurs se laisse tranquille jusqu'à ce que l'utilisateur en dise quelque chose de neuf.
- **`Pourquoi eux` porte l'histoire, pas l'état du moment.** Il dit d'abord **pourquoi cette entreprise est entrée dans la base** : ce qui, chez eux, appelle l'offre. Le jour où elle en sort, où elle passe hors cible, **la raison de la sortie s'ajoute à la ligne d'entrée, elle ne la remplace pas** : « trois devis par semaine tapés à la main, veulent industrialiser », puis « écartés le 20 août, ce qu'ils cherchent est trop loin de ce que je fais ». Une entreprise mise de côté sans raison écrite est un travail qu'on refera dans six mois, faute de se souvenir pourquoi on avait dit non. Le test du droit d'accès vaut sur la ligne de sortie comme sur celle d'entrée : une raison d'affaires s'écrit, un jugement sur les gens ne s'écrit pas.
- **Ces mots se disent en français, jamais en nom de champ.** « Une boîte qui est vraiment ta cible », « c'est lui qui décide », « celle-là, tu la mets de côté ». Jamais « je passe la correspondance cible à cœur de cible ». C'est la règle du vocabulaire de la base appliquée à ces quatre champs : l'utilisateur a des clients et des priorités, pas des colonnes.
- **Ne jamais trier sur `Priorité`.** NoCoDB trie un single select par ordre alphabétique de la valeur : le tri donnerait basse, en veille, haute, moyenne. On **filtre** sur ce champ, on ne trie pas.
- **Un nom d'entreprise sous-entendu ne se résout jamais tout seul avant une écriture.** Quand une phrase désigne une entreprise par « l'entreprise », « la boîte », « chez eux », « leur », et que **deux organisations au moins** sont candidates dans la phrase ou dans la conversation, on **s'arrête et on demande laquelle** avant tout appel d'écriture. La personne nommée dans la phrase est le candidat le plus probable, jamais le sujet du tour précédent, mais la probabilité ne suffit pas ici : une organisation reclassée à tort porte une raison écrite qui rend le classement crédible, et personne ne rouvrira la fiche. « Après discussion avec Nicolas Betton, l'entreprise a déjà un CRM » parle de l'entreprise **de Nicolas Betton**, pas de celle dont on parlait il y a deux phrases. Dans le doute, une question de cinq mots : « chez Perfhomme, c'est ça ? »

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

> **La position dans la fenêtre est un chiffre comme un autre : elle se calcule sur `Début` et `Échéance` lus dans l'enregistrement, jamais sur une impression.** Un objectif ouvert hier est au jour 2, même s'il traîne dans la conversation depuis une semaine. Dire « on est à 5 jours » d'une fenêtre qui a commencé avant-hier fait douter de tout le reste du point, y compris des chiffres qui, eux, sortent d'un appel. Dans le doute, donner les deux bornes en clair et laisser l'utilisateur situer : « du 17 août au 31 décembre, on en est au deuxième jour ».

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

> **« Propositions en cours » est un stock, pas un flux, et cela se dit à l'utilisateur.** La base ne garde **aucun historique d'étape** : une affaire passée de Proposition à Gagnée n'a laissé aucune trace de son passage. On sait donc combien d'affaires sont en proposition **aujourd'hui**, jamais combien en ont été émises dans le mois. Formuler au présent, toujours : « tu as 3 propositions en cours », jamais « tu as fait 3 propositions ce mois-ci ». La seconde phrase serait une invention, et elle passerait inaperçue.

**Sur un objectif de chiffre signé, compter aussi ce que la mesure ne verra jamais :**

```
countRecords  Opportunités  where=(Étape,in,Identifiée,Contactée,RDV,Proposition)~and(Clôture prévue,blank)
```

`Chiffre signé` filtre sur `Clôture prévue` : une affaire sans cette date apportera **0 €** à la cible, même signée, et rien ne le dira. **Le signaler quand il y en a**, en une ligne, et poursuivre : « deux affaires en cours n'ont pas de date de clôture prévue, elles ne compteront dans aucun bilan tant qu'elle manque. » La date se pose dans `creer-opportunite`, pas ici.

### L'indicateur mesure large, l'objectif dit étroit

Les sept indicateurs comptent des enregistrements, ils ne lisent pas le texte de l'objectif. Quand le champ `Objectif` nomme un produit, un segment ou un type de client que la base ne sait pas distinguer, « Signer 3 **Packs Solo** », « 4 rendez-vous **de découverte** », **le dire une fois, en une phrase, et poursuivre** : « je compte tout le chiffre signé, la base ne distingue pas les Packs Solo du reste ».

**Ne jamais présenter une affaire nommée comme comptant dans un objectif que l'indicateur ne sait pas filtrer.** Citer une affaire, c'est affirmer qu'elle entre dans la cible. Sur un objectif large, on annonce le total et la cible, sans désigner qui y contribue.

**Ne pas corriger l'objectif de l'utilisateur pour autant.** Ce n'est pas la cible qui est mal posée, c'est la mesure qui est plus grossière qu'elle : le garde-fou « ne pas modifier `Objectif` ni `Cible` » tient. Le dire est la seule réponse honnête.

---

## Le cas de la table vide, qui est le cas important

**Le risque de cette compétence n'est pas de ne pas se déclencher. C'est de se déclencher et de devenir `tableau-de-bord`.**

Appelée sans aucun objectif en base, elle sera tentée de rendre service en récitant l'activité du mois. Elle produirait alors un bilan que personne n'a demandé, sous un nom qui laisse croire qu'il est mesuré contre quelque chose. C'est la faute la plus grave possible ici, parce qu'elle ne se voit pas : les chiffres sont justes, c'est leur sens qui est faux.

La réponse juste tient en trois temps :

1. **Le dire.** « Tu ne m'as pas donné de cible, je ne peux donc pas te dire si tu es dans les clous. »
2. **Proposer d'en poser une, en une question et pas quatre.** Demander seulement ce qu'il veut suivre et à quel niveau : « qu'est-ce que tu veux viser, et combien ? ». `Indicateur` et `Période` se déduisent de sa réponse et se font **confirmer** ensuite, la liste des sept indicateurs montrée seulement s'il faut trancher, comme le dit « Poser ou clore un objectif ». **Ne jamais réciter les quatre champs de la table**, « l'objectif, l'indicateur, la cible et la période » : c'est le formulaire NoCoDB déplacé dans la conversation, et c'est ce que le pack se vend à éviter.
3. **Proposer l'autre porte** : « si tu veux seulement voir ton activité du mois, je peux te faire le point », et passer la main à `tableau-de-bord`.

**Jamais combler.** Un objectif absent se dit, il ne se déduit pas de l'activité passée, il ne se remplace pas par une valeur ronde plausible.

Même règle sur un objectif présent mais incomplet : une `Cible` vide sur un indicateur mesurable est une saisie inachevée, à signaler et à faire compléter, jamais à estimer.

## L'objectif qualitatif

`Autre (non mesuré)` porte un objectif qui n'a volontairement pas de chiffre : « être identifié comme la référence sur mon secteur ». Sa `Cible` est vide, et c'est normal.

**Le restituer en toutes lettres, et ne jamais le chiffrer.** Ne pas lui inventer un pourcentage d'avancement, ne pas lui trouver un indicateur de remplacement, ne pas dire qu'il est « en bonne voie » sur la foi de l'activité. Le rappeler à l'utilisateur suffit : c'est un objectif qu'il a posé pour s'en souvenir, pas pour qu'on le mesure.

Ce qui est permis, et utile : citer un fait de la base qui s'y rapporte, sans en tirer de score. « Sur ton objectif de notoriété, rien de mesurable par nature. Je note quand même deux recommandations reçues ce mois-ci. »

---

## Ce qu'il reste dans le vivier, et ce qu'on n'en sait pas

C'est la lecture qui donne sa phrase au point stratégique : « tu vises 4 rendez-vous, il te reste 12 contacts cœur de cible que tu n'as jamais contactés ». Un écart tout seul dit qu'on est en retard, un écart plus un vivier dit **quoi faire ce matin**.

**Elle ne se fait que sur un objectif de prospection en retard**, c'est-à-dire `Rendez-vous`, `Échanges sortants` ou `Nouveaux contacts` sous la cible. Sur un objectif de chiffre signé ou sur un objectif tenu, elle n'apporte rien et allonge la restitution.

### Deux appels, parce qu'un filtre ne traverse pas un lien

La correspondance cible vit sur l'organisation, le statut de relation vit sur le contact. On lit donc les entreprises d'abord, puis les personnes qui en dépendent :

```
queryRecords  Organisations  where=(Correspondance cible,eq,Cœur de cible)
                             fields=["Nom"]  limit=50
```

Puis, avec les noms obtenus, sur le libellé affiché du lien :

```
queryRecords  Contacts  where=(Organisation,in,Odyssée 29,Super Super,CLR Location)~and(Statut relation,eq,Nouveau)
                        fields=["Nom complet","Fonction"]  limit=25
```

**Trois bornes, toutes les trois nécessaires.** Cinquante organisations au maximum au premier appel, parce qu'une liste de deux cents noms dans un filtre devient une URL qui casse. Vingt-cinq contacts au second, parce que la phrase annonce un nombre et cite trois noms, pas vingt-cinq. Et si le premier appel rend plus de cinquante entreprises, le dire : « je regarde sur les cinquante premières », plutôt que d'annoncer un total faux.

**`Périphérie` ne se mélange pas à `Cœur de cible` dans le même chiffre.** Si le cœur de cible est vide et que la périphérie ne l'est pas, faire un second passage et le nommer pour ce qu'il est : « plus rien en cœur de cible, mais 9 contacts en périphérie ».

### Nommer l'angle mort plutôt que de le combler

Sur une base jeune, la plupart des entreprises n'ont pas encore été jugées, et un comptage sur le seul cœur de cible dirait « 2 » là où la vérité est « 2, sur 40 dont 35 n'ont jamais été regardées ». **Un chiffre partiel présenté comme complet est un chiffre faux.**

Compter donc ce qui n'est pas tranché, en un appel :

```
countRecords  Organisations  where=(Correspondance cible,blank)
```

Et le dire en une ligne, une seule fois, sans le répéter à chaque objectif : « à noter, 35 entreprises sur 40 n'ont jamais été classées, donc ce chiffre-là ne voit qu'un bout de ton vivier ».

> **La tranche est la seconde moitié du geste, elle ne se sépare pas de la première.** Nommer l'angle mort sans proposer par où le réduire laisse l'utilisateur devant un chiffre gênant et rien à en faire, ce qui est exactement l'effet que ce paragraphe existe pour éviter. **Les deux phrases partent ensemble, dans la même réponse** : le constat, puis la proposition. Elle ne se garde pas pour la conclusion, où elle sauterait, et elle ne compte pas dans la recommandation unique de fin, qui porte sur le commercial et non sur le rangement.

**Puis proposer une tranche, et une seule.** Jamais « il faudrait qualifier tes 35 entreprises », qui est une corvée que personne n'ouvre. Ce qui marche est un lot que l'utilisateur boucle en trois minutes, choisi sur ce qui bouge : les entreprises entrées le mois dernier, ou celles qui portent un contact déjà en discussion.

> Si tu veux, on prend les huit boîtes arrivées ce mois-ci et on les trie en deux minutes : à chaque fois, tu me dis en un mot ce qui te les fait garder.

**Là aussi, on demande *en quoi* et jamais *si*.** « C'est ta cible ou c'est à côté ? » a une réponse par défaut et ne rend qu'un classement ; la question ouverte rend le classement **et** sa raison, pour `Pourquoi eux`, dans le même mot. Un mot par boîte suffit, et rien ne se réclame.

L'utilisateur accepte, et **c'est `creer-contact` qui porte l'écriture**, sur les mots qu'il donne, entreprise par entreprise. Cette compétence-ci ne se met pas à écrire `Correspondance cible` : elle compare et elle propose.

**Le silence clôt le sujet.** Si l'utilisateur ne relève pas, ne pas y revenir dans la même séance, et ne pas rouvrir la proposition au point stratégique suivant si elle a déjà été déclinée. Un point stratégique qui réclame chaque mois le même rangement devient un reproche mensuel, et le client cesse de le demander.

---

## Restituer

Un objectif par bloc, court. Pour chacun :

1. **L'objectif dans ses mots à lui**, repris du champ `Objectif`, pas reformulé.
2. **Les deux nombres**, cible et mesure, et l'écart. « 2 rendez-vous sur les 4 visés. »
3. **Où l'on en est dans la période.** « À mi-parcours du mois. » C'est ce qui fait la différence entre un constat et un jugement.
4. **Le verdict, prudent et explicite.** Dans les clous, en retard, atteint, hors d'atteinte. Un seul mot, pas un paragraphe.

Puis, une fois pour l'ensemble : **une recommandation actionnable, une seule**, et le skill qui la porte. « Le plus rentable : relancer les deux propositions en attente. Je peux préparer les mails. »

> **Une recommandation est une affirmation sur l'état de la base : elle obéit aux mêmes règles qu'un chiffre.** Toute affaire, tâche ou personne **nommée** dans la conclusion se relit **par un appel, dans le tour où la phrase s'écrit**. Jamais depuis un état lu plus tôt dans la conversation, même de quelques minutes : entre-temps, la même session a pu écrire. La conclusion est la seule partie de ce skill qui ne sorte d'aucun appel, donc la seule qui puisse mentir pendant que les chiffres, eux, restent justes.
>
> Le cas réel, le 19 août 2026 : « chiffrer et dater la clôture prévue des deux affaires en RDV » a été conseillé sur une affaire qui portait son montant et sa date depuis vingt-six minutes, écrits dans la même session. Un client qui suit le conseil refait un travail déjà fait, un client qui vérifie cesse de lire la conclusion.

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
- **Un comptage sur la qualification s'annonce avec ce qu'il ne voit pas.** Tant que des entreprises restent non classées, « 12 contacts cœur de cible » est un sous-total, pas un total. Le dire une fois, et donner le nombre d'entreprises jamais jugées dans la même phrase.
- **Ne jamais trier ni classer des personnes dans une restitution.** Cette compétence compte des contacts et nomme trois entreprises, elle ne produit jamais un palmarès de gens à rappeler par ordre de valeur. `Priorité` sert à **filtrer** un vivier, jamais à ranger des personnes les unes après les autres, et le tri sur ce champ est faux par construction, voir les quatre repères ci-dessus.
- **Ne jamais présenter un chiffre calculé de tête.** Tout nombre annoncé sort d'un appel. En cas de doute, recouper par un `countRecords` plutôt qu'arrondir.
- **Une recommandation se relit avant de s'écrire, exactement comme un chiffre se recompte.** Elle nomme des enregistrements, donc elle affirme quelque chose de leur état, donc elle se vérifie par un appel dans le tour même. Une règle qui ne parle que des chiffres laisse passer les conseils, et c'est le conseil que l'utilisateur suit.
- **Une date se dit telle qu'elle est en base.** « hier », « la semaine dernière », « il y a un mois » sont des calculs, et ils tombent faux exactement comme un total : les poser contre la date du jour avant de les écrire, ou citer la date. Une date fausse dans une phrase juste passe inaperçue.
- **L'indicateur mesure plus large que l'objectif ne le dit**, dès que celui-ci nomme un produit ou un segment. Le dire une fois, et ne jamais citer une affaire comme comptant dans une cible que l'indicateur ne sait pas filtrer.
- **Un seul comptage par indicateur**, celui du tableau. Deux mesures différentes du même objectif d'un mois sur l'autre valent moins que pas de mesure du tout.
- **`Propositions en cours` se dit au présent.** C'est un stock : la base ne porte pas d'historique d'étape.
- **Ne pas modifier `Objectif` ni `Cible`** sans que l'utilisateur les redonne lui-même. Corriger une cible pour qu'elle colle au réel vide la compétence de tout son sens.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître.
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

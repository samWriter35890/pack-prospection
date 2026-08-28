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
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
- **Les caractères accentués s'écrivent littéralement dans un filtre, jamais échappés.** `(Prénom,like,%fabrice%)` fonctionne. Sur un **nom de colonne**, un échappement de la forme `\uXXXX` échoue bruyamment, `Column alias 'Pr\u00e9nom' not found.`, et se corrige donc tout seul. Sur une **valeur**, il rend `"records": []` **sans aucune erreur** : `(Nom,like,%g\u00e9rard%)` ne trouve pas Gérard et ne le dit pas, ce qui est indiscernable d'une absence. C'est le second échec silencieux du connecteur après `aggregate`, et le plus facile à déclencher, puisque la plupart des noms de personnes et d'entreprises français portent un accent. **Une recherche qui rend zéro résultat sur un terme accentué se rejoue une fois, en ASCII strict, avant de conclure à l'absence.** Un doublon créé sur cette base est indétectable jusqu'au jour où quelqu'un rouvre la table.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

---

## Les quatre repères de qualification

Quatre champs disent ce qui mérite le temps de l'utilisateur. Sur l'organisation : `Correspondance cible`, cœur de cible, périphérie, hors cible ou à qualifier, et `Pourquoi eux`, pourquoi cette entreprise est dans la base, en une ligne. Sur le contact : `Rôle dans la décision`, décideur, prescripteur, utilisateur, relais ou inconnu, et `Priorité`, haute, moyenne, basse ou en veille.

- **On juge la pertinence de l'affaire, jamais la personne.** `Correspondance cible` juge une **entreprise** contre le champ `À qui je le vends` du contexte. `Rôle dans la décision` décrit une **position dans un achat**, celle que l'intéressé assume lui-même en réunion, jamais un trait de caractère. `Priorité` dit dans quel ordre l'utilisateur rappelle, pas ce que les gens valent. Le test qui tranche : ne rien écrire qu'on ne serait pas prêt à lui lire s'il demandait à voir sa fiche.
- **Rien ne s'écrit sans un mot de l'utilisateur.** Ces quatre champs se **proposent**, ils ne se posent jamais d'office, et une proposition non confirmée ne s'écrit pas. Un rôle déduit d'une fonction est une inférence, pas un fait, et elle a le défaut de toutes les inférences : elle sonne juste. Ce qui est obligatoire, c'est de proposer quand on a de quoi le faire, pas d'écrire.
- **Vide et « à qualifier » ne disent pas la même chose.** Vide veut dire qu'on n'a jamais demandé. `À qualifier` et `Inconnu` veulent dire qu'on a demandé et que ce n'est pas tranché. **Ne jamais reposer une question déjà posée** : un champ qui porte l'une de ces deux valeurs se laisse tranquille jusqu'à ce que l'utilisateur en dise quelque chose de neuf.
- **La question de la cible nomme les trois rangements en français, et demande la raison dans la même phrase.** « Frères Boyer, tu les mets où : au cœur de ce que tu cherches, en périphérie, ou plutôt de côté ? Et qu'est-ce qui te fait dire ça ? » Une question qui ne demande que le motif, « qu'est-ce qui te les fait mettre là, chez eux », **ne se comprend pas**, « là » n'ayant aucun référent pour qui ne connaît pas le champ, et surtout **elle ne rapporte pas le rangement** : il faudrait alors le déduire d'une réponse en texte libre, et une classe déduite d'un motif favorable est une invention que personne ne peut vérifier. **Sans rangement explicite dans la réponse de l'utilisateur, rien ne s'écrit dans `Correspondance cible`** : la raison seule remplit `Pourquoi eux` et la correspondance reste vide, ce qui est exactement ce que « vide veut dire jamais demandé » signifie.
- **`Pourquoi eux` porte l'histoire, pas l'état du moment.** Il dit d'abord **pourquoi cette entreprise est entrée dans la base** : ce qui, chez eux, appelle l'offre. Le jour où elle en sort, où elle passe hors cible, **la raison de la sortie s'ajoute à la ligne d'entrée, elle ne la remplace pas** : « trois devis par semaine tapés à la main, veulent industrialiser », puis « écartés le 20 août, ce qu'ils cherchent est trop loin de ce que je fais ». Une entreprise mise de côté sans raison écrite est un travail qu'on refera dans six mois, faute de se souvenir pourquoi on avait dit non. Le test du droit d'accès vaut sur la ligne de sortie comme sur celle d'entrée : une raison d'affaires s'écrit, un jugement sur les gens ne s'écrit pas.
- **Ces mots se disent en français, jamais en nom de champ.** « Une boîte qui est vraiment ta cible », « c'est lui qui décide », « celle-là, tu la mets de côté ». Jamais « je passe la correspondance cible à cœur de cible ». C'est la règle du vocabulaire de la base appliquée à ces quatre champs : l'utilisateur a des clients et des priorités, pas des colonnes.
- **Ne jamais trier sur `Priorité`.** NoCoDB trie un single select par ordre alphabétique de la valeur : le tri donnerait basse, en veille, haute, moyenne. On **filtre** sur ce champ, on ne trie pas.
- **Un nom d'entreprise sous-entendu ne se résout jamais tout seul avant une écriture.** Quand une phrase désigne une entreprise par « l'entreprise », « la boîte », « chez eux », « leur », et que **deux organisations au moins** sont candidates dans la phrase ou dans la conversation, on **s'arrête et on demande laquelle** avant tout appel d'écriture. La personne nommée dans la phrase est le candidat le plus probable, jamais le sujet du tour précédent, mais la probabilité ne suffit pas ici : une organisation reclassée à tort porte une raison écrite qui rend le classement crédible, et personne ne rouvrira la fiche. « Après discussion avec Nicolas Betton, l'entreprise a déjà un CRM » parle de l'entreprise **de Nicolas Betton**, pas de celle dont on parlait il y a deux phrases. Dans le doute, une question de cinq mots : « chez Perfhomme, c'est ça ? »

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
| `Correspondance cible` | Cœur de cible · Périphérie · Hors cible · À qualifier |

`Secteur` est une liste **adaptée à chaque client** : lire les valeurs disponibles avec `getTableSchema` avant d'écrire, ne pas en inventer une.

#### Sur une organisation qu'on vient de créer, demander si c'est une cible

C'est la seule question de qualification de ce skill, et elle se pose **une fois par entreprise, jamais par personne**. Une organisation déjà en base et déjà renseignée ne se redemande pas, et deux contacts de la même boîte ne valent qu'une question.

**Ce qu'on a sous la main ne suffit presque jamais à trancher seul.** L'organisation vient d'être créée avec son nom, parfois sa ville, rarement son secteur ou sa taille : il n'y a pas de quoi la comparer sérieusement à `À qui je le vends`. Donc **on demande la conclusion plutôt que les ingrédients**, en une question à laquelle un dirigeant répond en une phrase :

> Super Super, tu les mets où : au cœur de ce que tu cherches, en périphérie, ou plutôt de côté ? Et qu'est-ce qui te fait dire ça ?

**Le rangement et la raison, dans la même phrase, jamais l'un sans l'autre.** Les deux moitiés se sont ratées chacune leur tour, et chaque fois pour une raison différente. Demander seulement *si*, « c'est le genre de boîte que tu cherches ? », a une réponse par défaut, elle est « oui », et rend un mot là où `Pourquoi eux` attend une phrase. Demander seulement *en quoi*, « qu'est-ce qui te les fait mettre là, chez eux ? », **ne se comprend pas** et **ne rapporte aucun rangement** : le 25 août 2026 la classe a dû être déduite d'un texte libre quatre fois, et la cinquième elle n'a pas été écrite du tout, tout en étant annoncée comme écrite. La question qui nomme les trois rangements **et** demande la raison remplit les deux champs d'un coup, sans coûter un tour de plus, et laisse une trace vérifiable de ce que l'utilisateur a réellement dit.

**Sans rangement dans la réponse, `Correspondance cible` reste vide.** Une raison seule s'écrit dans `Pourquoi eux` et rien d'autre ne part. Un motif favorable n'est pas un classement, et le déduire produit une valeur crédible que personne ne rouvrira jamais.

**Une organisation dont `Correspondance cible` est vide se qualifie à la première occasion, quelle que soit la compétence et quel que soit l'âge de la fiche.** La question nomme les trois rangements et demande la raison dans la même phrase, comme ci-dessus. Une organisation déjà classée ne se requalifie que sur contradiction. **Et l'ancienneté de la fiche n'est jamais une raison de ne pas demander** : une organisation en base depuis trois semaines sans classement n'a pas été classée, elle a été oubliée. Le champ vide n'est pas un état stable, c'est une question jamais posée.

**Et elle garde sa sortie.** Si la réponse écarte l'entreprise, « en fait rien, je me suis trompé, ils sont trop gros », c'est le cas du « à côté » traité plus bas, et il s'écrit exactement pareil.

Quand le nom, la ville ou la fonction du contact donnent vraiment un indice, **proposer** au lieu de demander à blanc, et laisser corriger : « une boîte de location de matériel à Rennes, ça tombe en plein dans ce que tu vises, je le note comme ça ? ». La proposition est une aide, pas une décision : sans réponse, rien ne s'écrit.

Deux réponses closent la question, et une seule est un « oui ». Un « je ne sais pas encore » s'écrit `À qualifier`, ce qui n'est pas la même chose que de laisser vide : cela veut dire que la question a été posée, et personne ne la reposera.

**Un « à côté » s'écrit avec sa raison, et c'est la seule exception à la règle du dessous.** Quand la réponse écarte l'entreprise, la raison donnée part dans `Pourquoi eux`, à la suite de ce qui s'y trouve déjà et sans rien effacer : « écartés le 20 août, ce qu'ils cherchent est trop loin de ce que je fais ». Si la réponse est un « non » sec, demander **une fois** de quoi il s'agit, en une phrase, « qu'est-ce qui te fait dire ça, en deux mots ? », et ne pas insister. Une entreprise mise de côté sans raison écrite se rejuge de zéro dans six mois. Le test du droit d'accès reste le même : une raison d'affaires s'écrit, un jugement sur les gens ne s'écrit pas.

**`Pourquoi eux` ne se demande jamais pour lui-même ici, il se ramasse.** L'argument d'affaires complet, ce qui chez eux appelle l'offre, se sait après avoir parlé aux gens, et il s'écrit dans `enregistrer-echange` ou `creer-opportunite`. Mais la question de cible ci-dessus en rapporte déjà la première ligne, et **cette ligne s'écrit** : « ils louent du matériel et gèrent tout sur papier » vaut mieux que rien, et se complétera plus tard. Ce qui est interdit, c'est une **deuxième** question sur le sujet au moment où on note un nom. Une seule question, deux champs remplis, et on n'y revient pas.

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
  "Rôle dans la décision": "Décideur",
  "Organisation":    {"Id": 7}
}
```

| Champ | Valeurs admises |
|---|---|
| `Statut relation` | Nouveau · À contacter · En discussion · Client · Dormant · Perdu |
| `Source` | LinkedIn · Email · Salon · Réseau · Recommandation · Import Datablist |
| `Rôle dans la décision` | Décideur · Prescripteur · Utilisateur · Relais · Inconnu |

#### `Rôle dans la décision` se propose depuis la fonction, et seulement quand elle le dit

Dans une TPE, la fonction porte la réponse : un gérant, un dirigeant, un fondateur, un associé, un artisan à son compte **décide**. C'est le cas le plus fréquent de cette base, et le taire serait laisser vide un champ dont la réponse est sous les yeux. Alors on le glisse dans la confirmation, sans en faire une question de plus :

> Gérante, donc c'est elle qui décide chez eux, je le note comme ça ?

Partout ailleurs, la fonction ne dit rien de l'achat. « Responsable clientèle », « chargé de mission », « directeur technique » dans une structure de deux cents personnes : on ne sait pas, et on ne devine pas. Deux conduites, selon ce qu'on a :

- **La fonction ne tranche pas, et on n'a rien d'autre** : laisser vide. Le champ se remplira au premier échange, quand la personne aura dit elle-même qui décide.
- **La question a été posée et personne n'a su répondre** : écrire `Inconnu`, qui veut dire « demandé, non tranché », et ne plus la reposer.

`Priorité` ne se demande pas ici. Elle se donne à la sortie d'un échange, pas au moment où on note un nom : c'est `enregistrer-echange` qui l'écrit.

- **`Nom complet` ne s'écrit pas.** C'est une formule, calculée à partir du prénom et du nom. C'est aussi le libellé qui s'affichera partout où le contact est lié.
- **Renseigner `Source`.** C'est ce qui permettra plus tard de mesurer ce qui fonctionne. « Je ne sais plus » est une réponse acceptable, une valeur inventée ne l'est pas.
- `Prochaine relance` : la poser si une échéance est évoquée. C'est ce champ qui fera remonter la personne dans « À relancer ».
- `Notes` : le contexte durable sur la personne. Le récit d'un échange, lui, va dans `enregistrer-echange`.

### 4. Confirmer, et demander les coordonnées dans la même réponse

Une phrase pour dire ce qui a été créé. Si le skill a été appelé depuis `enregistrer-echange`, revenir à l'échange à consigner sans faire répéter l'utilisateur.

**La confirmation porte la question.** Si `Email`, `Téléphone` ou `LinkedIn` sont vides, la demande part **avec** la phrase de confirmation, au même endroit que les points tranchés sans certitude, sous la même forme. Ce n'est pas une étape de plus, c'est une puce de plus. **La question de la cible voyage au même endroit**, quand l'organisation vient d'être créée :

> C'est fait : la fiche de Charlotte Le Bedel est créée, rattachée à Perfhomme Rennes, avec l'échange du rendez-vous d'hier. Je l'ai noté comme un rendez-vous et j'ai fait avancer la relation, corrige-moi si je me trompe.
> Deux choses avant de refermer : Perfhomme, tu les mets où, au cœur de ce que tu cherches, en périphérie, ou plutôt de côté, et qu'est-ce qui te fait dire ça ? Et il me manque ses coordonnées, email, téléphone, profil LinkedIn, donne-moi ce que tu as.

**Trois questions au maximum, numérotées dès qu'il y en a deux, jamais en puces sans numéro.** Ce qui a été tranché sans certitude s'annonce comme un fait corrigeable, dans la phrase de confirmation et sans point d'interrogation : c'est une information, pas une question de plus. Le 25 août 2026, cette étape a rendu trois puces interrogatives puis quatre, et c'est très exactement la forme que le mode lot a appris à éviter. **Jamais deux fois la même question.** Sur un lot de personnes, la question de la cible se pose **par entreprise**, une seule fois pour toutes celles de la même boîte, et à la fin du lot comme les coordonnées. Cinq contacts chez trois entreprises font trois questions, pas cinq, et pas quinze.

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
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre. **Et la règle porte sur le parcours, pas sur le mode d'emploi.** Quand l'utilisateur interroge la construction de sa base, compare deux champs, ou demande pourquoi une valeur plutôt qu'une autre, il pose une question d'outil et attend une réponse d'outil : les noms de champs et les valeurs se disent. **Le basculement est marqué par la question, jamais par la compétence.** Dès le tour suivant qui parle d'une personne ou d'une entreprise, on revient au français ordinaire.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.** **Tout ce qui s'affiche entre deux appels d'outil est une réponse.** Même langue, même vocabulaire, mêmes interdits que la phrase finale : le français, aucun nom de table ni de champ, aucune annonce de ce qui va être appelé. **Si rien n'a besoin d'être dit entre deux écritures, rien ne se dit.**
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Ce qu'on demande et ce qu'on restitue n'obéissent pas à la même règle de forme, et c'est la question qui décide, jamais la compétence.**
  - **Ce qu'on demande : trois questions au maximum, et numérotées dès qu'il y en a deux.** Une question seule reste dans la phrase, sans numéro. Deux ou trois se détachent, chacune sur sa ligne, numérotées, de sorte que l'utilisateur puisse répondre à la 1 et à la 2, n'en traiter qu'une, et **voir laquelle il n'a pas traitée**. Deux questions noyées dans une phrase, il en manque une sans savoir qu'il en a manqué une. Ce qui reste proscrit, c'est la liste de puces interrogatives sans numéro et sans fin : ce n'est pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais.
  - **Ce qu'on restitue se structure** : une liste numérotée pour ce qu'il y a à faire, un tableau quand les lignes ont plus de deux attributs à comparer. Une restitution n'a pas de plafond de trois, elle a la longueur de ce qu'elle rend.
  - **Une puce qui se termine par un point d'interrogation est une question et retombe sous la première règle.** C'est le seul test qui tranche, et il se fait sur le texte écrit, pas sur l'intention.
- **Ce qui n'empêche pas d'écrire se dit sans point d'interrogation, et ne compte donc pas dans les trois.** Un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.
- **Une organisation créée sans qu'on demande si c'est une cible est une organisation qu'on ne qualifiera jamais.** Personne ne rouvre une fiche pour ça, et le jour où l'utilisateur demande « qui viser cette semaine », elle manquera au comptage sans qu'aucun chiffre ne bouge. La question part avec la confirmation, ou elle ne part pas.
- **Ne jamais requalifier une organisation qui existait déjà.** Elle a été jugée une fois, par l'utilisateur, peut-être il y a trois mois : une fiche rattachée n'est pas une occasion de rejuger l'entreprise. Le seul cas qui rouvre la question, c'est l'utilisateur qui en parle de lui-même.
- **Un champ vide se demande, il ne s'abandonne pas.** Créer sans email est normal, conclure sans avoir demandé l'email ne l'est pas. Et la demande vit dans la phrase de confirmation, jamais dans un « on verra plus tard ».

---
name: accroche-linkedin
description: Préparer un message d'accroche personnalisé pour une demande de connexion ou un premier message LinkedIn. À utiliser quand l'utilisateur veut approcher quelqu'un sur LinkedIn ou prépare une session de prospection. Produit le texte, ne l'envoie pas.
---

# Préparer une accroche LinkedIn

Produit le texte d'une demande de connexion, ou d'un premier message une fois la connexion acceptée. **Le skill ne clique jamais.** L'utilisateur copie, colle, envoie.

C'est une position produit assumée : aucun envoi automatisé d'invitations dans le socle. Un compte LinkedIn automatisé se fait restreindre, et c'est l'outil de travail du client.

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

## Le contexte du client, lu une fois par session

Avant tout, lire la table `Contexte`. Elle porte **un seul enregistrement** : qui est l'utilisateur, ce qu'il vend, à qui, ce qui le distingue, ce qui coince, comment il parle, comment il signe, où l'on réserve un rendez-vous avec lui, et ce qu'il ne fait pas.

```
queryRecords  Contexte  pageSize=1
              fields=["Entreprise", "Qui je suis", "Ce que je vends", "À qui je le vends",
                      "Ce qui me distingue", "Ce qui coince", "Comment je parle",
                      "Signature", "Lien de réservation", "Ce que je ne fais pas"]
```

**Une fois par session, jamais une fois par appel.** Ce contexte est stable : il se remplit à la mise en main et se revoit une fois par an. S'il a déjà été lu dans la conversation, le réutiliser tel quel sans rappeler la base. **Sur un lot de douze accroches, il se lit une fois pour les douze.**

**Lire les dix champs, même ceux dont ce skill n'a pas l'usage.** C'est délibéré : la lecture sert toute la session, et les autres skills s'en serviront ensuite sans repayer l'appel.

**Si la table est vide ou l'enregistrement absent :** le dire en une phrase, continuer quand même, et signaler que le texte sera générique tant que le contexte n'est pas rempli. **Ne jamais deviner** ce que l'utilisateur vend ni comment il signe. Un contexte inventé produit un texte qui sonne juste et qui est faux, ce qui est le pire des deux cas.

**`Signature` se recopie, elle ne se réécrit pas.**

**`Ce que je ne fais pas` est un interdit, pas une indication.** Rien de ce qui y figure ne se propose, ne se promet ni ne se sous-entend dans un texte destiné à un tiers.

Ce que ce skill en fait, lui : **`Qui je suis` fournit la ligne de présentation, et `Ce qui me distingue` la raison d'être crédible.** Sur 300 caractères, ce sont les deux seuls champs qui séparent une invitation qui se lit d'une invitation qui se supprime. **`À qui je le vends` sert à vérifier que la personne approchée est bien une cible** : si elle n'y ressemble pas, le dire à l'utilisateur avant d'écrire, il a peut-être une raison, et il vaut mieux qu'il la donne.

**`Lien de réservation` se recopie en clair, ou ne se remplace par rien.** C'est la règle de `Signature`, appliquée au rendez-vous. Dès qu'un texte propose de se voir ou de se parler, le lien y figure **tel quel**, en toutes lettres, jamais derrière un « je vous envoie mon lien ». S'il est vide, proposer l'échange **sans en inventer les modalités** : ni café, ni visio, ni créneau, ni lien fabriqué. Un lieu de rencontre inventé est la partie du texte que l'utilisateur devra réécrire à la main, à chaque fois. Sur une note d'invitation, le champ ne sert pas : elle ne demande pas de rendez-vous, voir l'étape 4.

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

### 1. Retrouver la personne, si elle est en base

```
queryRecords  Contacts  where=(Nom complet,like,%le goff%)
```

Ce qui sert à personnaliser : fonction, organisation, `Notes`, `Rôle dans la décision`, et un éventuel échange antérieur. Sur l'organisation, `Pourquoi eux` vaut de l'or : c'est l'argument d'affaires déjà entendu de la bouche de quelqu'un, et il fait un bien meilleur point d'accroche qu'un post trouvé au hasard.

Si la personne n'est pas en base, ce n'est pas bloquant : l'accroche se prépare à partir de ce que l'utilisateur en dit ou de ce qu'il colle. **Ne pas créer la fiche à ce stade** : on ne remplit la base qu'avec les gens avec qui on a effectivement un lien. Elle se crée plus tard, à deux moments : **quand l'utilisateur dit que le message est parti**, étape 6 ci-dessous, et à l'acceptation, par `import-capture-linkedin`. Un message envoyé est un lien, une invitation préparée n'en est pas un.

#### Si un profil est transmis et que la fiche existe déjà, corriger son identité

Le cas est fréquent, parce que l'ordre réel des choses l'impose : la fiche se crée souvent **avant** d'avoir vu le profil, donc avec un nom entendu au téléphone ou lu dans un mail, donc parfois faux.

**Dès que l'utilisateur transmet la capture du profil, elle fait référence pour l'identité, tant qu'elle n'est pas explicitement contredite.** Corriger `Prénom`, `Nom`, `Fonction` sur le contact et `Nom` sur son organisation par `updateRecords`, puis dire en une phrase ce qui a été corrigé. **Ne pas redemander à l'utilisateur des orthographes qui sont lisibles à l'écran** : il vient de les fournir en transmettant l'image.

Corriger le nom de l'organisation dans l'enregistrement Organisations le corrige **partout**, le lien pointant sur l'enregistrement et non sur son nom. En revanche, si le contact est rattaché à la **mauvaise organisation**, c'est le lien qui devrait changer, et un lien ne se met pas à jour : le signaler plutôt que d'essayer.

**Distinguer les deux avant d'écrire, parce que renommer est destructeur.** « Crédut Mutuel » corrigé en « Crédit Mutuel » est une faute de frappe. « Crédit Mutuel » devenu « Harmonie Mutuelle » est une **autre société**, donc un mauvais lien. Deux tests, dans cet ordre :

1. **L'enregistrement porte-t-il d'autres contacts ?** `queryRecords Contacts where=(Organisation,eq,<nom>)`. S'il en porte, le renommer renomme la société de tout le monde. Ne pas le faire, signaler.
2. **Est-ce la même société, mal écrite ?** Si les deux noms désignent deux entreprises différentes, ce n'est jamais une correction d'orthographe, quel que soit le nombre de lettres communes.

Quand c'est un mauvais lien sur un enregistrement isolé, créé à l'instant pour ce seul contact, le dire à l'utilisateur et proposer le rattrapage : créer la bonne organisation, et refaire la fiche du contact, puisque le lien ne s'écrit qu'à la création.

Ce n'est pas une entorse au cadre RGPD ci-dessous, et il faut savoir pourquoi : nom, fonction et organisation sont précisément les champs que la base a vocation à porter. Corriger une identité fausse n'est pas enrichir une fiche avec du profil, c'est réparer ce qu'elle contient déjà. Le reste du profil, lui, sert au message puis disparaît. Le détail de la manœuvre est dans `import-capture-linkedin`.

### 2. Personnaliser sur du réel

Une accroche ne vaut que par son point d'accroche. Par ordre de force :

1. **Un lien concret** : une connaissance commune, un événement où l'on s'est croisé, une recommandation.
2. **Quelque chose que la personne a publié ou fait** : un post, une annonce, une ouverture, un recrutement.
3. **Un point commun de métier ou de territoire** : même secteur, même bassin, même problème connu.

Si aucun des trois n'est disponible, le dire. Une accroche sans point d'accroche est une accroche générique : elle abîme la réputation de l'expéditeur et il vaut mieux ne pas l'envoyer.

**Un post qui parle d'un ancien employeur se situe avant de servir.** Le fil d'expérience dit lequel des deux postes est le poste actuel, et la date du changement. Un post de **départ** est un excellent point d'accroche, même six mois après. Une **félicitation d'ancienneté** dans une société que la personne a quittée est une bourde. Les deux se ressemblent au premier coup d'œil et ne se distinguent qu'en lisant le fil.

**Le rôle de la personne change l'angle, pas la longueur.** `Rôle dans la décision` dit à qui on parle, et deux angles suffisent :

| Rôle | Ce sur quoi le message ouvre |
|---|---|
| `Décideur` | ce que ça change pour la boîte : du temps repris, un coût, un risque écarté |
| `Prescripteur`, `Utilisateur`, `Relais` | ce que ça change dans leur travail à eux, et de quoi ils pourront parler en interne |
| `Inconnu`, vide | l'angle du décideur, qui est le plus sûr par défaut sur une TPE |

Ne jamais écrire à quelqu'un qu'il n'est pas le décideur, ni lui demander de transmettre à qui décide dans un premier message. Le champ oriente ce qu'on met en avant, il ne se dit pas au destinataire.

Quand un échange réel existe déjà, il prime sur tout le reste : c'est le lien concret du niveau 1, et il n'empêche pas de citer un post, il dispense d'en chercher un.

> **Cadre RGPD, non négociable.** Ce qui est lu sur un profil pour personnaliser le message reste **transitoire** : rien de tout cela n'est stocké en base. La base ne porte que les coordonnées professionnelles que l'utilisateur gère légitimement.

### 3. Choisir le format, avant d'écrire une ligne

Trois situations, et le mot « accroche » employé par l'utilisateur ne les distingue pas. **C'est l'état réel de la relation qui tranche, pas le mot employé.**

| Où en est la relation | Format | Longueur |
|---|---|---|
| Pas encore connectés | Note d'invitation | **300 caractères maximum**, espaces compris |
| Connexion acceptée, jamais parlé | Message direct | 4 à 6 lignes |
| **Déjà en base, avec un échange ou une affaire** | **Demander lequel** | selon la réponse |

Le troisième cas est le piège, et il s'est produit en vrai. Quand la personne a déjà une fiche, un échange consigné et une affaire ouverte, les deux formats restent légitimes : la connexion peut ne pas exister encore, et un mot de suite après un appel, qui montre que le travail est lancé, est un bon message. **Ce qui n'est pas acceptable, c'est de choisir en silence**, parce que les deux formats n'ont ni la même longueur ni les mêmes règles, et que le texte produit ressemble alors aux deux sans être ni l'un ni l'autre.

Une question, deux options, avant d'écrire :

> Tu es déjà connecté avec lui sur LinkedIn, ou c'est encore une invitation à envoyer ? Dans le premier cas je te fais un message de suite après ton appel, dans le second une note d'invitation, plus courte.

**Le plafond de 300 caractères ne s'applique qu'à la note d'invitation.** Ne pas le faire peser sur un message direct, et ne pas non plus produire 315 caractères en les appelant une invitation.

### 4. Écrire

Règles communes :

- **Pas de pitch.** Une invitation ne vend rien. Elle ouvre une relation.
- Dire **qui on est en une ligne**, tirée de `Qui je suis` et resserrée, **pourquoi cette personne précisément**, et rien d'autre. Ne pas réciter `Ce que je vends` dans une invitation : c'est exactement le pitch que la règle précédente interdit.
- **Aucune question fermée** dans une note d'invitation, aucune demande de rendez-vous.
- **Des phrases complètes, sujet et verbe, y compris dans les 300 caractères.** « Volontiers en lien. », « Au plaisir d'échanger. », « Ravi de vous suivre. » sont des formules tronquées : elles font gagner quinze caractères et donnent au message le ton d'un télégramme. Le plafond se tient en coupant une idée, jamais en amputant une phrase. Écrire « Je serais ravi d'échanger avec vous » plutôt que « Volontiers en lien ».
- **Le ton de `Comment je parle`**, tel que l'utilisateur parle. Ce champ règle le ton du texte **vers son destinataire**, tutoiement ou vouvoiement et mots à éviter ; il ne dit rien de la façon dont on parle à l'utilisateur, qui se tutoie dans tous les cas. Pas de ton corporate.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.**
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Une réponse pose une question, deux au maximum, et jamais sous forme de liste à puces.** Tout ce qui manque part bien dans le même tour, une question repoussée n'étant jamais posée, mais **ce qui n'empêche pas d'écrire se dit sans point d'interrogation** : un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. Trois puces interrogatives ne sont pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.
- Pas d'emoji sauf si l'utilisateur en utilise habituellement.

**Compter les caractères d'une note d'invitation, et raccourcir avant de proposer.** Le compte s'annonce avec le texte, sous la forme `287 caractères`. Un texte de 315 caractères a l'air d'aller : LinkedIn le tronque au milieu d'un mot, et cela se voit. Proposer un texte trop long puis annoncer qu'il est trop long ne sert à rien, l'utilisateur l'a déjà copié.

**Un texte, dans un bloc de code. Un lot, dans un artefact.** Le bloc de code garde le texte à l'écran et donne le bouton copier : sur un message unique, il n'y a rien à arbitrer. L'artefact reste le bon support à partir de plusieurs messages. **Jamais en citation** : elle n'offre pas le bouton, et l'utilisateur en est réduit à sélectionner à la souris un texte qui embarque un retour à la ligne de trop.

Le bloc ne contient **que le texte à envoyer** : pas de commentaire, pas de « Objet : », pas le compte de caractères, qui s'annonce dans la phrase au-dessus. Ce qui est dans le bloc est ce qui sera collé dans LinkedIn.

Proposer **une version**, puis ajuster sur retour. Pas un catalogue de trois variantes.

### 5. Préparer un lot, s'il y en a un

Quand l'utilisateur prépare une session de prospection, produire un texte par personne, jamais un modèle à trous : c'est précisément ce que le destinataire repère.

Rappeler les plafonds, une fois, sans moraliser :

- Environ **20 à 25 invitations par jour**, **100 par semaine glissante**. Au-delà, LinkedIn restreint le compte.
- **La note personnalisée est contingentée** sur un compte gratuit, et LinkedIn a déjà changé ce quota plusieurs fois. Si l'utilisateur bute dessus, envoyer l'invitation nue et garder le texte pour le premier message après acceptation.

### 6. Consigner l'envoi, dès que le message est parti

**C'est une écriture, pas une proposition.** Dès que l'utilisateur dit que le message ou l'invitation est parti, que le texte vienne du pack ou qu'il l'ait écrit lui-même, la trace se pose, puis on le dit. Ne pas demander l'autorisation d'écrire ce qu'il vient de demander.

Les formulations à reconnaître, toutes équivalentes : « c'est envoyé », « je l'ai déjà envoyée », « consigne tout cela », « note-le », « garde-le », « c'est parti ». **Un refus du texte proposé n'est pas un refus de consigner** : « non merci, je l'ai déjà envoyée » demande les deux à la fois, on abandonne le texte et on écrit la trace.

1. **Le contact d'abord, s'il n'est pas en base. Et l'organisation avant le contact, sans exception.** Une personne à qui on vient d'écrire a sa place en base, c'est le lien effectif dont parle l'étape 1.

   > **C'est un arrêt, pas une consigne.** Tant que l'organisation de la personne n'existe pas en base, **le contact ne se crée pas** : on s'arrête, on demande « chez qui travaille-t-elle ? », et on attend la réponse. Créer d'abord et rattacher ensuite est impossible, le lien ne s'écrivant qu'à la création : la fiche reste orpheline pour toujours, et il faut ouvrir NoCoDB à la main, ce que le pack se vend précisément à éviter. Sur une session de prospection, l'erreur se répète autant de fois qu'il y a de personnes.
   >
   > **Deux réponses lèvent l'arrêt, pas une seule** : le nom de l'entreprise, ou un « je ne sais pas » explicite de l'utilisateur. Une organisation absente du profil LinkedIn n'est pas un « je ne sais pas » : c'est ce que LinkedIn affiche, pas ce que l'utilisateur sait. Un indépendant qui facture à son nom prend une organisation à son nom.
   >
   > **Pourquoi un arrêt et pas une règle de plus.** Cette règle était déjà écrite ici, en v1.6.0, sous forme de renvoi à `creer-contact`, et elle a cassé pareil le 19 août 2026 : contact 16 créé avec `Organisation: null`. Dans la même session, `creer-contact`, qui en fait un blocage, a tenu sur le chemin voisin. **Une règle qui a échoué une fois ne se réécrit pas plus fort, elle devient un blocage.**

   Le reste se crée selon `creer-contact`, sans en recopier la procédure. **« Selon `creer-contact` » veut dire ses règles comprises, pas seulement son ordre de création.** En particulier sa question de coordonnées, **et sa question de cible sur une organisation qu'on vient de créer**, qui s'attachent l'une comme l'autre à la phrase de confirmation de l'étape 3 ci-dessous. Sur une session de prospection, la question de cible se pose **par entreprise et une seule fois**, groupée à la fin comme celle des coordonnées. Et sur ce chemin-ci, **`LinkedIn` n'est jamais vide** : on vient d'envoyer une invitation sur ce profil, l'URL est sous les yeux, elle se recopie sans qu'il y ait rien à demander. Un contact né d'une invitation LinkedIn sans son adresse LinkedIn est le seul cas de la base où le champ manquant était certain d'exister.

2. **L'échange ensuite.**

```
createRecords  Échanges
{
  "Objet":   "Invitation envoyée",
  "Date":    "2026-08-18",
  "Canal":   "LinkedIn",
  "Sens":    "Sortant",
  "Contact": {"Id": 12}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

`Objet` dit ce qui est parti : `Invitation envoyée` pour une note d'invitation, `Premier message LinkedIn` pour un message direct. La `Date` est celle de l'envoi, le jour même sauf mention contraire de l'utilisateur.

**Puis faire avancer `Statut relation`, dans le même geste.** Un premier message sortant sur un contact `Nouveau` le passe à `À contacter`, une réponse reçue le passe à `En discussion`. C'est une écriture du **chemin normal** : elle ne dépend d'aucune affaire, et elle ne se demande pas.

```
updateRecords  Contacts  id=15  {"Statut relation": "À contacter"}
```

**Faire avancer, jamais reculer** : un contact déjà `En discussion`, `Client` ou `Dormant` n'y redescend pas. La règle complète est dans `enregistrer-echange`, étape 3, elle ne se recopie pas plus loin que ceci. Sans elle, un contact à qui on a écrit hier reste rangé avec ceux qu'on n'a jamais approchés, et le champ ne veut plus rien dire.

Sur un contact créé à l'instant par l'étape précédente, `Statut relation` se pose directement à la création, à `À contacter`, plutôt qu'en un appel de plus.

3. **Le dire en une phrase, en nommant la personne, et demander ce qui manque dans la même phrase.** « C'est noté : Éric Komlan est en base, chez Untel, avec son profil LinkedIn et l'invitation envoyée aujourd'hui. Si tu as son email ou son téléphone, je les ajoute. » Une consignation muette ne vaut pas mieux qu'une consignation absente : l'utilisateur n'a aucun moyen de voir la différence. Et une question reportée à plus tard est une question qui ne sera jamais posée.

**Sur un lot parti d'un coup**, écrire les échanges en un seul appel et rendre compte d'un compte, pas de douze phrases. **Sur une partie du lot seulement**, ne consigner que ce qui est parti, et dire lesquels restent.

### 7. Poser un rappel, si l'utilisateur le veut

Hors la correction d'identité de l'étape 1 et la consignation de l'étape 6, ce skill **n'écrit rien en base**. Sur demande, une seule écriture utile de plus :

```
createRecords  Tâches
{
  "Tâche":     "Envoyer les 12 invitations LinkedIn préparées",
  "Échéance":  "2026-08-11",
  "Priorité":  "Moyenne",
  "Statut":    "À faire"
}
```

| Champ | Valeurs admises |
|---|---|
| `Priorité` | Haute · Moyenne · Basse |
| `Statut` | À faire · En cours · Fait · Annulée |

**Ne pas consigner d'Échange sur des textes seulement préparés** : rien n'est parti, et une trace posée pour un message jamais envoyé pollue durablement le journal. Les deux traces légitimes ont chacune leur moment : l'envoi à l'étape 6, quand l'utilisateur le dit, l'acceptation via `import-capture-linkedin`.

---

## Garde-fous

- **`Priorité` ne se lit pas pour trier une session de prospection, et elle ne s'écrit jamais ici.** Elle sort d'un échange où l'on a parlé à quelqu'un, pas d'un message envoyé. Et le tri sur ce champ est faux par construction, voir les quatre repères ci-dessus : on **filtre**, on ne trie pas.

- **Un nouveau chemin de création hérite des règles du chemin qu'il double, ou il ne le double pas.** L'étape 6 crée des contacts comme `creer-contact` en crée : elle doit donc les créer aussi bien, coordonnées comprises. Renvoyer à un autre skill dispense de recopier sa procédure, jamais d'appliquer ses règles.
- **Pas d'organisation, pas de contact. C'est un arrêt, pas une préférence.** Un contact orphelin est irréversible depuis l'assistant : il faut ouvrir NoCoDB à la main. La règle a déjà échoué une fois ici sous forme de renvoi, elle est donc écrite en blocage à l'étape 6.
- **Une accroche s'écrit en phrases complètes, sujet et verbe, y compris dans les 300 caractères.** Le plafond se tient en coupant une idée, jamais en amputant une phrase : « Volontiers en lien » n'est pas une phrase, c'est une abréviation, et elle s'entend.

- **Le skill ne clique jamais et n'envoie jamais.** Il produit un texte, l'utilisateur agit.
- **Rien de scrapé ne va en base.** L'enrichissement de profil sert au message, puis disparaît. **Une seule exception, la correction d'une identité fausse** : nom, prénom, fonction, nom de l'organisation. Ces champs sont ceux que la base porte de plein droit, et un profil transmis en est la meilleure source.
- **Pas d'accroche sans point d'accroche.** Le dire plutôt que de produire du générique.
- **Ne rien inventer sur la personne** : ni un post qu'elle n'a pas écrit, ni une connaissance commune supposée. Une accroche fausse se démasque en une réponse. Ce qui est **lisible sur le profil** n'est pas une invention : un changement de poste que le fil d'expérience date se cite sans réserve.
- **Ne jamais choisir le format en silence** quand la personne est déjà en base. Note d'invitation et message de suite ne se plafonnent pas pareil, et le texte hybride qui sort d'un choix implicite ne convient à aucun des deux.
- **300 caractères sur une note d'invitation**, comptés, pas estimés.
- **Une demande de consignation ne reste jamais sans effet et sans réponse.** Si l'utilisateur dit qu'il a envoyé et qu'on n'écrit pas, il croit la chose faite et rien ne le détrompe. Une erreur bruyante se rattrape, un silence non. En cas d'empêchement, base injoignable ou personne impossible à identifier, le dire et nommer ce qui n'a pas été écrit.
- **Un message qui porte plusieurs demandes se traite en entier.** Une pièce jointe ne remplace pas la phrase qui l'accompagne : traiter la phrase d'abord, l'image ensuite.

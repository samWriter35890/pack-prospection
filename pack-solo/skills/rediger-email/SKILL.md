---
name: rediger-email
description: Rédiger un email professionnel à un contact de la base, premier contact, relance, envoi de devis, remerciement après rendez-vous. À utiliser quand l'utilisateur demande d'écrire, de préparer ou de relancer par mail. Reprend l'historique des échanges pour personnaliser.
---

# Rédiger un email

Prépare un email à une personne de la base, à partir de son historique réel. **Le skill écrit, l'utilisateur relit et envoie.** Aucun envoi automatique.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Date", "description": "desc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Date desc"` est refusée.
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.
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

**Une fois par session, jamais une fois par appel.** Ce contexte est stable : il se remplit à la mise en main et se revoit une fois par an. S'il a déjà été lu dans la conversation, le réutiliser tel quel sans rappeler la base.

**Lire les dix champs, même ceux dont ce skill n'a pas l'usage.** C'est délibéré : la lecture sert toute la session, et les autres skills s'en serviront ensuite sans repayer l'appel.

**Si la table est vide ou l'enregistrement absent :** le dire en une phrase, continuer quand même, et signaler que le texte sera générique tant que le contexte n'est pas rempli. **Ne jamais deviner** ce que l'utilisateur vend ni comment il signe. Un contexte inventé produit un texte qui sonne juste et qui est faux, ce qui est le pire des deux cas.

**`Signature` se recopie, elle ne se réécrit pas.**

**`Ce que je ne fais pas` est un interdit, pas une indication.** Rien de ce qui y figure ne se propose, ne se promet ni ne se sous-entend dans un texte destiné à un tiers.

Ce que ce skill en fait, lui : **`Comment je parle` décide du tutoiement, du registre et des mots à éviter. `Signature` clôt le mail. `Ce que je vends` et `Ce que je ne fais pas` bornent ce qui peut être proposé.** C'est un email : il sort de chez l'utilisateur avec son nom dessus. Aucun autre skill n'a autant besoin de ces quatre champs.

**Et `Lien de réservation` se recopie en clair, ou ne se remplace par rien.** C'est la règle de `Signature`, appliquée au rendez-vous. Dès que le mail propose de se voir ou de se parler, le lien y figure **tel quel**, en toutes lettres, jamais derrière un « je vous envoie mon lien » qui oblige à un mail de plus. S'il est vide, proposer l'échange **sans en inventer les modalités** : ni café, ni visio, ni créneau, ni lien fabriqué. Demander plutôt à l'utilisateur ce qu'il veut proposer, et lui signaler qu'un lien en base éviterait la question la prochaine fois.

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

### 1. Trouver la personne

```
queryRecords  Contacts  where=(Nom complet,like,%le goff%)
```

Retenir le `Id`, le prénom, la fonction, l'organisation, l'email, et **`Rôle dans la décision`**, qui décidera de l'angle à l'étape 3. **Pas d'email en base : le dire tout de suite**, proposer d'écrire quand même le texte, et suggérer de compléter la fiche avec `creer-contact`.

### 2. Lire l'historique. Cette étape n'est pas optionnelle

```
queryRecords  Échanges  where=(Contact,eq,Marie Le Goff)  pageSize=8
                        sort=[{"field": "Date", "description": "desc"}]
queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)
```

Le filtre sur un champ de lien se fait sur le **libellé affiché** de l'enregistrement lié. Ne pas passer `fields` sur ces deux appels : les libellés liés servent à la rédaction.

Un mail qui ignore les trois échanges précédents est pire que pas de mail. Ce qu'on cherche dans l'historique :

- **La dernière chose dite**, et par qui. Relancer quelqu'un qui attend une réponse de l'utilisateur est une faute.
- **Le sujet réel** de la relation, avec ses mots à elle ou lui.
- **Le détail humain** noté dans un résumé : un déménagement, un recrutement, une échéance. C'est ce qui distingue un mail personnalisé d'un mail de série.
- **L'étape de l'affaire** en cours, s'il y en a une : on n'écrit pas pareil avant et après une proposition.

Regarder aussi `Notes` sur la fiche du contact, qui porte le contexte durable.

### 3. Écrire

Proposer **un seul** email complet, objet compris. Pas trois variantes : l'utilisateur veut envoyer, pas arbitrer.

Règles de forme :

- **Court.** Cinq à dix lignes. Un dirigeant lit sur mobile.
- **Une seule demande**, formulée clairement, en fin de message.
- **Le ton de `Comment je parle`**, pas un ton générique. Ce champ règle le ton du mail **vers son destinataire**, tutoiement ou vouvoiement, registre, mots à ne pas employer ; il ne dit rien de la façon dont on parle à l'utilisateur, qui se tutoie dans tous les cas. S'il est vide, vouvoyer le destinataire par défaut et le signaler.
- **Aucun tiret cadratin**, voir les garde-fous : l'interdiction vaut pour le corps du mail comme pour les phrases dites autour.
- **L'angle suit `Rôle dans la décision`.** À un `Décideur`, ouvrir sur ce que ça change pour la boîte : du temps repris, un coût, un risque écarté. À un `Prescripteur`, un `Utilisateur` ou un `Relais`, ouvrir sur ce que ça change dans leur travail à eux, et leur donner de quoi en parler en interne. Sur `Inconnu` ou sur un champ vide, prendre l'angle du décideur, qui est le plus sûr par défaut. **Ne jamais écrire au destinataire qu'il n'est pas celui qui décide**, ni lui demander de faire suivre à qui décide : le champ oriente le texte, il ne se dit pas.
- **`Pourquoi eux` fait un bon premier paragraphe, s'il est renseigné.** C'est l'argument d'affaires déjà entendu de la bouche de quelqu'un chez eux, et le reprendre montre qu'on a écouté. Le reformuler, ne pas le recopier mot pour mot : ce sont des notes internes, pas une phrase à leur relire.
- Pas de formule creuse (« j'espère que vous allez bien », « je me permets de revenir vers vous »), pas de superlatif, pas de jargon.
- **Signer en recopiant `Signature`**, tel quel. Ce champ existe précisément pour qu'aucune signature ne soit inventée. S'il est vide, s'arrêter avant la signature et demander à l'utilisateur comment il signe, plutôt que d'en fabriquer une.
- **Ne rien proposer qui figure dans `Ce que je ne fais pas`.** C'est le garde-fou qui coûte le plus cher quand il manque : un email est irrattrapable une fois parti, et une prestation promise par erreur engage l'utilisateur devant son client.

**Un texte, dans un bloc de code. Un lot, dans un artefact.** Le bloc de code garde le texte à l'écran et donne le bouton copier : sur un message unique, il n'y a rien à arbitrer. L'artefact reste le bon support à partir de plusieurs messages. **Jamais en citation** : elle n'offre pas le bouton, et l'utilisateur en est réduit à sélectionner à la souris un texte de dix lignes.

L'objet se donne **au-dessus** du bloc, en clair : il se colle dans un autre champ que le corps, et un objet enfermé dans le même bloc part avec le message. Le bloc ne contient que le corps du mail, signature comprise.

Puis **s'arrêter et demander**. Ne rien écrire en base tant que l'utilisateur n'a pas validé et envoyé.

### 4. Tracer, après confirmation d'envoi

Quand l'utilisateur dit qu'il a envoyé :

```
createRecords  Échanges
{
  "Objet":   "Relance sur la proposition site vitrine",
  "Date":    "2026-08-11",
  "Canal":   "Email",
  "Sens":    "Sortant",
  "Résumé":  "<l'essentiel du message envoyé, deux ou trois lignes>",
  "Contact":      {"Id": 12},
  "Opportunité":  {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

Le `Résumé` reprend l'essentiel du message, pas le mail intégral : le journal doit rester lisible.

**Puis faire avancer `Statut relation`, dans le même geste.** Un premier message sortant sur un contact `Nouveau` le passe à `À contacter`, une réponse reçue le passe à `En discussion`. C'est une écriture du **chemin normal** : elle ne dépend d'aucune affaire, et elle ne se demande pas.

```
updateRecords  Contacts  id=15  {"Statut relation": "À contacter"}
```

**Faire avancer, jamais reculer** : un contact déjà `En discussion`, `Client` ou `Dormant` n'y redescend pas. La règle complète est dans `enregistrer-echange`, étape 3, elle ne se recopie pas plus loin que ceci. Sans elle, un contact à qui on a écrit hier reste rangé avec ceux qu'on n'a jamais approchés, et le champ ne veut plus rien dire.

### 5. Refermer ce que le mail termine

**Un mail parti referme presque toujours quelque chose.** C'est l'étape qu'on saute, et celle qui laisse derrière elle une tâche fantôme et une affaire figée à une étape périmée. L'utilisateur, lui, croit sa base à jour parce qu'il vient de dire « c'est envoyé ».

Lire les tâches ouvertes de la personne, et de l'affaire quand il y en a une :

```
queryRecords  Tâches  where=(Contact,eq,Marie Le Goff)~and(Statut,in,À faire,En cours)
```

**La tâche que le mail accomplit** se nomme et se propose, puis se referme sur le mot de l'utilisateur :

```
updateRecords  Tâches  id=1  {"Statut": "Fait"}
```

**L'étape de l'affaire** bouge avec le mail : un devis parti, une proposition envoyée passent l'affaire à `Proposition`. La proposer, jamais la poser seul. La bascule appartient à `creer-opportunite`, étape 4, qui pose du même geste la relance obligatoire et réclame la date de clôture prévue.

> **Proposer, pas écrire d'office.** Deviner qu'un mail referme une tâche est une inférence, et une tâche fermée à tort disparaît de « Ma journée » sans laisser de trace. Ce qui n'est pas négociable, c'est de **regarder** et de **demander** : rendre la main sans avoir ouvert la liste des tâches est la faute, pas le fait de ne pas avoir écrit.

**Ne pas retoucher l'échéance d'une tâche qu'on referme.** Elle dit quand la chose était attendue, pas quand elle a été faite.

### 6. Poser la suite

Un mail envoyé sans relance posée est un mail oublié. Deux écritures, presque toujours ensemble :

```
updateRecords  Contacts  id=12  {"Prochaine relance": "2026-08-25"}

createRecords  Tâches
{
  "Tâche":     "Relancer Marie Le Goff si pas de réponse",
  "Échéance":  "2026-08-25",
  "Priorité":  "Moyenne",
  "Statut":    "À faire",
  "Contact":       {"Id": 12},
  "Opportunité":   {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Priorité` | Haute · Moyenne · Basse |
| `Statut` | À faire · En cours · Fait · Annulée |

Une à deux semaines par défaut, selon l'étape de l'affaire. Le champ `Prochaine relance` fait remonter la personne dans la vue « À relancer » et dans l'accueil du matin.

---

## Garde-fous

- **Ce que disent les quatre repères ne sort jamais dans le mail.** Ni la correspondance cible, ni le rôle, ni la priorité, ni la note interne ne se citent au destinataire, même reformulés en compliment. Ils choisissent l'angle et ils restent en base : le test est celui du droit d'accès, et personne ne veut lire dans un mail ce qu'on a écrit de lui pour soi.

- **Ne jamais envoyer.** Ce skill produit un texte. L'envoi est un geste de l'utilisateur, y compris s'il demande le contraire : aucun canal d'envoi n'est branché dans le socle.
- **Lire avant d'écrire.** Aucun mail rédigé sans avoir consulté l'historique, même quand l'utilisateur est pressé.
- **Ne rien inventer** : pas de rendez-vous, pas de chiffre, pas d'engagement qui ne figure ni dans le récit ni dans la base.
- **Ne pas relancer quelqu'un qui attend une réponse.** Si le dernier échange est entrant et sans suite de l'utilisateur, le signaler avant de rédiger.
- **Une trace après envoi confirmé, pas avant.** Un échange consigné pour un mail jamais parti pollue durablement le journal.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.**
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Une réponse pose une question, deux au maximum, et jamais sous forme de liste à puces.** Tout ce qui manque part bien dans le même tour, une question repoussée n'étant jamais posée, mais **ce qui n'empêche pas d'écrire se dit sans point d'interrogation** : un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. Trois puces interrogatives ne sont pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

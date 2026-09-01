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
- **`Dernier échange` et `Étape depuis` ressemblent à des champs calculés, et ce sont des champs que les compétences écrivent.** `Contacts.Dernier échange` porte la date du dernier échange consigné, `Opportunités.Étape depuis` la date du dernier changement d'étape. **La base ne les remplit pas** : le schéma v1.8 les voulait en rollup, l'instance ne le permet pas, la fonction `max` d'un rollup y étant réservée à un plan payant. Deux conséquences, et aucune n'est facultative : **toute écriture d'un échange réécrit `Dernier échange`**, toute écriture de `Étape` réécrit `Étape depuis`, dans le même appel et à la date de l'événement, pas à celle de la saisie ; et **une valeur vide veut dire « jamais écrit », pas « jamais d'échange »**, donc un filtre `lt` sur ces champs rend une liste incomplète tant que le parc n'est pas repassé une fois.
- **`Ouverte` dit si une tâche ou une affaire est en cours, et il se lit avec `eq`, jamais avec `in`.** C'est une colonne **calculée par la base** : elle vaut `1` tant qu'une tâche n'est ni `Fait` ni `Annulée`, et `1` tant qu'une affaire n'est ni `Gagnée` ni `Perdue`. Elle remplace depuis le schéma v1.8 les filtres par énumération, `(Statut,in,À faire,En cours)` et `(Étape,in,Identifiée,Contactée,RDV,Proposition)`, qui se mettaient à mentir en silence dès qu'une valeur était ajoutée à la liste. **Deux règles vont avec, et aucune n'est facultative :** l'opérateur `in` échoue bruyamment sur une colonne calculée, `(Ouverte,in,1)` compris, donc `(Ouverte,eq,1)` est la seule forme valide ; et **`Ouverte` ne s'écrit jamais**, c'est `Statut` ou `Étape` qu'on écrit, la base recalcule.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un tri s'écrit `sort=[{"field": "Date", "description": "desc"}]`.** La clé qui porte le sens s'appelle bien `description`, c'est un défaut de nommage du connecteur. Une chaîne comme `"Date desc"` est refusée.
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien à la création, et par sa colonne de clé étrangère ensuite.** `updateRecords` sur un **champ de lien** échoue toujours, quelle que soit la forme employée, sur `SQLITE_ERROR: near "(": syntax error` : c'est une limite du connecteur, pas une faute de syntaxe. Mais la même relation porte aussi une **colonne de clé étrangère**, de la forme `nc_<préfixe>___<Table liée>_id`, et **celle-là s'écrit en `updateRecords` comme un champ ordinaire** : `{"nc_h27z___Opportunités_id": 3}` rattache l'enregistrement à l'affaire n° 3, et le lien revient résolu avec son libellé dès la réponse. **Le nom exact de cette colonne se lit dans un `getRecord` sur la table concernée, jamais de mémoire** : le préfixe est propre à chaque base et il change d'un client à l'autre. **Deux conséquences :** créer dans l'ordre reste la bonne façon de faire, un lien posé à la création valant mieux qu'un rattrapage ; et **un lien oublié se répare en une écriture**, sans jamais supprimer ni recréer l'enregistrement.
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

## Les trois repères de qualification

Trois champs disent ce qui mérite le temps de l'utilisateur. Sur l'organisation : `Correspondance cible`, cœur de cible, périphérie, hors cible ou à qualifier, et `Pourquoi eux`, pourquoi cette entreprise est dans la base, en une ligne. Sur le contact : `Rôle dans la décision`, décideur, prescripteur, utilisateur, relais ou inconnu.

- **On juge la pertinence de l'affaire, jamais la personne.** `Correspondance cible` juge une **entreprise** contre le champ `À qui je le vends` du contexte. `Rôle dans la décision` décrit une **position dans un achat**, celle que l'intéressé assume lui-même en réunion, jamais un trait de caractère. Le test qui tranche : ne rien écrire qu'on ne serait pas prêt à lui lire s'il demandait à voir sa fiche.
- **Rien ne s'écrit sans un mot de l'utilisateur.** Ces trois champs se **proposent**, ils ne se posent jamais d'office, et une proposition non confirmée ne s'écrit pas. Un rôle déduit d'une fonction est une inférence, pas un fait, et elle a le défaut de toutes les inférences : elle sonne juste. Ce qui est obligatoire, c'est de proposer quand on a de quoi le faire, pas d'écrire.
- **`Rôle dans la décision` se demande à la création du contact, et c'est la seule question de qualification qui ne se rate pas.** Le moment est le bon parce que c'est le seul où l'utilisateur a la personne en tête et où l'on n'interrompt rien : plus tard, il n'y en a pas. Il reste soumis à la règle du dessus, on écrit sa réponse et jamais sa fonction, et il vaudra de plus en plus cher à mesure que le produit sert à préparer des rendez-vous et pas seulement à les consigner. Le geste complet est dans `creer-contact`.
- **Vide et « à qualifier » ne disent pas la même chose.** Vide veut dire qu'on n'a jamais demandé. `À qualifier` et `Inconnu` veulent dire qu'on a demandé et que ce n'est pas tranché. **Ne jamais reposer une question déjà posée** : un champ qui porte l'une de ces deux valeurs se laisse tranquille jusqu'à ce que l'utilisateur en dise quelque chose de neuf.
- **La question de la cible nomme les trois rangements en français, et demande la raison dans la même phrase.** « Frères Boyer, tu les mets où : au cœur de ce que tu cherches, en périphérie, ou plutôt de côté ? Et qu'est-ce qui te fait dire ça ? » Une question qui ne demande que le motif, « qu'est-ce qui te les fait mettre là, chez eux », **ne se comprend pas**, « là » n'ayant aucun référent pour qui ne connaît pas le champ, et surtout **elle ne rapporte pas le rangement** : il faudrait alors le déduire d'une réponse en texte libre, et une classe déduite d'un motif favorable est une invention que personne ne peut vérifier. **Sans rangement explicite dans la réponse de l'utilisateur, rien ne s'écrit dans `Correspondance cible`** : la raison seule remplit `Pourquoi eux` et la correspondance reste vide, ce qui est exactement ce que « vide veut dire jamais demandé » signifie.
- **`Pourquoi eux` porte l'histoire, pas l'état du moment.** Il dit d'abord **pourquoi cette entreprise est entrée dans la base** : ce qui, chez eux, appelle l'offre. Le jour où elle en sort, où elle passe hors cible, **la raison de la sortie s'ajoute à la ligne d'entrée, elle ne la remplace pas** : « trois devis par semaine tapés à la main, veulent industrialiser », puis « écartés le 20 août, ce qu'ils cherchent est trop loin de ce que je fais ». Une entreprise mise de côté sans raison écrite est un travail qu'on refera dans six mois, faute de se souvenir pourquoi on avait dit non. Le test du droit d'accès vaut sur la ligne de sortie comme sur celle d'entrée : une raison d'affaires s'écrit, un jugement sur les gens ne s'écrit pas.
- **Ces mots se disent en français, jamais en nom de champ.** « Une boîte qui est vraiment ta cible », « c'est lui qui décide », « celle-là, tu la mets de côté ». Jamais « je passe la correspondance cible à cœur de cible ». C'est la règle du vocabulaire de la base appliquée à ces quatre champs : l'utilisateur a des clients et des priorités, pas des colonnes.
- **L'urgence d'un contact ne vit pas dans un champ de qualification, elle vit dans `Prochaine relance`.** Le contact a porté une `Priorité` jusqu'au 31 août 2026, remplie **3 fois sur 31** en douze jours d'usage : le champ est retiré du produit. La date de la prochaine action dit toute seule, et sans que personne ait à la tenir à jour, ce qu'une échelle haute, moyenne, basse disait mal. **Ne jamais la reconstituer sous un autre nom** : ni une mention d'urgence glissée dans `Notes`, ni un `Pourquoi eux` transformé en jugement sur qui rappeler d'abord. Ce qui est urgent est ce qui est daté.
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

> **Un message ne dit d'un autre envoi que ce qui est déjà consigné.** Un email rédigé au tour précédent n'est pas un email parti. Tant que l'utilisateur n'a pas dit que c'était envoyé, la phrase se supprime ou se met au futur : « je vous écris aussi par mail ». Le message part chez quelqu'un ; une affirmation fausse n'y est pas rattrapable.
>
> **Et quand l'utilisateur impose un ordre, l'ordre demandé gouverne ce que chaque message a le droit de tenir pour acquis.** « avant », « d'abord », « en premier » ne règlent pas seulement la file d'attente : le message envoyé en premier ne peut se référer à aucun des suivants, et le second peut se référer au premier **s'il est parti**. Un ordre inversé produit des textes qui se citent l'un l'autre en boucle, et c'est l'utilisateur qui le découvre chez son destinataire.

**Un texte, dans un bloc de code. Un lot, dans un artefact.** Le bloc de code garde le texte à l'écran et donne le bouton copier : sur un message unique, il n'y a rien à arbitrer. L'artefact reste le bon support à partir de plusieurs messages. **Jamais en citation** : elle n'offre pas le bouton, et l'utilisateur en est réduit à sélectionner à la souris un texte de dix lignes.

L'objet se donne **au-dessus** du bloc, en clair : il se colle dans un autre champ que le corps, et un objet enfermé dans le même bloc part avec le message. Le bloc ne contient que le corps du mail, signature comprise.

> **Ce que le message promet devient une tâche, au moment de la rédaction et pas au moment de l'envoi.** « je vous transmettrai un devis d'ici la fin de semaine prochaine » crée une tâche datée, rattachée à l'affaire. Elle est vraie que le mail parte aujourd'hui ou demain : c'est du travail que l'utilisateur s'est engagé à faire. La relance, elle, reste liée à l'envoi.

Puis **s'arrêter et demander**. Ne rien écrire d'autre en base tant que l'utilisateur n'a pas validé et envoyé : **la tâche de promesse ci-dessus est la seule exception**, et elle l'est parce qu'elle ne trace pas un envoi, elle trace un engagement pris en écrivant. Tout le reste, l'échange, la relance, la bascule d'étape, attend le mot de l'utilisateur.

### 4. Tracer, après confirmation d'envoi

Quand l'utilisateur dit qu'il a envoyé :

> **Un email consigné se rattache à l'affaire quand il y en a une.** Le même bloc que celui de la consignation d'échange : lire les affaires ouvertes du contact, puis écrire. Un email envoyé sur le sujet d'une affaire ouverte le jour même et rattaché à rien fera compter cette affaire pour dormante au premier tableau de bord, et c'est arrivé le 1er septembre 2026 dans la séance qui venait d'ouvrir l'affaire.

```
1. Relire la date du jour.                       ← jamais déduite du fil
2. queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)
                               fields=["Nom","Étape","Clôture prévue"]
3. createRecords Échanges
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

**Quand l'échange consigné est un message que l'on vient d'écrire, le `Résumé` reprend l'objet et la promesse du message, pas son texte intégral. Une phrase.** « Proposition d'un point de trente minutes, devis annoncé pour la fin de semaine » et non le mail recopié. Le journal se relit en diagonale six mois plus tard : un résumé qui est la copie du message ne se relit pas, et il noie les deux informations qui comptent, ce qu'on a demandé et ce qu'on a promis. **La règle vise les envois rédigés, pas tous les échanges** : une invitation acceptée porte légitimement un résumé vide.

**Puis écrire `Dernier échange` et faire avancer `Statut relation`, dans le même geste.** `Dernier échange` prend la date de l'échange qu'on vient de consigner, à chaque fois et sans le demander : **rien ne le calcule à notre place**, et un contact dont la date n'est pas réécrite passera pour muet dans tous les bilans. `Statut relation`, lui, avance : un premier message sortant sur un contact `Nouveau` le passe à `À contacter`, une réponse reçue le passe à `En discussion`. Deux écritures du **chemin normal** : elles ne dépendent d'aucune affaire, et elles ne se demandent pas.

```
1. getRecord     Contacts  id=15
                 ← l'état actuel de Statut relation et de Dernier échange
2. updateRecords Contacts  id=15  {"Statut relation": "À contacter", "Dernier échange": "2026-08-11"}
                 ← seulement sur les valeurs qui avancent
```

**Faire avancer, jamais reculer, et cela demande de lire d'abord.** Un contact déjà `En discussion`, `Client` ou `Dormant` ne redescend pas à `À contacter`, et une date de dernier échange **postérieure** à celle qu'on s'apprête à écrire se garde telle quelle. **Sans la lecture, la comparaison n'a rien à comparer.** C'était le seul renvoi croisé du plugin qui demandait un geste sans le montrer, et le 31 août 2026 l'écriture est partie sans lecture, exactement comme l'exemple la montrait. **Une compétence qui écrit dans une table appartenant à une autre hérite de ses règles, elle ne les cite pas** : c'est la formule que porte déjà `import-capture-linkedin`, et c'est le modèle. Sans elle, un contact à qui on a écrit hier reste rangé avec ceux qu'on n'a jamais approchés, et le champ ne veut plus rien dire.

### 5. Refermer ce que le mail termine

**Un mail parti referme presque toujours quelque chose.** C'est l'étape qu'on saute, et celle qui laisse derrière elle une tâche fantôme et une affaire figée à une étape périmée. L'utilisateur, lui, croit sa base à jour parce qu'il vient de dire « c'est envoyé ».

Lire les tâches ouvertes de la personne, et de l'affaire quand il y en a une :

```
queryRecords  Tâches  where=(Contact,eq,Marie Le Goff)~and(Ouverte,eq,1)
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

- **Ce que disent les trois repères ne sort jamais dans le mail.** Ni la correspondance cible, ni le rôle, ni la note interne ne se citent au destinataire, même reformulés en compliment. Ils choisissent l'angle et ils restent en base : le test est celui du droit d'accès, et personne ne veut lire dans un mail ce qu'on a écrit de lui pour soi.

- **Ne jamais envoyer.** Ce skill produit un texte. L'envoi est un geste de l'utilisateur, y compris s'il demande le contraire : aucun canal d'envoi n'est branché dans le socle.
- **Lire avant d'écrire.** Aucun mail rédigé sans avoir consulté l'historique, même quand l'utilisateur est pressé.
- **Ne rien inventer** : pas de rendez-vous, pas de chiffre, pas d'engagement qui ne figure ni dans le récit ni dans la base.
- **Un message sortant n'engage que ce que l'utilisateur a dit.** Ce qui part chez un tiers ne contient aucune intention, aucune promesse, aucune présence annoncée que l'utilisateur n'ait formulée dans la conversation ou que la base ne porte. **Une information reçue n'est pas un engagement pris** : « il m'a conseillé cet événement » se remercie, il ne s'y répond pas « j'y serai ». Dans le doute, la phrase se retire, ou se pose en question à l'utilisateur avant l'envoi. **C'est le seul endroit du pack où une erreur ne se rattrape pas** : le briefing du lendemain corrigera une date fausse, personne ne rattrapera un email parti. Et l'invention se propage : celle du 1er septembre 2026 a produit une tâche datée, donc une obligation future consignée en base.
- **Ne pas relancer quelqu'un qui attend une réponse.** Si le dernier échange est entrant et sans suite de l'utilisateur, le signaler avant de rédiger.
- **Une trace après envoi confirmé, pas avant.** Un échange consigné pour un mail jamais parti pollue durablement le journal.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre. **Et la règle porte sur le parcours, pas sur le mode d'emploi.** Quand l'utilisateur interroge la construction de sa base, compare deux champs, ou demande pourquoi une valeur plutôt qu'une autre, il pose une question d'outil et attend une réponse d'outil : les noms de champs et les valeurs se disent. **Le basculement est marqué par la question, jamais par la compétence.** Dès le tour suivant qui parle d'une personne ou d'une entreprise, on revient au français ordinaire.
- **Le jargon commercial anglais ne se dit pas davantage.** `pipeline`, `lead`, `funnel`, `closing` ne se disent pas. On dit « tes affaires en cours », « ta plus grosse affaire », « ce que tu as en discussion ». C'est la règle du vocabulaire de la base élargie d'un cran : le nom d'une colonne trahit le schéma, un mot de jargon trahit le métier de celui qui a écrit l'outil. **`pipeline` est un mot d'outil et ne sort jamais vers l'utilisateur.** Il vit légitimement dans la `description` d'une compétence, que le client ne lit pas, et nulle part dans une phrase qui lui est adressée. Ce qu'il désigne se dit « tes affaires en cours ». **Le mot est ressorti dans une phrase entière une passe après avoir été corrigé** : il ne se retire donc pas d'une liste de mots interdits, il se remplace par sa traduction, écrite juste à côté de lui.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.** **Tout ce qui s'affiche entre deux appels d'outil est une réponse.** Même langue, même vocabulaire, mêmes interdits que la phrase finale : le français, aucun nom de table ni de champ, aucune annonce de ce qui va être appelé. **Si rien n'a besoin d'être dit entre deux écritures, rien ne se dit.** **Un enchaînement ne se raconte pas davantage qu'un outil.** Ni « Historique : », ni « Maintenant, l'échange de ce matin », ni aucun titre de section qui décrive l'étape où l'on se trouve. Ce sont des étiquettes de procédure, et « journal » est un nom d'objet interne. **Ce qui vient d'être écrit se dit une fois, en français, dans la phrase de confirmation prévue pour cela**, et pas une seconde fois en tête du geste suivant.
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Ce qu'on demande et ce qu'on restitue n'obéissent pas à la même règle de forme, et c'est la question qui décide, jamais la compétence.**
  - **Ce qu'on demande : trois questions au maximum, et numérotées dès qu'il y en a deux.** Une question seule reste dans la phrase, sans numéro. Deux ou trois se détachent, chacune sur sa ligne, numérotées, de sorte que l'utilisateur puisse répondre à la 1 et à la 2, n'en traiter qu'une, et **voir laquelle il n'a pas traitée**. Deux questions noyées dans une phrase, il en manque une sans savoir qu'il en a manqué une. Ce qui reste proscrit, c'est la liste de puces interrogatives sans numéro et sans fin : ce n'est pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais.
  - **Ce qu'on restitue se structure** : une liste numérotée pour ce qu'il y a à faire, un tableau quand les lignes ont plus de deux attributs à comparer. Une restitution n'a pas de plafond de trois, elle a la longueur de ce qu'elle rend.
  - **Une puce qui se termine par un point d'interrogation est une question et retombe sous la première règle.** C'est le seul test qui tranche, et il se fait sur le texte écrit, pas sur l'intention.
- **Ce qui n'empêche pas d'écrire se dit sans point d'interrogation, et ne compte donc pas dans les trois.** Un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.
- **Une date affichée se recopie, elle ne se raconte pas.** Quand une échéance ou une date d'échange est nommée dans la réponse, elle reprend la valeur lue en base, au format que l'utilisateur reconnaîtra, « le 24 août » plutôt que « hier » ou « mercredi ». Les repères relatifs se calculent à partir de la date du jour **relue**, jamais estimée. Le jour de la semaine se déduit de la date, il ne se suppose pas.
- **Et cela vaut pour toute date lue dans un texte, pas seulement pour un champ de date.** Une note de classement, un résumé d'échange, une observation datée se citent avec leur date en clair, jamais en relatif. **Une date stockée franchit minuit, une date racontée en relatif ne le franchit pas** : une fenêtre ouverte la veille garde en tête un « aujourd'hui » périmé. C'est le piège propre aux sessions qui durent plus d'une journée, et il n'existe pas en démonstration.
- **Une durée est un calcul entre deux dates lues, jamais une impression.** « Depuis plus d'un mois », « ça fait longtemps », « il y a plusieurs semaines » ne s'écrivent que si la date de départ a été lue dans ce tour et soustraite de la date du jour, elle aussi relue. **Dans le doute, on donne la date plutôt que la durée** : « son dernier échange date du 26 août » est toujours vrai et toujours utile, là où « depuis plus d'un mois » est faux dès qu'on se trompe d'un facteur cinq. **Une durée fausse est invisible à la relecture quand elle voisine avec des chiffres justes** : le lecteur qui a vérifié les quatre premiers ne recompte pas le cinquième.

---
name: creer-opportunite
description: Ouvrir une affaire potentielle rattachée à un contact, ou faire évoluer son étape dans le pipeline. À utiliser quand l'utilisateur évoque un besoin client identifié, un devis à faire, une proposition envoyée, une affaire gagnée ou perdue.
---

# Créer ou faire avancer une opportunité

Ouvre une affaire, ou la fait changer d'étape. C'est ce qui alimente le pipeline et le bilan.

Appelé directement, ou depuis `enregistrer-echange` quand le récit décrit une affaire qui n'existe pas encore. **Dans ce cas, l'affaire se crée avant l'échange**, jamais après : le lien de l'échange vers l'affaire ne s'écrit qu'à la création de l'échange.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste, ne jamais traduire ni abréger.
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

Ce que ce skill en fait, lui : c'est le seul des quatre qui n'écrit pas de texte, et il s'en sert autrement. **`Ce que je vends` donne le vocabulaire du champ `Nom` de l'affaire**, celui du catalogue de l'utilisateur plutôt qu'une paraphrase de ce qu'il vient de raconter. Le Kanban Pipeline devient lisible parce que les affaires y portent des noms cohérents d'une ligne à l'autre.

**Et `Ce que je ne fais pas` sert de contrôle avant d'ouvrir l'affaire.** Si le besoin décrit tombe hors périmètre, ne pas créer en silence : le signaler en une phrase et demander. Une affaire ouverte sur une prestation que l'utilisateur ne sait pas livrer pollue son pipeline, fausse son bilan, et finit en promesse quand `rediger-email` viendra écrire dessus.

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

### 1. Créer, ou faire évoluer ? La question à trancher en premier

Une même personne peut porter plusieurs affaires. Avant d'écrire, regarder ce qui existe déjà :

```
queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)
```

Le filtre sur un champ de lien se fait sur le **libellé affiché** de l'enregistrement lié, ici le nom complet du contact. Ne pas passer `fields` : le nom du contact et de l'organisation sont utiles à la restitution.

- **Rien d'ouvert, ou un sujet clairement différent** : créer une affaire (étape 3).
- **Une affaire ouverte sur le même sujet** : ne pas en créer une seconde. Faire évoluer l'étape (étape 4).
- **Doute** : montrer les affaires trouvées avec leur étape et leur montant, et demander. Un pipeline en doublon fausse tous les chiffres du bilan.

Si le contact n'existe pas encore, passer par `creer-contact` avant. **Une opportunité sans contact n'a pas d'interlocuteur** : la base l'accepte, ce skill non.

### 2. Retenir les identifiants

Le `Id` du contact, et celui de son organisation. L'organisation se lit sur la fiche du contact, elle se recopie sur l'affaire pour permettre le filtrage par entreprise.

**Lire au passage `Correspondance cible` et `Pourquoi eux` sur l'organisation.** Les deux servent à l'étape 3, l'un pour signaler une contradiction, l'autre pour éviter de redemander ce qui est déjà écrit.

### 3. Créer l'affaire

```
createRecords  Opportunités
{
  "Nom":              "Site vitrine + base contacts",
  "Étape":            "Identifiée",
  "Montant estimé":   3200,
  "Clôture prévue":   "2026-09-30",
  "Notes":            "<le contexte du besoin, dans les mots de l'utilisateur>",
  "Contact":       {"Id": 12},
  "Organisation":  {"Id": 7}
}
```

| Champ | Valeurs admises |
|---|---|
| `Étape` | Identifiée · Contactée · RDV · Proposition · Gagnée · Perdue |

- `Nom` : ce qui sera vendu, pas le nom du client. « Site vitrine + base contacts », pas « Affaire Le Goff ». C'est ce qui s'affiche dans le Kanban Pipeline.
- `Montant estimé` : un nombre nu, sans symbole ni espace. Le champ est en euros. **Ne jamais l'inventer, et toujours le demander.** Ce sont deux règles, pas une : si l'utilisateur n'a donné aucun chiffre, créer l'affaire sans montant, puis **poser la question dans la même réponse**, avec un ordre de grandeur si le contexte en porte un. « Je n'ai pas de montant sur cette affaire. Un ordre de grandeur, même large, suffit à la faire compter dans le pipeline. » Un champ qu'on s'interdit d'inventer est un champ qu'on doit demander : s'interdire l'invention n'est pas une dispense de poser la question.
- `Clôture prévue` : la date de décision espérée, pas la date de livraison. C'est elle qui fait apparaître l'affaire dans le bilan du mois. **Elle se propose dès la création, à toutes les étapes, `Identifiée` comprise.** L'affaire 5 du 19 août 2026 est née en `Identifiée` sans date, à 4 000 € : signée demain, elle ne compterait dans aucun bilan. Une date lointaine et fausse se corrige au premier échange, une date absente ne se corrige jamais toute seule. Sans indication de l'utilisateur, en proposer une et le dire : « je mets fin septembre en prévision, on ajustera ».
- **Aucun tiret cadratin**, voir les garde-fous : l'interdiction vaut pour `Notes` comme pour la phrase de confirmation.

> **`Contact` et `Organisation` se posent ici ou jamais.** Les deux liens ne s'écrivent qu'à la création, voir les conventions ci-dessus. Une affaire créée sans contact restera sans interlocuteur, et le filtre par entreprise du bilan l'ignorera.

> **Une affaire ouverte à la suite d'un échange raccroche cet échange, dans le même tour.** Le lien vers l'affaire ne s'écrivant qu'à la création, cela veut dire supprimer et recréer l'échange en recopiant tous ses champs, procédure décrite dans la compétence qui consigne les échanges. Un échange créé une minute avant l'affaire n'est pas rattaché tout seul, et l'affaire affichera zéro échange, ce qui la fera classer dormante au premier tableau de bord.

#### Une affaire qui s'ouvre est le meilleur moment pour écrire `Pourquoi eux`

Ce qu'on vient de dire en créant l'affaire, ce que le client cherche et pourquoi il l'a demandé, est exactement ce que `Organisations.Pourquoi eux` attend. C'est écrit dans `Notes` de l'affaire, où cela vaut pour **cette vente-là** ; sur l'organisation, cela vaut pour **toutes les suivantes**, et c'est ce qui resservira dans une accroche ou un mail dans six mois.

Écrire seulement si le champ est vide et si l'utilisateur a donné une raison d'affaires, en une ligne et dans ses mots :

```
updateRecords  Organisations  id=7  {"Pourquoi eux": "trois devis par semaine tapés à la main, veulent industrialiser"}
```

Rien ne s'invente à partir du nom de l'affaire.

> **Sur une organisation dont `Pourquoi eux` est vide, ce geste n'est pas facultatif : il fait partie de l'ouverture de l'affaire**, au même titre que la date de clôture. **Le champ se lit à l'étape 2**, avec `Correspondance cible`, précisément pour qu'on sache ici s'il est vide. Deux suites, et une seule est un silence :
>
> - Le besoin exprimé porte sur **l'entreprise**, ce qui chez eux appelle l'offre : la ligne s'écrit dans le même geste. « Il faut un système d'envoi de coupons aux clients selon ce qu'ils ont dépensé l'année dernière » décrit un besoin de l'entreprise, pas un produit du catalogue : ça s'écrit.
> - L'utilisateur n'a dit que **ce qu'il achète**, « une formation deux jours », « un audit » : la question se pose **une fois**, dans la phrase de confirmation, « et chez eux, qu'est-ce qui appelle ça ? ». Sans réponse, on laisse vide et on n'y revient pas.
>
> La différence coûte cher et ne se voit pas : rangée dans les `Notes` de l'affaire, la phrase mourra avec elle ; sur l'organisation, elle resservira dans une accroche ou un mail dans six mois.
>
> **Écrire sur l'organisation ne dispense jamais d'écrire dans les `Notes` de l'affaire.** Les deux champs ne disent pas la même chose et ne se lisent pas au même endroit : `Pourquoi eux` dit pourquoi cette entreprise est dans la base et reste vrai dans six mois ; les `Notes` disent de quoi **cette affaire-là** retourne, changent à chaque étape, et sont **le seul texte que les deux compétences de bilan relisent** quand elles parlent d'une affaire. Le 25 août 2026, la règle ci-dessus a bien rempli `Pourquoi eux` sur les deux affaires ouvertes, et les deux sont sorties avec des `Notes` vides, là où les sept affaires plus anciennes portent toutes leur besoin en clair. **Un correctif qui déplace une information vérifie ce qui vivait à l'ancienne adresse : une affaire sans notes est une ligne de pipeline sans contenu.**

#### Quand l'affaire sort d'un rendez-vous, la question de priorité revient à `enregistrer-echange`

Une même phrase déclenche souvent les deux compétences, « j'étais en RDV chez eux, ils ont tel problème », et **c'est celle-ci qui écrit en dernier**, donc celle dont la phrase de confirmation part vers l'utilisateur. Elle porte donc la question que l'autre a préparée : sur un `RDV` ou un `Appel` dont le contact a une `Priorité` vide, **la confirmation ne part pas sans elle**. Le détail et la formulation sont dans `enregistrer-echange`, ce qui compte ici est de ne pas la laisser tomber entre les deux.

#### Une affaire chez une entreprise marquée hors cible se signale, elle ne se refuse pas

Le cas arrive, et il est intéressant plutôt qu'anormal : une recommandation, un besoin inattendu, une boîte jugée à côté il y a six mois. **L'affaire se crée normalement**, puis une phrase le dit, une seule, sans insister :

> C'est ouvert. Petite chose : cette boîte est notée comme à côté de ce que tu cherches. Ça arrive, dis-moi juste s'il faut la reclasser.

Deux suites, et les deux sont bonnes : l'utilisateur reclasse l'entreprise, et on écrit `Correspondance cible` ; ou il confirme que c'est une exception, et **on n'écrit rien du tout**, y compris pas `À qualifier`. Ne jamais reposer la question à l'affaire suivante chez la même entreprise.

**Sur `À qualifier`, la même phrase, plus courte.** Une entreprise qu'on n'avait pas su trancher et chez qui une affaire s'ouvre est une entreprise sur laquelle on en sait maintenant davantage : c'est le moment de le demander. Sur `Cœur de cible` ou `Périphérie`, **ne rien dire** : il n'y a aucune contradiction à signaler, et un commentaire de plus à chaque affaire créée est un formulaire déguisé.

#### Une organisation jamais classée se qualifie ici, et l'âge de la fiche n'y change rien

> **Une organisation dont `Correspondance cible` est vide se qualifie à la première occasion, quelle que soit la compétence et quel que soit l'âge de la fiche. Ouvrir une affaire chez elle est une occasion.** La question nomme les trois rangements et demande la raison dans la même phrase. Une organisation déjà classée ne se requalifie que sur contradiction. **Et l'ancienneté de la fiche n'est jamais une raison de ne pas demander** : une organisation en base depuis trois semaines sans classement n'a pas été classée, elle a été oubliée.

Vide et `À qualifier` restent deux choses différentes, et c'est ce qui distingue ce cas du précédent : `À qualifier` veut dire qu'on a demandé sans trancher, vide veut dire qu'on n'a jamais demandé. **C'est le champ vide qui manquait de déclencheur**, et l'explication donnée à l'écran le 27 août, que la fiche était trop ancienne pour qu'on y revienne, était fausse : rien dans le produit ne prescrit d'abandonner une organisation parce qu'elle attend depuis trois semaines.

### 4. Faire évoluer l'étape

```
updateRecords  Opportunités  id=4  {"Étape": "Proposition", "Montant estimé": 2950}
```

Un devis chiffré est l'occasion de corriger le montant estimé. Le faire dans le même appel.

**Tout changement d'étape réclame `Clôture prévue` si le champ est vide**, et le passage à `Proposition` est le dernier moment où l'oubli est encore rattrapable. C'est là qu'une date de décision est la plus sûre : on vient d'envoyer un chiffre, on sait quand on espère la réponse. La demander en une phrase, « quand est-ce que tu espères une réponse ? », et l'écrire dans le même appel :

```
updateRecords  Opportunités  id=4  {"Étape": "Proposition", "Montant estimé": 2950,
                                    "Clôture prévue": "2026-09-15"}
```

Si l'utilisateur ne sait pas, **proposer une date et le dire**, plutôt que de laisser vide. Ce n'est pas une invention : le champ s'appelle « prévue », et une prévision se corrige. Le laisser vide, en revanche, ne se corrige jamais tout seul : les deux compétences de bilan filtrent le conclu sur ce champ, et **une affaire sans date de clôture n'est comptée nulle part, même gagnée**. Elle ne produit aucune erreur, elle produit un zéro crédible.

**Un passage à `Proposition` crée systématiquement une tâche de relance datée** : une proposition sans relance posée est une affaire perdue par oubli.

```
createRecords  Tâches
{
  "Tâche":     "Relancer sur la proposition site vitrine",
  "Échéance":  "2026-08-25",
  "Priorité":  "Haute",
  "Statut":    "À faire",
  "Contact":       {"Id": 12},
  "Opportunité":   {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Priorité` | Haute · Moyenne · Basse |
| `Statut` | À faire · En cours · Fait · Annulée |

Sans délai annoncé, proposer une semaine plutôt que de laisser le champ vide : une tâche sans échéance ne remonte jamais dans « Ma journée ».

### 5. Clore une affaire

`Gagnée` ou `Perdue` : **toujours demander la raison et la consigner en `Notes`**, à la suite de ce qui s'y trouve déjà. Une ligne suffit : « Perdue, budget reporté à 2027 », « Gagnée, la recommandation de Pierre a fait la différence ».

C'est la matière du bilan annuel, et la seule qui ne se reconstitue pas après coup. Sur une affaire perdue, poser aussi la question de la relance à distance : si l'utilisateur y croit encore, renseigner `Prochaine relance` sur le contact.

**`Clôture prévue` prend la date du jour de la décision**, dans le même appel que l'étape :

```
updateRecords  Opportunités  id=2  {"Étape": "Perdue", "Clôture prévue": "2026-08-19",
                                    "Notes": "<ce qui s'y trouvait déjà, plus la raison>"}
```

> **La prévision devient un fait le jour où elle se réalise ou s'annule.** Le champ porte « prévue » dans son nom et il sert de date **réelle** aux deux compétences de bilan, qui comptent le conclu dessus. Une affaire perdue le 19 août et laissée au 3 septembre ne comptera pas dans le bilan d'août et comptera dans celui de septembre : le taux de transformation est faux **dans les deux mois**, et les deux restent crédibles. C'est le genre d'erreur qui ne se voit jamais.
>
> Sauf si l'utilisateur donne une autre date, celle où la décision a réellement été prise : « il a signé vendredi » vaut le vendredi, pas aujourd'hui. Et le dire en une demi-phrase dans la confirmation, pour qu'il puisse corriger : « l'affaire est refermée au 19 août ».

**Regarder ce qui reste ouvert derrière l'affaire, par un appel filtré :**

```
queryRecords  Tâches  where=(Opportunité,eq,<nom de l'affaire>)~and(Statut,in,À faire,En cours)
```

> **Le compteur de liens `Tâches` ne compte que des liens, jamais des tâches ouvertes.** Il vaut 2 sur une affaire qui porte une tâche faite et une tâche à faire, et proposer « de refermer les deux tâches ouvertes » en nommant celle qui est déjà faite est ce qui s'est produit le 19 août 2026. **Un compteur de liens ne répond pas à une question qui porte un statut** : ce qui reste à faire se lit par une requête filtrée, et le compte et la liste qui l'accompagne sortent du même appel. Si on ne peut pas nommer les lignes, on n'annonce pas de nombre.

**Et proposer de consigner l'échange qui a provoqué la clôture, dans le même tour.** Quand l'information qui fait bouger l'affaire vient visiblement d'une conversation, « Charlotte m'a dit qu'ils avaient trouvé quelqu'un d'autre », la raison va bien en `Notes`, mais **la date et le canal de cette conversation ne sont écrits nulle part**. Dans trois mois, la base dira que l'affaire a été perdue sans dire quand ni comment on l'a appris, et le compteur d'échanges du bilan sous-comptera l'activité réelle. La question part accrochée à la confirmation, jamais reportée : « je note aussi l'appel de Charlotte au journal ? ». C'est `enregistrer-echange` qui écrit, le récit ne va pas en `Notes`.

> **Une tâche qui ne se fera pas se referme en `Annulée`, jamais en `Fait`.** Une visio de présentation abandonnée avec l'affaire n'a pas eu lieu : la marquer faite écrit un événement qui n'a jamais existé, et tout comptage rétrospectif de rendez-vous le comptera. `Fait` est réservé à ce qui a réellement été accompli, y compris quand c'est l'échange en cours qui vient de l'accomplir.
>
> ```
> updateRecords  Tâches  id=7  {"Statut": "Annulée"}
> ```
>
> **L'échéance ne bouge pas**, ni ici ni ailleurs. Elle dit quand la chose était attendue, et une tâche annulée était bel et bien attendue à cette date. Rien dans la base ne prétend plus qu'elle a eu lieu, c'est le `Statut` qui porte cette information.
>
> Le 25 août 2026, faute de cette valeur, une visio prévue au 3 septembre a été marquée `Fait` sur un prospect abandonné le jour même. Le correctif d'alors ramenait la date au jour de la clôture : il limitait les dégâts, il en fabriquait un autre, une présentation datée du 25 août qui n'avait pas eu lieu non plus. `Tâches.Statut` porte `Annulée` depuis le 26 août 2026, schéma v1.7, et cette rustine tombe avec.

**Une affaire close fait basculer son contact.** `Gagnée`, le contact passe `Client` ; `Perdue`, il passe `Dormant`. Et sa `Prochaine relance`, si elle porte encore une date liée à l'affaire qu'on vient de fermer, s'efface ou se reporte à une échéance réelle : laissée telle quelle, elle reviendra dans le briefing du matin réclamer une relance pour une affaire déjà tranchée. Le geste complet est décrit dans `enregistrer-echange`, étape 4, il ne se recopie pas ici.

### 6. Confirmer

Une phrase. « L'affaire site vitrine passe en proposition à 2 950 €, relance posée au 25 août. »

**Sur une clôture, la phrase dit la date retenue et ce qui a basculé avec.** « C'est refermé : l'affaire Perfhomme passe en Perdue au 19 août, Charlotte passe en Dormant et sa relance est enlevée. Une tâche reste ouverte, je la referme aussi ? » Chaque élément de cette phrase est corrigeable par l'utilisateur, et c'est à cela qu'elle sert.

**Si `Montant estimé` est resté vide, la question part avec cette phrase**, accrochée à elle et non reportée à plus tard. « C'est ouvert : affaire formation deux jours pour Toto, étape Proposition, clôture prévue au 3 septembre. Il me manque le montant, même approximatif, sinon l'affaire ne comptera pas dans le pipeline. » C'est le même geste que la demande de coordonnées de `creer-contact`, et il marche pour la même raison : la question arrive quand l'utilisateur a encore le sujet en tête.

---

## Garde-fous

- **Une affaire par sujet vendu, pas une par échange.** Le pipeline doit rester lisible en un coup d'oeil.
- **Ne rien inventer** : ni montant, ni étape. Une affaire « Identifiée » sur laquelle rien n'est sûr vaut mieux qu'une affaire « Proposition » optimiste.
- **Ne jamais inventer un montant, toujours demander un montant.** C'est lui qui fait le pipeline du tableau de bord, le chiffre signé du bilan et l'écart à l'objectif du point stratégique : une affaire sans montant est invisible dans les trois, et le pipeline annoncé au client est alors faux sans qu'il puisse le voir. Ne pas traiter le montant et la date de clôture de deux façons opposées : les deux champs sont facultatifs en base, aucun des deux ne s'abandonne en silence.
- **Une affaire sans `Clôture prévue` n'apparaît dans aucun bilan, même gagnée.** Le champ **se propose dès la création, à toutes les étapes**, et au plus tard au passage en `Proposition`. C'est la seule date qui se propose plutôt que de rester vide, et proposer une prévision datée n'est pas l'inventer : c'est la seule à porter « prévue » dans son nom. Réserver la proposition à `Proposition` laisse passer tout ce qui s'ouvre en `Identifiée`, c'est-à-dire l'essentiel.
- **Ne pas reculer une étape en silence.** Si l'affaire régresse, le dire et demander confirmation : c'est une information commerciale, pas une correction de saisie.
- **Une affaire close porte la date de sa clôture, pas celle qu'on espérait.** `Clôture prévue` est le champ sur lequel les deux bilans comptent le conclu : le jour où l'affaire est tranchée, la prévision devient un fait et se met à jour dans le même appel que l'étape. **Le principe vaut pour tout ce qui se referme, pas seulement pour les affaires** : une tâche passée à `Fait` dont l'événement a eu lieu à une autre date que son `Échéance` corrige les deux champs ensemble, dans `enregistrer-echange`. Une date prévisionnelle laissée sur un objet refermé ne gêne personne le jour même, et fausse tous les comptages qui reliront l'historique.
- **Une contradiction se signale une fois, et le silence de l'utilisateur clôt le sujet.** Une entreprise hors cible chez qui une affaire s'ouvre n'est pas une erreur à corriger : c'est une information à lui rendre. S'il ne reclasse pas, rien ne s'écrit, et la question ne revient pas à l'affaire suivante. **Ce qui se lit à voix haute en signalant la contradiction, c'est la raison écrite dans `Pourquoi eux`**, quand il y en a une : « tu les avais mis de côté parce que ce qu'ils cherchent est trop loin de ce que tu fais, on y va quand même ? ». C'est à ça que sert d'avoir noté la raison, et c'est ce qui distingue un rappel utile d'un rappel qui embête.
- **Un compteur de liens ne répond pas à une question qui porte un statut.** `Tâches` et `Échanges` comptent des liens, pas des tâches ouvertes ni des échanges récents. Tout ce qui porte un statut se lit par un appel filtré, et un nombre ne s'annonce qu'avec la liste qui le justifie.
- **Le récit de l'échange ne va pas ici**, il va dans `enregistrer-echange`. `Notes` porte le contexte durable de l'affaire, pas son journal. **Mais passer la main est un geste, pas une dispense** : quand l'information vient d'une conversation, proposer de la consigner dans le même tour. Un échange tombé dans l'intervalle entre deux compétences est un échange perdu.
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

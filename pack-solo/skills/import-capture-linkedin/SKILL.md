---
name: import-capture-linkedin
description: Mettre à jour la base à partir d'une capture d'écran LinkedIn, liste de relations, invitations acceptées, résultats de recherche. À utiliser quand l'utilisateur colle une image de LinkedIn et veut en récupérer les personnes. Lit l'image, rapproche des contacts existants, crée les manquants.
---

# Importer une capture LinkedIn

Fait entrer en base les personnes visibles sur une capture d'écran LinkedIn, sans doublon, après validation de l'utilisateur.

C'est le mode d'alimentation courant du Pack : robuste par construction, une refonte de l'interface LinkedIn ne casse rien. L'export natif LinkedIn, lui, ne sert **qu'une fois**, à la reprise du stock initial.

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

### 1. Lire l'image

Extraire, pour chaque ligne visible : **prénom, nom, fonction, organisation**. Rien d'autre. Ce que LinkedIn appelle le « titre » mélange souvent fonction et société : les séparer.

Demander d'abord à l'utilisateur ce que montre la capture, car cela change ce qu'on écrira :

| Capture | Ce qu'on en fait |
|---|---|
| Invitations acceptées | Créer les contacts et **tracer un Échange « Invitation acceptée »** |
| Liste de relations | Créer les contacts, sans échange |
| Résultats de recherche | Créer les contacts en `Source: LinkedIn`, sans échange : ce ne sont pas encore des relations |

**Ne rien deviner sur une ligne coupée en bord d'image.** La signaler et l'écarter, plutôt que de compléter un nom au jugé.

### 2. Rapprocher de l'existant

Pour chaque personne, chercher le doublon avant toute écriture :

```
queryRecords  Contacts       where=(Nom complet,like,%le goff%)
queryRecords  Organisations  where=(Nom,like,%odyssee%)
```

La recherche ne tient pas compte de la casse. Quand la lecture du nom est incertaine, élargir sur le seul nom de famille. Rapprocher sur **nom plus organisation**, jamais sur le nom seul.

Sur une capture d'une dizaine de lignes, regrouper les recherches plutôt que d'enchaîner vingt appels : un `like` par nom de famille suffit.

### 3. Afficher le tableau de contrôle. Étape obligatoire

Avant toute écriture, montrer ce qui va se passer, en trois blocs. **Les cinq colonnes ci-dessous sont obligatoires, `Cible` comprise** : un tableau à quatre colonnes n'est pas ce tableau-là.

| | Personne | Organisation | Cible | Décision |
|---|---|---|---|---|
| À créer | Marie Le Goff, Gérante | Odyssée 29 | à demander | Nouveau contact |
| À compléter | Pierre Autret | Super Super | Cœur de cible, déjà su | Fonction manquante, sera ajoutée |
| Doublon probable | M. Legoff | Odyssee 29 | à demander | Même personne que Marie Le Goff ? |

**La colonne « Cible » se remplit toute seule, elle ne se demande pas ici, et elle ne se supprime pas.** Elle affiche ce que la base sait déjà de l'organisation, lu à l'étape 2, et « à demander » pour celles qu'on va créer. Deux valeurs possibles, pas trois : ce que la base porte déjà, ou « à demander ». Elle sert à montrer d'un coup d'oeil **combien de questions vont arriver à l'étape suivante, et sur quelles entreprises** : c'est le seul endroit du parcours où l'utilisateur voit venir la charge avant qu'elle ne tombe. Sur trois profils elle ne coûte rien, sur vingt elle fait la différence entre un tableau qui prépare et un tableau qui décrit. Une organisation déjà qualifiée ne se requalifie pas.

**N'écrire qu'après validation explicite.** La lecture d'image se trompe sur les noms rares, les particules et les accents, et une base polluée ne se nettoie jamais. Cette étape n'est pas une politesse, c'est le garde-fou du skill.

### 4. Écrire

#### Avant d'écrire : une seule question pour tout le lot, organisations et coordonnées

Isoler les personnes dont la capture ne montre aucune entreprise, et **poser une seule question pour l'ensemble**, jamais une par personne. **La même question porte les coordonnées**, dans la même phrase et le même tour :

> Trois de ces personnes n'affichent pas d'entreprise : Thomas Louedoc, X, Y. Tu sais où elles travaillent ? Sans organisation, je ne pourrai plus les rattacher ensuite. Et si tu as leurs adresses de profil LinkedIn sous la main, donne-les moi dans la foulée : la capture ne les montre pas, et sans elles la fiche ne sert qu'à compter.

**La question de la cible voyage dans la même phrase, par entreprise et jamais par personne.** Les organisations nouvelles se listent groupées, et l'utilisateur répond en une ligne :

> Et pour ces quatre boîtes nouvelles : Odyssée 29, CLR Location, SARL L.B.G.E, Perfhomme. Chacune, tu la mets où, au cœur de ce que tu cherches, en périphérie ou plutôt de côté, et qu'est-ce qui te fait dire ça ? Un rangement et un mot par boîte me suffisent, je le note une fois pour toutes.

**Ici aussi, le rangement et la raison partent ensemble.** Demander seulement *si*, « lesquelles sont vraiment ce que tu cherches ? », a une réponse par défaut et ne rapporte qu'un classement. Demander seulement *en quoi* ne rapporte aucun rangement, et oblige à le déduire d'un texte libre. **Mais la question garde son plafond** : un rangement et un mot par boîte suffisent, et rien ne se réclame. Sur un lot de vingt, exiger une phrase par entreprise serait le formulaire que ce mode existe pour éviter.

**Quand il écarte une boîte et dit pourquoi, la raison s'écrit.** C'est la seule chose qu'un import mette dans `Pourquoi eux` : « à côté, ils ne font que du bâtiment » suffit et se note tel quel, à la suite de ce qui s'y trouve déjà. Un « à côté » sans explication s'écrit seul, sans rien réclamer : sur un lot de vingt, réclamer une raison par boîte transforme une question d'une ligne en interrogatoire.

Quand l'utilisateur ne trie qu'une partie du lot, écrire ce qu'il a dit et **laisser vide le reste**, sans réclamer. Vide veut dire qu'on n'a jamais tranché, et la question se reposera un autre jour. Écrire `À qualifier` partout pour faire propre reviendrait à interdire qu'on la repose.

**Ni `Rôle dans la décision`, ni `Priorité`, ni `Pourquoi eux` ne s'écrivent sur un import**, à l'exception ci-dessus. Une capture de relations LinkedIn n'apprend rien de ces trois-là : les déduire d'une fonction en série produirait vingt inférences plausibles et invérifiables d'un coup. Le rôle se propose quand on crée une fiche une par une, dans `creer-contact` ; les deux autres sortent d'un échange.

**Viser `LinkedIn` en premier.** C'est le seul des trois champs qu'un parcours LinkedIn peut plausiblement remplir : l'adresse est dans la barre du navigateur de la page dont l'utilisateur vient de faire la capture. `Email` et `Téléphone` se prennent s'ils viennent, ils ne se réclament pas ligne à ligne.

**Quand aucune organisation ne manque, la question se pose quand même**, sur les seules coordonnées. C'est le seul moment du parcours où elles sont demandées : personne ne les redemandera plus tard, et une fiche sans coordonnée ne se relance pas.

> **Un lot ne pose qu'un seul tour de questions, et c'est celui-ci.** Organisations manquantes, coordonnées et cible partent **dans la même réponse**, quel que soit le nombre de sujets, et on attend une seule fois. Trois tours d'affilée, l'organisation d'untel, puis la cible, puis les profils LinkedIn, c'est un formulaire : chaque aller-retour est une occasion d'abandonner, et découper en trois ce qui tient en un transforme un import de vingt personnes en interrogatoire. C'est exactement ce que le mode lot existe pour éviter. **Une question de plus après coup se pose seulement si la réponse en a ouvert une**, jamais parce qu'on avait gardé un sujet pour après.

Puis écrire, avec ce que l'utilisateur a donné.

#### Ce qu'on lit dans la réponse peut dépasser ce qu'on avait demandé

La question portait sur les organisations, la réponse se lit **en entier**. Elle apporte souvent autre chose au passage : une fonction, une ville, une adresse de profil, une orthographe corrigée. **Tout prendre**, pas seulement ce qu'on était allé chercher.

Puis **réafficher les seules lignes modifiées** du tableau de contrôle, avec les valeurs retenues, avant d'écrire :

| | Personne | Organisation | Fonction |
|---|---|---|---|
| Retenu | Enzo Blanchard | SARL L.B.G.E | Associé gérant |
| Retenu | Fabrice Gérard | CLR Location | Chargé d'affaires |

**Le piège est l'attribution, pas la lecture.** Une fonction citée dans une phrase qui nomme deux personnes se recolle au mauvais nom quand elle figurait déjà à côté de l'autre dans le tableau. Deux lignes réaffichées coûtent une seconde de lecture, et c'est le seul endroit où l'erreur se voit avant d'être en base.

> **L'appel d'écriture part du tableau, pas de la conversation.** Le geste est un seul et il ne se coupe pas en deux : réafficher le tableau complété, avec les valeurs qui vont partir, **puis** écrire dans la foulée, sans nouvelle question et dans la même réponse. Le tableau n'est pas une validation demandée à l'utilisateur, c'est **la source de l'appel** : ce qui n'y figure pas ne s'écrit pas.
>
> Formulé comme un arrêt dans les garde-fous, « tant que les lignes modifiées ne sont pas réaffichées, aucun appel d'écriture ne part », il n'a pas tenu : le 25 août 2026 la trace passe directement de la réponse de l'utilisateur à `Create Records`. **Un arrêt rangé loin de l'étape qui écrit ne se relit pas.** C'est pour cela qu'il vit ici, dans le geste, et non plus dans une liste de principes.
>
> Le risque est le plus fort exactement là où la réponse de l'utilisateur a été riche, une fonction, une entreprise et trois adresses de profil en vrac dans un ordre différent de celui du tableau, c'est-à-dire au moment où l'on se sent le plus sûr d'avoir compris.

> **Un contact créé sans organisation ne se rattache jamais depuis l'assistant.** Sur un import, l'absence d'organisation sur la capture n'est pas une réponse : c'est ce que LinkedIn affiche, pas ce que l'utilisateur sait. Demander pour tout le lot en une fois, accepter « je ne sais pas » et le dire, et ne laisser le lien vide que là. Un indépendant qui facture à son nom prend une organisation à son nom.

**Ne pas bloquer l'import pour autant.** Un lot de quinze relations ne se transforme pas en quinze questions, et un contact non créé est pire qu'un contact sans organisation. Une question, la réponse, puis on écrit.

Les organisations d'abord, puisque les contacts pointent dessus.

```
createRecords  Organisations
{ "Nom": "Odyssée 29", "Source": "LinkedIn", "Correspondance cible": "Cœur de cible" }
```

Valeurs de `Correspondance cible` : Cœur de cible · Périphérie · Hors cible · À qualifier. **Le champ s'omet purement et simplement** quand l'utilisateur n'a rien dit de cette entreprise.

Puis les personnes, plusieurs en un seul appel :

```
createRecords  Contacts
[
  {
    "Prénom": "Marie", "Nom": "Le Goff", "Fonction": "Gérante",
    "Statut relation": "Nouveau", "Source": "LinkedIn",
    "Organisation": {"Id": 7}
  },
  { ... }
]
```

| Champ | Valeurs admises |
|---|---|
| `Statut relation` | Nouveau · À contacter · En discussion · Client · Dormant · Perdu |
| `Source` (Contacts) | LinkedIn · Email · Salon · Réseau · Recommandation · Import Datablist |
| `Source` (Organisations) | Réseau · Salon · Recommandation · LinkedIn · Web · Import Datablist |

- **`Nom complet` ne s'écrit pas** : c'est une formule.
- **Pas d'email ni de téléphone lus sur l'image** : une capture LinkedIn n'en montre pas, et un email déduit d'un modèle `prenom.nom@` est un email faux. **Ce n'est pas une permission de ne pas les demander** : ils se demandent à l'utilisateur, avec la question de lot ci-dessus, et s'écrivent avec ce qu'il donne.
- Sur une fiche existante, compléter avec `updateRecords`, **sans écraser une valeur renseignée** par une valeur lue sur l'image. Deux exceptions, à connaître : l'organisation, qui ne se rattache pas après coup, voir les conventions ci-dessus ; et l'**identité**, quand un profil a été transmis, voir juste en dessous.
- **Les organisations d'abord, les personnes ensuite**, dans cet ordre : le lien vers l'organisation ne s'écrit qu'à la création de la fiche. Sur un lot, cela veut dire un premier appel `createRecords` sur Organisations, puis un second sur Contacts avec les `Id` obtenus.

#### Un profil transmis fait référence sur l'identité

**Dès que l'utilisateur a transmis la capture du profil d'une personne, ce profil fait référence pour son identité, tant qu'il n'est pas explicitement contredit.** Concrètement : ne pas redemander à l'utilisateur les orthographes exactes qui sont lisibles à l'écran. Les corriger, et dire ce qui a été corrigé.

Les champs concernés sont ceux que la personne déclare elle-même : `Prénom`, `Nom`, `Fonction` sur le contact, et `Nom` sur son organisation. Un nom mal orthographié en base vient presque toujours d'une saisie rapide ou d'une fiche créée avant d'avoir vu le profil : le profil est la meilleure source disponible, et redemander ce qui est sous les yeux fait perdre du temps sans rien fiabiliser.

Cela ne déborde pas sur le reste. **Un email, un téléphone, une adresse saisis par l'utilisateur ne se remplacent jamais** par une lecture d'image, et une ligne coupée ou illisible reste écartée et signalée comme partout ailleurs.

**Un nom faux se corrige toujours, c'est un lien faux qui ne se corrige pas.** La distinction est celle du constat sur les liens, et elle est plus favorable qu'il n'y paraît :

- Le nom de l'organisation vit dans l'enregistrement Organisations. Le corriger là par `updateRecords` **le corrige partout**, y compris dans le libellé affiché sur le contact, puisque le lien pointe sur l'enregistrement et non sur son nom. Il n'y a **rien à toucher au lien**.
- Ce qui reste irréparable est autre chose : un contact rattaché à la **mauvaise organisation**, c'est-à-dire au mauvais enregistrement. Là, le lien devrait changer, et il ne peut pas. Le signaler à l'utilisateur plutôt que de tenter une correction qui échouera.

**Les deux cas ne se distinguent pas au nombre de lettres qui changent.** « Crédut Mutuel » vers « Crédit Mutuel » est une faute de frappe. « Crédit Mutuel » vers « Harmonie Mutuelle » est une autre entreprise, donc un mauvais lien, même si le mot « Mutuel » survit. Avant tout `updateRecords` sur le `Nom` d'une organisation, **compter les contacts qu'elle porte** : un enregistrement partagé se renomme pour tout le monde, et personne ne s'en aperçoit.

### 5. Tracer les invitations acceptées

Uniquement pour une capture d'invitations acceptées, un échange par personne :

```
createRecords  Échanges
{
  "Objet":   "Invitation acceptée",
  "Date":    "2026-08-11",
  "Canal":   "LinkedIn",
  "Sens":    "Entrant",
  "Contact": {"Id": 12}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

**La date de l'échange se lit sur la capture.** LinkedIn affiche « Connexion le 17 août 2026 » sous chaque relation : c'est cette date qui va dans le champ `Date`. Sans date lisible, prendre le jour de l'import et le dire. **Ne jamais la déduire** d'une impression de fraîcheur : « des connexions récentes » n'est pas une date.

C'est ce qui permettra plus tard de mesurer le rendement réel de la prospection LinkedIn.

> **Un échange tracé ici entraîne les mêmes conséquences que s'il avait été consigné par le chemin ordinaire.** Une invitation acceptée est un échange **entrant** : elle fait avancer `Statut relation` sur le contact, exactement comme le décrit `enregistrer-echange`, étape 4. La règle ne se recopie pas ici, elle s'applique.
>
> **Une compétence qui écrit dans `Échanges` sans passer par `enregistrer-echange` hérite de ses règles, elle ne les contourne pas.** Les 24 et 25 août 2026, six contacts sont entrés avec leur invitation acceptée du jour et sont restés au statut de départ, sans une seule modification après leur création. Trente minutes plus tard, la compétence de bilan les a annoncés « jamais approchés » et a proposé de les solliciter. **Un champ qu'on n'avance pas ne reste pas faux dans son coin, il propage sa fausseté dans tout ce qui le lit.**

### 6. Enchaîner les captures

Une capture montre une dizaine de lignes : accepter plusieurs images à la suite dans la même session, et **dédoublonner aussi entre les captures**, pas seulement contre la base. Deux images d'une même liste se recouvrent presque toujours d'une ou deux lignes.

### 7. Conclure

Un compte rendu court : combien créés, combien complétés, combien écartés et pourquoi. Puis proposer la suite utile : `accroche-linkedin` pour écrire aux nouvelles relations.

---

## Garde-fous

- **Sur un lot, on qualifie des entreprises, jamais des personnes.** Quatre organisations nouvelles font une question, quinze contacts n'en font aucune. C'est ce qui empêche l'import de devenir un questionnaire, et c'est aussi ce qui empêche de coller une étiquette de valeur sur vingt personnes qu'on n'a jamais eues au téléphone.

- **Aucune écriture avant validation du tableau de contrôle.**
- **Cadre RGPD.** N'entrent en base que nom, fonction, organisation et coordonnées professionnelles. Ce qui a été lu sur un profil pour personnaliser un message reste transitoire, jamais stocké.
- **Ne rien compléter au jugé** : un nom coupé, une société illisible, une ligne floue sont écartés et signalés.
- **La base fait foi sur les coordonnées, le profil transmis fait foi sur l'identité.** Un email ou un téléphone saisi ne se remplace jamais par une lecture d'image. Un nom, un prénom, une fonction ou un nom d'entreprise lus sur un profil que l'utilisateur a transmis corrigent la base, sans lui redemander de les réécrire.
- **Une invitation envoyée n'est pas une invitation acceptée.** Ne tracer un échange que sur une capture qui montre effectivement une acceptation.
- **Un contact créé sans organisation est définitivement orphelin**, le lien ne s'écrivant qu'à la création. L'absence d'entreprise sur la capture ne vaut pas réponse : demander pour tout le lot en une question, et ne laisser le lien vide que sur un « je ne sais pas » de l'utilisateur.
- **Une fiche sans coordonnée est une fiche qu'on ne relancera pas.** L'absence d'email sur une capture n'est pas une absence d'email : c'est ce que LinkedIn affiche, pas ce que l'utilisateur sait. Une question pour le lot, jamais une par personne, jamais aucune.
- **Une réponse de l'utilisateur se lit en entier, et se réaffiche avant d'écrire.** Ce qui dépasse la question posée s'écrit aussi, à condition de le montrer sur la ligne de la bonne personne.
- **Une date vient de la capture ou du jour de l'import**, jamais d'une impression de fraîcheur. Et la raison donnée à l'utilisateur doit être la vraie : « la capture indique le 17 août », pas « les connexions semblent récentes ».
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « tu ne m'as pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un. **Les guillemets sont le signal, pas le mot.** « Il passe à « à contacter » » cite la base ; « il est maintenant dans ceux que tu dois contacter » dit la même chose. Une valeur de liste qui se lit bien en français se **traduit** quand même : c'est de la citer qui trahit, pas de la comprendre.
- **Le nom d'une compétence ne sort pas davantage.** Jamais « je peux m'en occuper via `creer-opportunite` », jamais `pack-solo:` quoi que ce soit, jamais « je vais utiliser la compétence qui… ». Ce sont des rouages, et le client n'a pas acheté des rouages : il a acheté que ça se fasse. On annonce **ce qu'on va faire**, « je peux ouvrir l'affaire avec toi », jamais avec quoi on le fait. Même famille que la règle du dessus, même raison : nommer la mécanique apprend qu'il y a une mécanique à connaître. **Et ce qui s'écrit avant un appel obéit à la même règle que ce qui s'écrit après** : un préambule d'outil, une phrase de transition, une annonce de lecture s'adressent à l'utilisateur au même titre que la réponse. Ni « lire le skill créer-opportunité, notamment l'étape de clôture », ni « reading point-strategique skill », ni « il me manque le milieu du guide, laisse-moi le lire ». Les trois ont été lues à l'écran le 25 août 2026, une passe après que la règle a été déclarée tenue. **Une compétence qui a besoin de lire quelque chose le lit sans le dire.**
- **Rien de la mécanique ne se dit à l'utilisateur, y compris quand elle coince.** Ni le nom d'un outil du connecteur, ni un repli technique, ni une remarque sur la mémoire : « pas d'outil de comptage disponible, je passe par autre chose » n'a rien à faire dans une conversation. Un outil manquant se contourne **en silence** ; seule une base **injoignable** se dit, dans les phrases déjà prévues pour ça. Et **tout ce qui s'adresse à l'utilisateur s'écrit en français**, y compris une simple phrase de transition : une incise en anglais au milieu d'un travail montre la couture, et elle amène le tiret cadratin avec elle.
- **On tutoie l'utilisateur, dans les neuf compétences, toujours.** Pas de vouvoiement, pas d'alternance d'une compétence à l'autre : rien ne trahit plus vite un assemblage de morceaux qu'un assistant qui change de registre au milieu d'une séance. `Comment je parle` ne décide que du ton de ce qui **sort vers un tiers**, un email ou une accroche, et ne change rien à la façon de s'adresser à l'utilisateur.
- **Une personne se nomme toujours avec son entreprise, dans le même segment de phrase.** Jamais une liste d'entreprises d'un côté et une liste de personnes de l'autre, à charge pour l'utilisateur de les apparier : « Benjamin Lemer chez Holl Studio, Jacques Coupliere chez Pain d'épices traiteur ». Deux listes justes séparément forment une phrase fausse dès qu'on les met côte à côte sans les apparier, et c'est arrivé le 25 août 2026 sur l'entreprise même avec qui l'utilisateur venait d'ouvrir une affaire. **L'appariement est le seul moyen de rendre l'erreur visible au moment où elle s'écrit.**
- **Une réponse pose une question, deux au maximum, et jamais sous forme de liste à puces.** Tout ce qui manque part bien dans le même tour, une question repoussée n'étant jamais posée, mais **ce qui n'empêche pas d'écrire se dit sans point d'interrogation** : un point tranché sans certitude s'annonce comme un fait corrigeable, « je l'ai noté comme un rendez-vous, corrige-moi si besoin », et non comme une question de plus. Trois puces interrogatives ne sont pas une conversation, c'est un formulaire, et un formulaire se remplit plus tard, c'est-à-dire jamais. **En cas de doute, la question qui reste est celle qui empêche d'écrire.**
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

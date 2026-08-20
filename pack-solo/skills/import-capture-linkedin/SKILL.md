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
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

---

## Les quatre repères de qualification

Quatre champs disent ce qui mérite le temps de l'utilisateur. Sur l'organisation : `Correspondance cible`, cœur de cible, périphérie, hors cible ou à qualifier, et `Pourquoi eux`, l'argument d'affaires en une ligne. Sur le contact : `Rôle dans la décision`, décideur, prescripteur, utilisateur, relais ou inconnu, et `Priorité`, haute, moyenne, basse ou en veille.

- **On juge la pertinence de l'affaire, jamais la personne.** `Correspondance cible` juge une **entreprise** contre le champ `À qui je le vends` du contexte. `Rôle dans la décision` décrit une **position dans un achat**, celle que l'intéressé assume lui-même en réunion, jamais un trait de caractère. `Priorité` dit dans quel ordre l'utilisateur rappelle, pas ce que les gens valent. Le test qui tranche : ne rien écrire qu'on ne serait pas prêt à lui lire s'il demandait à voir sa fiche.
- **Rien ne s'écrit sans un mot de l'utilisateur.** Ces quatre champs se **proposent**, ils ne se posent jamais d'office, et une proposition non confirmée ne s'écrit pas. Un rôle déduit d'une fonction est une inférence, pas un fait, et elle a le défaut de toutes les inférences : elle sonne juste. Ce qui est obligatoire, c'est de proposer quand on a de quoi le faire, pas d'écrire.
- **Vide et « à qualifier » ne disent pas la même chose.** Vide veut dire qu'on n'a jamais demandé. `À qualifier` et `Inconnu` veulent dire qu'on a demandé et que ce n'est pas tranché. **Ne jamais reposer une question déjà posée** : un champ qui porte l'une de ces deux valeurs se laisse tranquille jusqu'à ce que l'utilisateur en dise quelque chose de neuf.
- **Ces mots se disent en français, jamais en nom de champ.** « Une boîte qui est vraiment votre cible », « c'est lui qui décide », « celle-là, vous la mettez de côté ». Jamais « je passe la correspondance cible à cœur de cible ». C'est la règle du vocabulaire de la base appliquée à ces quatre champs : l'utilisateur a des clients et des priorités, pas des colonnes.
- **Ne jamais trier sur `Priorité`.** NoCoDB trie un single select par ordre alphabétique de la valeur : le tri donnerait basse, en veille, haute, moyenne. On **filtre** sur ce champ, on ne trie pas.

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

Avant toute écriture, montrer ce qui va se passer, en trois blocs :

| | Personne | Organisation | Cible | Décision |
|---|---|---|---|---|
| À créer | Marie Le Goff, Gérante | Odyssée 29 | à demander | Nouveau contact |
| À compléter | Pierre Autret | Super Super | Cœur de cible, déjà su | Fonction manquante, sera ajoutée |
| Doublon probable | M. Legoff | Odyssee 29 | à demander | Même personne que Marie Le Goff ? |

**La colonne « Cible » se remplit toute seule, elle ne se demande pas ici.** Elle affiche ce que la base sait déjà de l'organisation, lu à l'étape 2, et « à demander » pour celles qu'on va créer. Elle sert à montrer d'un coup d'oeil combien de questions vont arriver à l'étape suivante, et sur quelles entreprises. Une organisation déjà qualifiée ne se requalifie pas.

**N'écrire qu'après validation explicite.** La lecture d'image se trompe sur les noms rares, les particules et les accents, et une base polluée ne se nettoie jamais. Cette étape n'est pas une politesse, c'est le garde-fou du skill.

### 4. Écrire

#### Avant d'écrire : une seule question pour tout le lot, organisations et coordonnées

Isoler les personnes dont la capture ne montre aucune entreprise, et **poser une seule question pour l'ensemble**, jamais une par personne. **La même question porte les coordonnées**, dans la même phrase et le même tour :

> Trois de ces personnes n'affichent pas d'entreprise : Thomas Louedoc, X, Y. Savez-vous où elles travaillent ? Sans organisation, je ne pourrai plus les rattacher ensuite. Et si vous avez leurs adresses de profil LinkedIn sous la main, donnez-les moi dans la foulée : la capture ne les montre pas, et sans elles la fiche ne sert qu'à compter.

**La question de la cible voyage dans la même phrase, par entreprise et jamais par personne.** Les organisations nouvelles se listent groupées, et l'utilisateur répond en une ligne :

> Et pour ces quatre boîtes nouvelles : Odyssée 29, CLR Location, SARL L.B.G.E, Perfhomme. Lesquelles sont vraiment ce que vous cherchez, lesquelles sont à côté ? Un mot par boîte me suffit, je le note une fois pour toutes.

Quand l'utilisateur ne trie qu'une partie du lot, écrire ce qu'il a dit et **laisser vide le reste**, sans réclamer. Vide veut dire qu'on n'a jamais tranché, et la question se reposera un autre jour. Écrire `À qualifier` partout pour faire propre reviendrait à interdire qu'on la repose.

**Ni `Rôle dans la décision`, ni `Priorité`, ni `Pourquoi eux` ne s'écrivent sur un import.** Une capture de relations LinkedIn n'apprend rien de ces trois-là : les déduire d'une fonction en série produirait vingt inférences plausibles et invérifiables d'un coup. Le rôle se propose quand on crée une fiche une par une, dans `creer-contact` ; les deux autres sortent d'un échange.

**Viser `LinkedIn` en premier.** C'est le seul des trois champs qu'un parcours LinkedIn peut plausiblement remplir : l'adresse est dans la barre du navigateur de la page dont l'utilisateur vient de faire la capture. `Email` et `Téléphone` se prennent s'ils viennent, ils ne se réclament pas ligne à ligne.

**Quand aucune organisation ne manque, la question se pose quand même**, sur les seules coordonnées. C'est le seul moment du parcours où elles sont demandées : personne ne les redemandera plus tard, et une fiche sans coordonnée ne se relance pas.

Puis écrire, avec ce que l'utilisateur a donné.

#### Ce qu'on lit dans la réponse peut dépasser ce qu'on avait demandé

La question portait sur les organisations, la réponse se lit **en entier**. Elle apporte souvent autre chose au passage : une fonction, une ville, une adresse de profil, une orthographe corrigée. **Tout prendre**, pas seulement ce qu'on était allé chercher.

Puis **réafficher les seules lignes modifiées** du tableau de contrôle, avec les valeurs retenues, avant d'écrire :

| | Personne | Organisation | Fonction |
|---|---|---|---|
| Retenu | Enzo Blanchard | SARL L.B.G.E | Associé gérant |
| Retenu | Fabrice Gérard | CLR Location | Chargé d'affaires |

**Le piège est l'attribution, pas la lecture.** Une fonction citée dans une phrase qui nomme deux personnes se recolle au mauvais nom quand elle figurait déjà à côté de l'autre dans le tableau. Deux lignes réaffichées coûtent une seconde de lecture, et c'est le seul endroit où l'erreur se voit avant d'être en base.

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
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « vous ne m'avez pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un.
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

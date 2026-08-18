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
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`.
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

## Procédure

### 1. Retrouver la personne, si elle est en base

```
queryRecords  Contacts  where=(Nom complet,like,%le goff%)
```

Ce qui sert à personnaliser : fonction, organisation, `Notes`, `Étiquettes`, et un éventuel échange antérieur.

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

> Vous êtes déjà connectés sur LinkedIn, ou c'est encore une invitation à envoyer ? Dans le premier cas je vous fais un message de suite après votre appel, dans le second une note d'invitation, plus courte.

**Le plafond de 300 caractères ne s'applique qu'à la note d'invitation.** Ne pas le faire peser sur un message direct, et ne pas non plus produire 315 caractères en les appelant une invitation.

### 4. Écrire

Règles communes :

- **Pas de pitch.** Une invitation ne vend rien. Elle ouvre une relation.
- Dire **qui on est en une ligne**, tirée de `Qui je suis` et resserrée, **pourquoi cette personne précisément**, et rien d'autre. Ne pas réciter `Ce que je vends` dans une invitation : c'est exactement le pitch que la règle précédente interdit.
- **Aucune question fermée** dans une note d'invitation, aucune demande de rendez-vous.
- **Le ton de `Comment je parle`**, tel que l'utilisateur parle. Ce champ dit le tutoiement ou le vouvoiement et les mots à éviter. Pas de ton corporate.
- **Aucun tiret cadratin**, ni dans le texte produit, ni dans les phrases dites autour. Le remplacer par une virgule ou deux points. L'utilisateur lit les deux, et c'est une signature d'écriture automatique.
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

1. **Le contact d'abord, s'il n'est pas en base.** Le créer selon `creer-contact`, sans en recopier la procédure : **l'organisation avant la personne**, le lien ne s'écrivant qu'à la création. Une personne à qui on vient d'écrire a sa place en base, c'est le lien effectif dont parle l'étape 1.
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

3. **Le dire en une phrase, en nommant la personne.** « C'est noté : Éric Komlan est en base, chez Untel, avec l'invitation envoyée aujourd'hui. » Une consignation muette ne vaut pas mieux qu'une consignation absente : l'utilisateur n'a aucun moyen de voir la différence.

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
| `Statut` | À faire · En cours · Fait |

**Ne pas consigner d'Échange sur des textes seulement préparés** : rien n'est parti, et une trace posée pour un message jamais envoyé pollue durablement le journal. Les deux traces légitimes ont chacune leur moment : l'envoi à l'étape 6, quand l'utilisateur le dit, l'acceptation via `import-capture-linkedin`.

---

## Garde-fous

- **Le skill ne clique jamais et n'envoie jamais.** Il produit un texte, l'utilisateur agit.
- **Rien de scrapé ne va en base.** L'enrichissement de profil sert au message, puis disparaît. **Une seule exception, la correction d'une identité fausse** : nom, prénom, fonction, nom de l'organisation. Ces champs sont ceux que la base porte de plein droit, et un profil transmis en est la meilleure source.
- **Pas d'accroche sans point d'accroche.** Le dire plutôt que de produire du générique.
- **Ne rien inventer sur la personne** : ni un post qu'elle n'a pas écrit, ni une connaissance commune supposée. Une accroche fausse se démasque en une réponse. Ce qui est **lisible sur le profil** n'est pas une invention : un changement de poste que le fil d'expérience date se cite sans réserve.
- **Ne jamais choisir le format en silence** quand la personne est déjà en base. Note d'invitation et message de suite ne se plafonnent pas pareil, et le texte hybride qui sort d'un choix implicite ne convient à aucun des deux.
- **300 caractères sur une note d'invitation**, comptés, pas estimés.
- **Une demande de consignation ne reste jamais sans effet et sans réponse.** Si l'utilisateur dit qu'il a envoyé et qu'on n'écrit pas, il croit la chose faite et rien ne le détrompe. Une erreur bruyante se rattrape, un silence non. En cas d'empêchement, base injoignable ou personne impossible à identifier, le dire et nommer ce qui n'a pas été écrit.
- **Un message qui porte plusieurs demandes se traite en entier.** Une pièce jointe ne remplace pas la phrase qui l'accompagne : traiter la phrase d'abord, l'image ensuite.

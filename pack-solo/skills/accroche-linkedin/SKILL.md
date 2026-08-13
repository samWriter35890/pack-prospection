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

---

## Procédure

### 1. Retrouver la personne, si elle est en base

```
queryRecords  Contacts  where=(Nom complet,like,%le goff%)
```

Ce qui sert à personnaliser : fonction, organisation, `Notes`, `Étiquettes`, et un éventuel échange antérieur.

Si la personne n'est pas en base, ce n'est pas bloquant : l'accroche se prépare à partir de ce que l'utilisateur en dit ou de ce qu'il colle. **Ne pas créer la fiche à ce stade** : on ne remplit la base qu'avec les gens avec qui on a effectivement un lien. La fiche se crée à l'acceptation, par `import-capture-linkedin`.

#### Si un profil est transmis et que la fiche existe déjà, corriger son identité

Le cas est fréquent, parce que l'ordre réel des choses l'impose : la fiche se crée souvent **avant** d'avoir vu le profil, donc avec un nom entendu au téléphone ou lu dans un mail, donc parfois faux.

**Dès que l'utilisateur transmet la capture du profil, elle fait référence pour l'identité, tant qu'elle n'est pas explicitement contredite.** Corriger `Prénom`, `Nom`, `Fonction` sur le contact et `Nom` sur son organisation par `updateRecords`, puis dire en une phrase ce qui a été corrigé. **Ne pas redemander à l'utilisateur des orthographes qui sont lisibles à l'écran** : il vient de les fournir en transmettant l'image.

Corriger le nom de l'organisation dans l'enregistrement Organisations le corrige **partout**, le lien pointant sur l'enregistrement et non sur son nom. En revanche, si le contact est rattaché à la **mauvaise organisation**, c'est le lien qui devrait changer, et un lien ne se met pas à jour : le signaler plutôt que d'essayer.

Ce n'est pas une entorse au cadre RGPD ci-dessous, et il faut savoir pourquoi : nom, fonction et organisation sont précisément les champs que la base a vocation à porter. Corriger une identité fausse n'est pas enrichir une fiche avec du profil, c'est réparer ce qu'elle contient déjà. Le reste du profil, lui, sert au message puis disparaît. Le détail de la manœuvre est dans `import-capture-linkedin`.

### 2. Personnaliser sur du réel

Une accroche ne vaut que par son point d'accroche. Par ordre de force :

1. **Un lien concret** : une connaissance commune, un événement où l'on s'est croisé, une recommandation.
2. **Quelque chose que la personne a publié ou fait** : un post, une annonce, une ouverture, un recrutement.
3. **Un point commun de métier ou de territoire** : même secteur, même bassin, même problème connu.

Si aucun des trois n'est disponible, le dire. Une accroche sans point d'accroche est une accroche générique : elle abîme la réputation de l'expéditeur et il vaut mieux ne pas l'envoyer.

> **Cadre RGPD, non négociable.** Ce qui est lu sur un profil pour personnaliser le message reste **transitoire** : rien de tout cela n'est stocké en base. La base ne porte que les coordonnées professionnelles que l'utilisateur gère légitimement.

### 3. Écrire

Deux formats distincts, à ne pas confondre :

| Situation | Format | Longueur |
|---|---|---|
| Demande de connexion, note jointe | Note d'invitation | **300 caractères maximum**, espaces compris |
| Connexion déjà acceptée, premier message | Message direct | 4 à 6 lignes |

Règles communes :

- **Pas de pitch.** Une invitation ne vend rien. Elle ouvre une relation.
- Dire **qui on est en une ligne**, **pourquoi cette personne précisément**, et rien d'autre.
- **Aucune question fermée** dans une note d'invitation, aucune demande de rendez-vous.
- Le ton de l'utilisateur, tel qu'il parle. Pas de ton corporate.
- **Aucun tiret cadratin.**
- Pas d'emoji sauf si l'utilisateur en utilise habituellement.

Toujours **compter les caractères** d'une note d'invitation et annoncer le compte. Un texte tronqué par LinkedIn se termine au milieu d'un mot, et cela se voit.

Proposer **une version**, puis ajuster sur retour. Pas un catalogue de trois variantes.

### 4. Préparer un lot, s'il y en a un

Quand l'utilisateur prépare une session de prospection, produire un texte par personne, jamais un modèle à trous : c'est précisément ce que le destinataire repère.

Rappeler les plafonds, une fois, sans moraliser :

- Environ **20 à 25 invitations par jour**, **100 par semaine glissante**. Au-delà, LinkedIn restreint le compte.
- **La note personnalisée est contingentée** sur un compte gratuit, et LinkedIn a déjà changé ce quota plusieurs fois. Si l'utilisateur bute dessus, envoyer l'invitation nue et garder le texte pour le premier message après acceptation.

### 5. Poser un rappel, si l'utilisateur le veut

Par défaut, ce skill **n'écrit rien en base**, hors la correction d'identité vue à l'étape 1. Sur demande, une seule écriture utile de plus :

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

Ne pas consigner d'Échange : rien n'a encore été envoyé. La trace se pose à l'acceptation, via `import-capture-linkedin`.

---

## Garde-fous

- **Le skill ne clique jamais et n'envoie jamais.** Il produit un texte, l'utilisateur agit.
- **Rien de scrapé ne va en base.** L'enrichissement de profil sert au message, puis disparaît. **Une seule exception, la correction d'une identité fausse** : nom, prénom, fonction, nom de l'organisation. Ces champs sont ceux que la base porte de plein droit, et un profil transmis en est la meilleure source.
- **Pas d'accroche sans point d'accroche.** Le dire plutôt que de produire du générique.
- **Ne rien inventer sur la personne** : ni un post qu'elle n'a pas écrit, ni une connaissance commune supposée. Une accroche fausse se démasque en une réponse.
- **300 caractères sur une note d'invitation**, comptés, pas estimés.

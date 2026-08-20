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
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre.** Un enregistrement créé sans son lien ne peut plus être rattaché depuis l'assistant.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste, ne jamais traduire ni abréger.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
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

Quatre champs disent ce qui mérite le temps de l'utilisateur. Sur l'organisation : `Correspondance cible`, cœur de cible, périphérie, hors cible ou à qualifier, et `Pourquoi eux`, l'argument d'affaires en une ligne. Sur le contact : `Rôle dans la décision`, décideur, prescripteur, utilisateur, relais ou inconnu, et `Priorité`, haute, moyenne, basse ou en veille.

- **On juge la pertinence de l'affaire, jamais la personne.** `Correspondance cible` juge une **entreprise** contre le champ `À qui je le vends` du contexte. `Rôle dans la décision` décrit une **position dans un achat**, celle que l'intéressé assume lui-même en réunion, jamais un trait de caractère. `Priorité` dit dans quel ordre l'utilisateur rappelle, pas ce que les gens valent. Le test qui tranche : ne rien écrire qu'on ne serait pas prêt à lui lire s'il demandait à voir sa fiche.
- **Rien ne s'écrit sans un mot de l'utilisateur.** Ces quatre champs se **proposent**, ils ne se posent jamais d'office, et une proposition non confirmée ne s'écrit pas. Un rôle déduit d'une fonction est une inférence, pas un fait, et elle a le défaut de toutes les inférences : elle sonne juste. Ce qui est obligatoire, c'est de proposer quand on a de quoi le faire, pas d'écrire.
- **Vide et « à qualifier » ne disent pas la même chose.** Vide veut dire qu'on n'a jamais demandé. `À qualifier` et `Inconnu` veulent dire qu'on a demandé et que ce n'est pas tranché. **Ne jamais reposer une question déjà posée** : un champ qui porte l'une de ces deux valeurs se laisse tranquille jusqu'à ce que l'utilisateur en dise quelque chose de neuf.
- **Ces mots se disent en français, jamais en nom de champ.** « Une boîte qui est vraiment votre cible », « c'est lui qui décide », « celle-là, vous la mettez de côté ». Jamais « je passe la correspondance cible à cœur de cible ». C'est la règle du vocabulaire de la base appliquée à ces quatre champs : l'utilisateur a des clients et des priorités, pas des colonnes.
- **Ne jamais trier sur `Priorité`.** NoCoDB trie un single select par ordre alphabétique de la valeur : le tri donnerait basse, en veille, haute, moyenne. On **filtre** sur ce champ, on ne trie pas.

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

#### Une affaire qui s'ouvre est le meilleur moment pour écrire `Pourquoi eux`

Ce qu'on vient de dire en créant l'affaire, ce que le client cherche et pourquoi il l'a demandé, est exactement ce que `Organisations.Pourquoi eux` attend. C'est écrit dans `Notes` de l'affaire, où cela vaut pour **cette vente-là** ; sur l'organisation, cela vaut pour **toutes les suivantes**, et c'est ce qui resservira dans une accroche ou un mail dans six mois.

Écrire seulement si le champ est vide et si l'utilisateur a donné une raison d'affaires, en une ligne et dans ses mots :

```
updateRecords  Organisations  id=7  {"Pourquoi eux": "trois devis par semaine tapés à la main, veulent industrialiser"}
```

Rien ne s'invente à partir du nom de l'affaire. Si l'utilisateur n'a dit que ce qu'il vend, sans dire pourquoi eux, laisser vide : la question a sa place dans un échange, pas ici.

#### Une affaire chez une entreprise marquée hors cible se signale, elle ne se refuse pas

Le cas arrive, et il est intéressant plutôt qu'anormal : une recommandation, un besoin inattendu, une boîte jugée à côté il y a six mois. **L'affaire se crée normalement**, puis une phrase le dit, une seule, sans insister :

> C'est ouvert. Petite chose : cette boîte est notée comme à côté de ce que tu cherches. Ça arrive, dis-moi juste s'il faut la reclasser.

Deux suites, et les deux sont bonnes : l'utilisateur reclasse l'entreprise, et on écrit `Correspondance cible` ; ou il confirme que c'est une exception, et **on n'écrit rien du tout**, y compris pas `À qualifier`. Ne jamais reposer la question à l'affaire suivante chez la même entreprise.

**Sur `À qualifier`, la même phrase, plus courte.** Une entreprise qu'on n'avait pas su trancher et chez qui une affaire s'ouvre est une entreprise sur laquelle on en sait maintenant davantage : c'est le moment de le demander. Sur `Cœur de cible`, `Périphérie` ou un champ vide, **ne rien dire** : il n'y a aucune contradiction à signaler, et un commentaire de plus à chaque affaire créée est un formulaire déguisé.

### 4. Faire évoluer l'étape

```
updateRecords  Opportunités  id=4  {"Étape": "Proposition", "Montant estimé": 2950}
```

Un devis chiffré est l'occasion de corriger le montant estimé. Le faire dans le même appel.

**Tout changement d'étape réclame `Clôture prévue` si le champ est vide**, et le passage à `Proposition` est le dernier moment où l'oubli est encore rattrapable. C'est là qu'une date de décision est la plus sûre : on vient d'envoyer un chiffre, on sait quand on espère la réponse. La demander en une phrase, « quand espérez-vous une réponse ? », et l'écrire dans le même appel :

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
| `Statut` | À faire · En cours · Fait |

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
queryRecords  Tâches  where=(Opportunité,eq,<nom de l'affaire>)~and(Statut,neq,Fait)
```

> **Le compteur de liens `Tâches` ne compte que des liens, jamais des tâches ouvertes.** Il vaut 2 sur une affaire qui porte une tâche faite et une tâche à faire, et proposer « de refermer les deux tâches ouvertes » en nommant celle qui est déjà faite est ce qui s'est produit le 19 août 2026. **Un compteur de liens ne répond pas à une question qui porte un statut** : ce qui reste à faire se lit par une requête filtrée, et le compte et la liste qui l'accompagne sortent du même appel. Si on ne peut pas nommer les lignes, on n'annonce pas de nombre.

**Et proposer de consigner l'échange qui a provoqué la clôture, dans le même tour.** Quand l'information qui fait bouger l'affaire vient visiblement d'une conversation, « Charlotte m'a dit qu'ils avaient trouvé quelqu'un d'autre », la raison va bien en `Notes`, mais **la date et le canal de cette conversation ne sont écrits nulle part**. Dans trois mois, la base dira que l'affaire a été perdue sans dire quand ni comment on l'a appris, et le compteur d'échanges du bilan sous-comptera l'activité réelle. La question part accrochée à la confirmation, jamais reportée : « je note aussi l'appel de Charlotte au journal ? ». C'est `enregistrer-echange` qui écrit, le récit ne va pas en `Notes`.

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
- **Une affaire close porte la date de sa clôture, pas celle qu'on espérait.** `Clôture prévue` est le champ sur lequel les deux bilans comptent le conclu : le jour où l'affaire est tranchée, la prévision devient un fait et se met à jour dans le même appel que l'étape.
- **Une contradiction se signale une fois, et le silence de l'utilisateur clôt le sujet.** Une entreprise hors cible chez qui une affaire s'ouvre n'est pas une erreur à corriger : c'est une information à lui rendre. S'il ne reclasse pas, rien ne s'écrit, et la question ne revient pas à l'affaire suivante.
- **Un compteur de liens ne répond pas à une question qui porte un statut.** `Tâches` et `Échanges` comptent des liens, pas des tâches ouvertes ni des échanges récents. Tout ce qui porte un statut se lit par un appel filtré, et un nombre ne s'annonce qu'avec la liste qui le justifie.
- **Le récit de l'échange ne va pas ici**, il va dans `enregistrer-echange`. `Notes` porte le contexte durable de l'affaire, pas son journal. **Mais passer la main est un geste, pas une dispense** : quand l'information vient d'une conversation, proposer de la consigner dans le même tour. Un échange tombé dans l'intervalle entre deux compétences est un échange perdu.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « vous ne m'avez pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un.
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

---
name: depouiller-un-test
description: Enregistrer dans la table Recette ce qui s'est passé pendant les requêtes de test jouées dans cette conversation, une ligne par requête, avec les appels faits à la base et les enregistrements écrits, relus dans la base. À utiliser seulement quand l'utilisateur demande explicitement de dépouiller un test, de l'enregistrer dans la recette, ou de noter ce qui s'est passé pendant un test. Un message qui parle d'un test en cours, ou qui donne une consigne de test, ne la déclenche pas : il se joue comme une requête ordinaire.
---

# Dépouiller un test

Dépose dans la table `Recette` **une ligne de faits bruts par requête** jouée : la phrase, la réponse, les appels, les enregistrements relus. Tu ne juges rien : une autre étape le fera, plus tard, ailleurs.

**Ce qui se dépouille** : toutes les requêtes de cette conversation depuis son début, ou depuis la dernière création de lignes `Recette` si elle a eu lieu plus haut.

**Une requête** : un message de l'utilisateur, et tout ce qui suit jusqu'à son message suivant. Chaque message a sa ligne, même une réponse à une question que tu lui as posée : les appels de deux messages ne se mélangent jamais. **Si ton message précédent se terminait par une ou plusieurs questions**, la ligne de ce message de l'utilisateur le dit en tête de `Phrase jouée` : `(suite de la requête <n>) `, puis le message mot pour mot.

---

## Bloc d'appel

1. **Lis d'abord la conversation, en entier, sur toute la période à dépouiller.** Découpe-la en requêtes, numérotées dans l'ordre. Pour chacune, relève chaque appel d'outil d'un connecteur (base, messagerie, tout autre) et chaque enregistrement créé ou modifié dans la base.
2. `getTablesList`, une fois : l'identifiant de `Recette` et le titre de chaque table touchée. Aucun identifiant de table en dur.
3. `getRecord`, une fois pour **chaque** enregistrement créé ou modifié pendant la période, par son `tableId` et son identifiant, sans paramètre `fields`. Une relecture qui échoue s'écrit avec son erreur mot pour mot.
4. `createRecords`, **un seul appel** sur `Recette`, une entrée par requête dans l'ordre : `tableId`, jamais `table`, et l'enveloppe `records: [{"fields": {…}}, {"fields": {…}}]`. Les champs ci-dessous, noms écrits exactement ainsi, accents compris.
5. **Relis les enregistrements renvoyés par la création.** Un champ absent de la réponse n'a pas été écrit : tu le dis.

| Champ | Ce que tu y écris, pour chaque requête | Ce qui le déclenche |
|---|---|---|
| `Compétence` | le nom de la compétence chargée pendant cette requête, tel que la conversation le montre | une compétence visible dans cette requête ; sinon `aucune` |
| `Phrase jouée` | le message de l'utilisateur qui a lancé la requête, mot pour mot, précédé de `(suite de la requête <n>) ` s'il répond à tes questions | toujours |
| `Réponse rendue` | **tout** le texte que tu as écrit **après** ce message de l'utilisateur et **avant** son message suivant, ni plus tôt ni plus tard : des questions posées à la fin de ta réponse restent dans cette ligne, pas dans celle de la suite. Ce texte se recopie mot pour mot, cadre email compris (libellé, objet, corps), tableaux, observations et synthèses compris. Si aucun texte n'a été rendu : `Aucun texte rendu.` Ce champ n'est jamais laissé vide | toujours |
| `Appels faits` | un appel par ligne, dans l'ordre : `connecteur · outil · table · paramètres : <…> · résultat : <…>`. **Paramètres** : filtres, tri, champs demandés, identifiants, tels qu'envoyés. **Résultat** : pour une écriture, les identifiants créés ou modifiés ; pour une lecture d'enregistrements, leur nombre et leurs identifiants ; pour un comptage ou une agrégation, les valeurs rendues ; pour un échec, `erreur : <message mot pour mot>` | au moins un appel dans la requête ; sinon `Aucun.` |
| `Enregistrements écrits` | un enregistrement par ligne. **Sur la première ligne qui l'a créé ou modifié** : `table · Id <n> · Champ = valeur ; …`, **tous** les champs, valeurs **recopiées depuis la réponse de la relecture de l'étape 3**, jamais depuis ce que la conversation a raconté : c'est l'état final ; un champ vide écrit `(vide)`. **Sur une ligne suivante qui l'a aussi touché** : `table · Id <n> · voir la requête <m>`, et rien d'autre | au moins un enregistrement créé ou modifié dans la requête ; sinon `Aucun.` |
| `Joué le` | la date du jour, `AAAA-MM-JJ` | toujours |

Tu n'écris jamais `Cas`, `Version`, `Statut` ni `Jugement`. La base met `Statut` à `Brut` d'elle-même.

Une requête sans aucun appel a sa ligne, comme les autres. La demande de dépouillement elle-même n'est pas une requête et n'a pas de ligne.

---

## Ce qui s'écrit, et ce qui ne s'écrit pas

- **Mot pour mot.** Phrase, réponse et erreurs se recopient sans reformuler, sans résumer, sans corriger une faute. Le contenu d'une compétence chargée n'est pas un texte rendu : il ne s'écrit pas, même sous forme de renvoi entre crochets.
- **Seulement ce que la conversation montre.** Un appel, un identifiant ou un texte que tu ne vois pas ne se reconstitue pas. Un identifiant que tu ne retrouves pas s'écrit `identifiant non visible`.
- **Les appels du dépouillement lui-même ne s'écrivent nulle part** dans `Appels faits`.
- **Aucune conclusion de ta part, nulle part** : ni dans les lignes, ni dans ta réponse. Cette règle vise ce que tu ajoutes, jamais ce que tu recopies : une réponse rendue pendant le test qui contient elle-même un jugement se recopie entière dans `Réponse rendue`. Pas de « conforme », « correct », « erreur de la compétence », « il aurait fallu », « le champ manque parce que ». Si un champ attendu est absent de la relecture, il est simplement absent de `Enregistrements écrits` : c'est le fait, il suffit.
- **Rien d'autre ne s'écrit dans la base.** Tu ne corriges, ne complètes et n'effaces aucun enregistrement, ni des requêtes ni d'une ligne `Recette` déjà créée. Tu ne rejoues aucune requête.
- **Les dates s'écrivent en clair**, `AAAA-MM-JJ`, jamais « aujourd'hui » ni « hier ».

---

## Ce que l'utilisateur voit

**Entre deux appels, tu n'écris rien.** Ton seul texte, une fois l'étape 5 faite, est ce bloc, rempli avec la réponse de la création :

> <n> lignes de recette créées, statut `Brut`. Relues dans la base :
>
> | Id | Phrase jouée | Compétence | Appels | Enregistrements écrits | Non écrit |
> |---|---|---|---|---|---|
> | … | les dix premiers mots, puis `…` | … ou `aucune` | nombre | nombre | les champs envoyés et absents de la réponse, ou `rien` |
>
> Le contenu complet se lit dans la vue `À juger`.

---

## Si la création échoue

Tu dis ce qui est passé et ce qui ne l'est pas, sans chercher de cause :

> Les lignes de recette n'ont pas été créées. Erreur rendue : `<message mot pour mot>`. Les requêtes elles-mêmes ne sont pas touchées. Voici le contenu préparé, à transmettre à SenseAct :

puis, requête par requête, les six champs, chacun dans un bloc de code, pour que rien ne se perde.

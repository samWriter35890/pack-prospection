---
name: identite-entreprise
description: Compléter l'identité publique d'une entreprise déjà dans la base depuis le registre officiel des entreprises, SIRET, adresse, activité, effectif, date de création, dirigeant. À utiliser quand l'utilisateur demande de chercher, vérifier ou compléter la société, l'entreprise, la fiche ou le SIRET d'une organisation, ou dit qu'il lui manque ces éléments pour un devis. Sur demande seulement, une entreprise à la fois. Ne crée aucune organisation.
---

# Identité d'une entreprise

Remplit, depuis l'open data de l'État, les six champs d'identité d'une organisation **déjà en base**, et rien d'autre. Ce geste **complète, il ne crée pas** : une organisation absente de la base se dit en une phrase, « je n'ai pas cette entreprise dans ta base », et rien ne se crée ici. Il ne se déclenche jamais de lui-même à la création d'un contact.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par fenêtre.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Une écriture voyage dans `records`, et chaque enregistrement dans `fields`.** `createRecords` attend `{"records": [{"fields": {…}}]}`, `updateRecords` attend `{"records": [{"id": n, "fields": {…}}]}`, et `deleteRecords` attend `{"records": [{"id": n}]}`. Un enregistrement envoyé à plat échoue **en entier** sur `MCP error -32602: Input validation error`, `"path": ["records"]` puis `["records", 0, "fields"]` : deux blocs rouges sous les yeux de l'utilisateur avant que l'écriture parte, mesurés le 16 septembre 2026. Les blocs écrits plus bas montrent les champs à plat pour se lire, c'est `records[].fields` qui les reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien à la création, et par sa colonne de clé étrangère ensuite.** `updateRecords` sur un **champ de lien** échoue toujours, quelle que soit la forme employée, sur `SQLITE_ERROR: near "(": syntax error` : c'est une limite du connecteur, pas une faute de syntaxe. Mais la même relation porte aussi une **colonne de clé étrangère**, de la forme `nc_<préfixe>___<Table liée>_id`, et **celle-là s'écrit en `updateRecords` comme un champ ordinaire** : `{"nc_h27z___Opportunités_id": 3}` rattache l'enregistrement à l'affaire n° 3, et le lien revient résolu avec son libellé dès la réponse. **Le nom exact de cette colonne se lit dans un `getRecord` sur la table concernée, jamais de mémoire** : le préfixe est propre à chaque base et il change d'un client à l'autre. **Deux conséquences :** créer dans l'ordre reste la bonne façon de faire, un lien posé à la création valant mieux qu'un rattrapage ; et **un lien oublié se répare en une écriture**, sans jamais supprimer ni recréer l'enregistrement.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
- **Les caractères accentués s'écrivent littéralement dans un filtre, jamais échappés.** `(Prénom,like,%fabrice%)` fonctionne. Sur un **nom de colonne**, un échappement de la forme `\uXXXX` échoue bruyamment, `Column alias 'Pr\u00e9nom' not found.`, et se corrige donc tout seul. Sur une **valeur**, il rend `"records": []` **sans aucune erreur** : `(Nom,like,%g\u00e9rard%)` ne trouve pas Gérard et ne le dit pas, ce qui est indiscernable d'une absence. C'est le second échec silencieux du connecteur après `aggregate`, et le plus facile à déclencher, puisque la plupart des noms de personnes et d'entreprises français portent un accent. **Une recherche qui rend zéro résultat sur un terme accentué se rejoue une fois, en ASCII strict, avant de conclure à l'absence.** Un doublon créé sur cette base est indétectable jusqu'au jour où quelqu'un rouvre la table.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.


---

## Procédure

#### Compléter l'identité publique de l'entreprise

Six colonnes de la table Organisations viennent de l'open data et de nulle part ailleurs : `SIRET`, `Adresse`, `NAF`, `Effectifs`, `Création` et `Dirigeant`. `NAF` et `Effectifs` sont la matière contre laquelle `Correspondance cible` se juge ; `SIRET`, `Adresse` et `Dirigeant` rendent l'organisation facturable.

**Le geste est un seul bloc**, la ville et l'attente du « oui » comprises :

```
1. queryRecords  Organisations  where=(Nom,like,%guiho%)  fields=["Nom","Ville","SIRET"]
                                ← toujours. Si SIRET est déjà rempli, le geste s'arrête ici
2. la ville, ou rien.            ← si Ville est vide, la demander à l'utilisateur,
                                   deux mots, avant toute recherche
3. lire la page  https://recherche-entreprises.api.gouv.fr/search
                 ?q=Guiho+Clotures&departement=44&per_page=3
                 ← comme une page web, avec l'outil de lecture de page. Jamais
                   en commande : le bac à sable de l'application n'a pas le
                   réseau, et la commande échoue en rouge avant de se rabattre
                                ← le nom SEUL dans q, la ville JAMAIS dans q,
                                  elle voyage dans departement= ou code_postal=
4. montrer ce qui est rendu, en français, et attendre un « oui »
5. updateRecords Organisations  id=34
{
  "SIRET":     "39061988000029",
  "Adresse":   "ZA des Pedras",
  "NAF":       "25.12Z",
  "Effectifs": "10 à 19",
  "Création":  "1993-04-05"
}
```

> **La ligne 2 fait partie de la recherche, elle ne la précède pas.** Sans ville, le nom seul rapporte le mauvais SIRET avec l'aplomb du bon, et personne ne rouvrira la fiche. Mesuré le 1er septembre 2026 sur les 31 organisations de la base de référence, dont 29 sans ville : `Habil` rend **315 résultats** et le premier s'appelle exactement `HABIL`, à Plaisir dans les Yvelines. Avec `departement=35`, il rend **un seul** résultat, `METIERS DES ENERGIES`, enseigne `HABIL`, à Rennes, c'est-à-dire celui de la base. **Le nom seul ne trouve pas moins, il trouve faux.**
>
> **Et la ville ne se met jamais dans `q`.** Toujours le 1er septembre 2026 : `Perfhomme` rend 23 résultats, `Perfhomme Rennes` en rend **zéro**. Le champ de recherche n'est pas une barre d'adresse, il cherche une dénomination.

**La ligne 4 n'est pas une politesse, c'est la règle du pack appliquée telle quelle** : rien ne s'écrit sans un mot de l'utilisateur, et une identité publique ne fait pas exception. Ce qu'on lui montre tient en une phrase, en français, sans nom de champ :

> Guiho Clôtures, j'en trouve une à Saint-André-des-Eaux, fabrication de portes et fenêtres en métal, créée en 1993, entre 10 et 19 salariés. C'est bien la tienne ?

**Ce qui rend cette question honnête, c'est ce qu'elle affiche.** La commune, l'activité en clair et l'année de création sont les trois choses sur lesquelles l'utilisateur reconnaît son entreprise ou dit non. Un SIRET affiché seul ne se vérifie pas, il se croit.

**Six champs et pas un de plus.** La réponse de l'API est beaucoup plus riche : forme juridique, numéro de TVA, chiffre d'affaires, résultat net. **Ces colonnes n'existent pas dans la base et rien de tout cela ne se recopie**, ni dans un autre champ, ni dans `Notes`.

| Champ de la base | Ce qu'on lit dans le premier résultat | La règle |
|---|---|---|
| `SIRET` | `siege.siret` | Quatorze chiffres, **du texte**. C'est le SIRET **du siège**, jamais celui d'un établissement rendu par un filtre |
| `Adresse` | `siege.adresse`, **coupée avant le code postal** | `ZA DES PEDRAS 44117 SAINT-ANDRE-DES-EAUX` s'écrit `ZA des Pedras`. Le code postal et la commune sont dans `Ville`, et une adresse qui les recopie fera diverger les deux champs |
| `NAF` | `activite_principale` | Forme `25.12Z`, telle quelle |
| `Création` | `date_creation` | `AAAA-MM-JJ`, format déjà celui du champ |
| `Effectifs` | `tranche_effectif_salarie`, traduit | Voir la table ci-dessous |
| `Dirigeant` | `dirigeants[0]` | Voir la règle ci-dessous. **Souvent à ne pas écrire** |

**Les tranches, dix valeurs de la base contre les codes de l'INSEE :**

| Code rendu | Ce qui s'écrit | Code rendu | Ce qui s'écrit |
|---|---|---|---|
| `00` | `0` | `21` | `50 à 99` |
| `01` | `1 à 2` | `22` | `100 à 199` |
| `02` | `3 à 5` | `31` à `53` | `200 et plus` |
| `03` | `6 à 9` | `NN` | voir ci-dessous |
| `11` | `10 à 19` | | |
| `12` | `20 à 49` | | |

**`NN` ne se traduit jamais tout seul en `0`.** La moitié des sociétés actives portent `NN`, et la plupart de celles-là sont marquées non employeur, ce qui veut dire zéro salarié, c'est-à-dire le profil cible du Pack Solo lui-même. **Cela reste une déduction, et une déduction se propose** : `NN` avec `siege.caractere_employeur = "N"` se montre à l'utilisateur comme « aucun salarié déclaré, je note zéro ? », et c'est son « oui » qui écrit `0`. `NN` avec `"O"` **laisse le champ vide**, et rien ne part.

> **Un effectif inconnu laisse `Effectifs` vide.** Jamais `Non renseigné`, qui est un mot d'écran et pas une valeur de base : les cinq organisations du 2 septembre 2026 l'ont reçu en dur, et aucun comptage de champs vides sur cette table n'est plus exploitable depuis.

> **Et le caractère employeur se lit dans `siege`, pas à la racine.** À la racine, `caractere_employeur` est **nul sur tous les enregistrements examinés le 1er septembre 2026**, Odyssée 29, Carrefour Hypermarchés et Airbus Operations compris. Lu là, la règle du dessus ne se déclencherait jamais, en silence.

**`Dirigeant` ne se remplit que si le dirigeant est une personne physique.** `dirigeants[0].type_dirigeant` le dit. Alors, et alors seulement, `prenoms` et `nom` s'écrivent en casse normale, **le premier prénom seulement** : `SAMUEL HENRI MARCEL` et `LÉCRIVAIN` donnent `Samuel Lécrivain`. Trois cas laissent le champ vide, et c'est le cas le plus fréquent sur cette base :

- **`type_dirigeant` vaut `personne morale`** : le dirigeant est une société, `HOLDING COLONNIER` pour Guiho Clôtures, `ALCHIMIE` et `BLOOM` pour Odyssée 29. **Cela ne s'écrit pas dans un champ qui porte un nom de personne**, et cela ne devient jamais une fiche Contact.
- **La liste est vide.**
- **Plusieurs personnes physiques.** Le champ porte **le représentant légal**, pas un annuaire : sans certitude sur lequel des deux, on ne choisit pas.

> **Un dirigeant publié n'est pas un interlocuteur.** C'est un nom d'état civil pris dans un registre, et il porte une année de naissance que **rien n'autorise à écrire en base**. S'il devient réellement l'un des interlocuteurs de l'utilisateur, il prend **en plus** une fiche Contact, par le geste ordinaire de cette compétence, avec ce que l'utilisateur en dit.

**Trois choses que ce geste n'écrit jamais**, et chacune ferme une porte qui se rouvrirait toute seule :

- **Ni `Secteur` ni `Taille`.** La correspondance du code NAF vers la liste `Secteur` et le recouvrement entre `Effectifs` et `Taille` sont deux questions ouvertes, tranchées ailleurs ou pas encore. Une compétence qui trancherait l'une des deux en passant écrirait la règle à l'endroit où personne ne la retrouvera.
- **Ni `Ville` déjà renseignée.** L'open data rend la commune en majuscules sans accent, `LAILLE`, `SAINT-ANDRE-DES-EAUX`. Elle **ne remplace jamais** ce que l'utilisateur a saisi. Sur une organisation dont `Ville` est vide, elle se propose comme le reste, et s'écrit en casse normale.
- **Ni quoi que ce soit sur une société cessée.** `etat_administratif` vaut `C` : on le dit à l'utilisateur en français, « celle que je trouve sous ce nom a fermé, c'est peut-être une homonyme », et **rien ne part en base**. Cas réel, `SENSEACT AVOCATS` le 1er septembre 2026.

> **Le nom rendu doit porter le nom cherché, sinon on ne propose pas, on montre.** L'API cherche une dénomination légale et des enseignes déclarées, pas une marque, **et elle est floue** : elle ne rend pas zéro quand elle ne trouve pas, elle rend autre chose. Mesuré le 1er septembre 2026 : `Cabinet Dupont Conseil` rend en premier `YOUR ENGLISH WORKSHOP`, `Agence Galopins` rend `GERARD GALOPIN`. **La réponse ne porte aucun score**, il n'y a donc rien à comparer : le seul test qui tranche est textuel, les mots du nom cherché contre ceux de `nom_complet`, `nom_raison_sociale`, `sigle` et `siege.liste_enseignes`, accents, casse et forme juridique mis de côté. Les mots correspondent, on propose. Ils ne correspondent pas, ou plusieurs résultats correspondent, on montre **trois lignes au plus, chacune avec sa commune et son activité**, et on demande. **On ne rattrape jamais un doute à la main.**

**Un résultat qui porte les mots du nom se montre, il ne s'écarte pas.** L'activité, l'effectif et la forme juridique sont **ce qu'on affiche pour que l'utilisateur reconnaisse**, jamais ce sur quoi on tranche à sa place : une SCI, un établissement à zéro salarié ou une activité inattendue sont des lignes de la liste, pas des raisons de les cacher. Dix-sept résultats dont deux portent les mots, c'est **deux lignes montrées**, commune et activité, puis la question. Une seule ligne ne se montre que si une seule porte les mots.

**Un tiers de silence est normal, et se dit sans être promis.** Sur les 31 organisations de la base de référence, interrogées par leur nom seul le 1er septembre 2026, **10 ne rendent rien du tout**, `Holl Studio`, `Cinnacom`, `Pain d'épices traiteur`, `Les Ateliers Défouloirs` et six autres. Ce n'est pas une panne, c'est ce que vaut un nom commercial dans un registre de dénominations. **Une entreprise introuvable se dit en une phrase et ne se poursuit pas** : ni recherche web de rattrapage, ni SIRET reconstitué, ni deuxième question. Les champs restent vides, ce qui est leur état normal.

---

## Garde-fous

- **Ce geste complète une organisation, il n'en crée aucune.** Une organisation absente de la base se dit et s'arrête là. La créer est le geste de la compétence qui crée les contacts, avec la personne qui va avec.
- **Une entreprise à la fois.** Une liste d'organisations n'est pas une demande de ce geste : chaque rapprochement se regarde par l'utilisateur, sur une commune et une activité, et quinze rapprochements d'un coup, c'est quinze SIRET dont aucun n'a été regardé.
- **La recherche part par une lecture de page, jamais par une commande.** Une commande échoue en rouge dans la conversation avant de se rabattre, et le client la voit.

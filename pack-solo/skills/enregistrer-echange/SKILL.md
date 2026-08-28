---
name: enregistrer-echange
description: Consigner une interaction avec un contact, appel, email reçu ou envoyé, message LinkedIn, rendez-vous, SMS. À utiliser dès que l'utilisateur raconte un échange qui vient d'avoir lieu, ou dicte un compte rendu. Crée la trace dans le journal et la tâche de suite si nécessaire. À utiliser aussi pour refermer une tâche accomplie, quand l'utilisateur dit qu'une chose est faite ou demande de la marquer comme faite.
---

# Enregistrer un échange

Transforme un récit parlé en une trace propre dans le journal : un Échange daté, rattaché à la bonne personne et, quand c'est clair, à la bonne affaire. Crée la tâche de suite s'il y en a une.

---

## Conventions d'appel de la base

- **Résoudre les identifiants de table avec `getTablesList`, une fois par session.** Ne jamais écrire un identifiant en dur : il change d'une base à l'autre.
- **Le paramètre qui porte la table s'appelle `tableId`, jamais `table`.** Un appel juste sur tout le reste, filtre, `fields` et tri compris, échoue **en entier** sur `MCP error -32602: Input validation error`, avec `"path": ["tableId"], "message": "Required"`. Les appels écrits plus bas nomment la table en clair pour se lire, c'est la clé `tableId` qui la reçoit.
- **Les noms de champs s'écrivent exactement comme dans la base, accents compris.** En lecture, un nom inconnu échoue bruyamment : `Column alias 'Echeance' not found.` **En écriture, il est ignoré en silence** : les autres champs passent, celui-là reste vide, et rien ne le signale.
- **Relire l'enregistrement renvoyé après chaque écriture.** C'est le seul garde-fou contre une faute de frappe sur un nom de champ, et il ne coûte aucun appel : la réponse contient déjà l'enregistrement complet.
- **Ce qui s'annonce à l'utilisateur se lit sur l'enregistrement relu, jamais sur l'appel envoyé.** Un champ ne se nomme dans une phrase de confirmation qu'après être revenu **rempli** dans la réponse. Le 25 août 2026, « Frères Boyer est classée cœur de cible avec sa raison » a été dit à l'écran alors que le champ est resté vide, et la compétence de bilan a compté une entreprise classée de trop quarante minutes plus tard. **Un champ annoncé et absent est pire qu'un champ absent** : il éteint la seule vérification que l'utilisateur pouvait faire, et le mensonge se propage ensuite dans les chiffres.
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre**, l'organisation avant le contact, l'affaire avant l'échange qui la vise. Un lien oublié ne se corrige qu'en supprimant et recréant l'enregistrement, ce qui est sans risque pour un échange et destructeur pour un contact.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste, ne jamais traduire ni abréger.
- **Filtrer côté requête**, jamais en rapatriant la table. Syntaxe `(champ,opérateur,valeur)`, combinée par `~and` et `~or`.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.
- **Un filtre ne traverse pas un lien.** `(Organisation.Correspondance cible,eq,Cœur de cible)` sur Contacts échoue sur `Column alias 'Organisation.Correspondance cible' not found.` Il n'existe aucune syntaxe de traversée dans ce connecteur. Ce qu'un filtre sait faire sur un champ de lien, c'est comparer son **libellé affiché** : `(Organisation,in,Odyssée 29,Super Super)` fonctionne. Une question qui croise une propriété de l'organisation et une propriété du contact se lit donc en **deux appels**, les organisations d'abord. Échec bruyant, donc sans danger.
- **Les caractères accentués s'écrivent littéralement dans un filtre, jamais échappés.** `(Prénom,like,%fabrice%)` fonctionne. Sur un **nom de colonne**, un échappement de la forme `\uXXXX` échoue bruyamment, `Column alias 'Pr\u00e9nom' not found.`, et se corrige donc tout seul. Sur une **valeur**, il rend `"records": []` **sans aucune erreur** : `(Nom,like,%g\u00e9rard%)` ne trouve pas Gérard et ne le dit pas, ce qui est indiscernable d'une absence. C'est le second échec silencieux du connecteur après `aggregate`, et le plus facile à déclencher, puisque la plupart des noms de personnes et d'entreprises français portent un accent. **Une recherche qui rend zéro résultat sur un terme accentué se rejoue une fois, en ASCII strict, avant de conclure à l'absence.** Un doublon créé sur cette base est indétectable jusqu'au jour où quelqu'un rouvre la table.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

---

## Les quatre repères de qualification

Quatre champs disent ce qui mérite le temps de l'utilisateur. Sur l'organisation : `Correspondance cible`, cœur de cible, périphérie, hors cible ou à qualifier, et `Pourquoi eux`, pourquoi cette entreprise est dans la base, en une ligne. Sur le contact : `Rôle dans la décision`, décideur, prescripteur, utilisateur, relais ou inconnu, et `Priorité`, haute, moyenne, basse ou en veille.

- **On juge la pertinence de l'affaire, jamais la personne.** `Correspondance cible` juge une **entreprise** contre le champ `À qui je le vends` du contexte. `Rôle dans la décision` décrit une **position dans un achat**, celle que l'intéressé assume lui-même en réunion, jamais un trait de caractère. `Priorité` dit dans quel ordre l'utilisateur rappelle, pas ce que les gens valent. Le test qui tranche : ne rien écrire qu'on ne serait pas prêt à lui lire s'il demandait à voir sa fiche.
- **Rien ne s'écrit sans un mot de l'utilisateur.** Ces quatre champs se **proposent**, ils ne se posent jamais d'office, et une proposition non confirmée ne s'écrit pas. Un rôle déduit d'une fonction est une inférence, pas un fait, et elle a le défaut de toutes les inférences : elle sonne juste. Ce qui est obligatoire, c'est de proposer quand on a de quoi le faire, pas d'écrire.
- **`Priorité` se lit dans une phrase de l'utilisateur sur lui-même, jamais dans une phrase sur le prospect.** « je le rappelle lundi », « lui c'est le plus urgent », « je le laisse mijoter » se prennent tels quels. « ils ne sont pas prêts », « ils sont en réflexion » sont des faits sur **eux** : ils partent dans `Pourquoi eux` et dans le résumé de l'échange, et ils ne touchent pas la priorité. Dans ce cas, la priorité **se demande dans la même réponse**, avec le rangement, et si l'utilisateur ne répond pas, elle reste vide. **Une priorité déduite est pire que vide et pire qu'`À qualifier`, parce qu'elle a l'air d'une réponse.**
- **Vide et « à qualifier » ne disent pas la même chose.** Vide veut dire qu'on n'a jamais demandé. `À qualifier` et `Inconnu` veulent dire qu'on a demandé et que ce n'est pas tranché. **Ne jamais reposer une question déjà posée** : un champ qui porte l'une de ces deux valeurs se laisse tranquille jusqu'à ce que l'utilisateur en dise quelque chose de neuf.
- **La question de la cible nomme les trois rangements en français, et demande la raison dans la même phrase.** « Frères Boyer, tu les mets où : au cœur de ce que tu cherches, en périphérie, ou plutôt de côté ? Et qu'est-ce qui te fait dire ça ? » Une question qui ne demande que le motif, « qu'est-ce qui te les fait mettre là, chez eux », **ne se comprend pas**, « là » n'ayant aucun référent pour qui ne connaît pas le champ, et surtout **elle ne rapporte pas le rangement** : il faudrait alors le déduire d'une réponse en texte libre, et une classe déduite d'un motif favorable est une invention que personne ne peut vérifier. **Sans rangement explicite dans la réponse de l'utilisateur, rien ne s'écrit dans `Correspondance cible`** : la raison seule remplit `Pourquoi eux` et la correspondance reste vide, ce qui est exactement ce que « vide veut dire jamais demandé » signifie.
- **`Pourquoi eux` porte l'histoire, pas l'état du moment.** Il dit d'abord **pourquoi cette entreprise est entrée dans la base** : ce qui, chez eux, appelle l'offre. Le jour où elle en sort, où elle passe hors cible, **la raison de la sortie s'ajoute à la ligne d'entrée, elle ne la remplace pas** : « trois devis par semaine tapés à la main, veulent industrialiser », puis « écartés le 20 août, ce qu'ils cherchent est trop loin de ce que je fais ». Une entreprise mise de côté sans raison écrite est un travail qu'on refera dans six mois, faute de se souvenir pourquoi on avait dit non. Le test du droit d'accès vaut sur la ligne de sortie comme sur celle d'entrée : une raison d'affaires s'écrit, un jugement sur les gens ne s'écrit pas.
- **Ces mots se disent en français, jamais en nom de champ.** « Une boîte qui est vraiment ta cible », « c'est lui qui décide », « celle-là, tu la mets de côté ». Jamais « je passe la correspondance cible à cœur de cible ». C'est la règle du vocabulaire de la base appliquée à ces quatre champs : l'utilisateur a des clients et des priorités, pas des colonnes.
- **Ne jamais trier sur `Priorité`.** NoCoDB trie un single select par ordre alphabétique de la valeur : le tri donnerait basse, en veille, haute, moyenne. On **filtre** sur ce champ, on ne trie pas.
- **Un nom d'entreprise sous-entendu ne se résout jamais tout seul avant une écriture.** Quand une phrase désigne une entreprise par « l'entreprise », « la boîte », « chez eux », « leur », et que **deux organisations au moins** sont candidates dans la phrase ou dans la conversation, on **s'arrête et on demande laquelle** avant tout appel d'écriture. La personne nommée dans la phrase est le candidat le plus probable, jamais le sujet du tour précédent, mais la probabilité ne suffit pas ici : une organisation reclassée à tort porte une raison écrite qui rend le classement crédible, et personne ne rouvrira la fiche. « Après discussion avec Nicolas Betton, l'entreprise a déjà un CRM » parle de l'entreprise **de Nicolas Betton**, pas de celle dont on parlait il y a deux phrases. Dans le doute, une question de cinq mots : « chez Perfhomme, c'est ça ? »

---

## Procédure

### 1. Identifier la personne

```
queryRecords  Contacts  where=(Nom complet,like,%legoff%)
```

La recherche ne tient pas compte de la casse. Si le nom entendu est incertain, chercher aussi sur les deux champs séparés : `(Nom,like,%goff%)~or(Prénom,like,%marie%)`.

- **Aucun résultat** : la personne n'est pas dans la base. Passer la main à `creer-contact`, puis revenir ici. **Ne jamais écrire un Échange sans contact** : la base l'accepte, et l'échange devient introuvable.
- **Plusieurs résultats** : demander lequel, en citant fonction et organisation. Ne pas deviner.
- **Un résultat** : retenir son `Id`.

### 2. Rattacher à une affaire, si le contexte est clair

```
queryRecords  Opportunités  where=(Contact,eq,Marie Le Goff)  fields=["Nom","Étape","Clôture prévue"]
```

Le filtre sur un champ de lien se fait sur le **libellé affiché** de l'enregistrement lié, ici le nom complet du contact.

- Une seule affaire ouverte et le récit la désigne : rattacher.
- Plusieurs affaires, ou récit ambigu : demander laquelle en une phrase, plutôt que de laisser le lien vide.
- Le récit décrit une affaire qui n'existe pas encore : **passer par `creer-opportunite` d'abord**, puis revenir écrire l'échange avec les deux liens.

> **Cette étape se règle de préférence maintenant, mais elle se rattrape.** Le lien vers l'affaire ne s'écrit qu'à la création : `updateRecords` sur le champ `Opportunité` échoue toujours. Un échange consigné sans son affaire a donc deux conséquences visibles, l'affaire affiche `Échanges = 0` et `tableau-de-bord` la classe à tort parmi les dormantes.
>
> Si l'utilisateur ne sait pas et ne veut pas trancher, écrire l'échange sans lien et **le dire** : « je le rattache à la personne seulement, on rattachera l'affaire quand tu sauras ». C'est une promesse tenable, voir ci-dessous.

#### Rattacher après coup un échange à une affaire

**Un échange est une feuille : rien ne pointe vers lui.** Il se supprime donc et se recrée avec les bons liens sans rien perdre. *Vérifié pour de vrai le 12 août 2026, sur la base de référence : mise à jour du lien refusée, puis suppression et recréation avec les deux liens, et l'affaire est bien repassée à `Échanges = 1`.*

1. **Relire l'échange en entier, sans `fields`.** C'est ce qui va être recopié : tout champ oublié est perdu.
2. `deleteRecords` sur son `Id`.
3. `createRecords` en repassant **tous** les champs relus, plus les deux liens `Contact` et `Opportunité`.
4. Relire la réponse et vérifier que les deux liens sont là.

L'identifiant de l'échange change, ce qui est sans conséquence puisque rien ne le référence. Sa date de création, en revanche, devient celle de la correction : conserver la vraie `Date` de l'échange, qui est le champ qui compte pour le journal.

> **Ce raccommodage ne vaut que pour les échanges.** Un contact, lui, est un **parent** : ses échanges, ses affaires et ses tâches pointent vers lui, et le supprimer les casserait. **Un échange sans affaire est rattrapable, un contact sans organisation ne l'est pas.** D'où la différence de posture entre les deux skills : ici on propose et on accepte un « je ne sais pas encore », dans `creer-contact` on demande le nom de l'entreprise et on insiste.

### 3. Écrire l'échange

> **Rien ne s'écrit avant deux lectures, à chaque fois, y compris quand l'échange ressemble au précédent.** Avant tout `createRecords` sur un échange : relire la date du jour, et interroger la base sur les affaires ouvertes du contact. **Ces deux lectures ne se déduisent jamais de ce qui a déjà été dit dans la conversation.** Un fil ouvert depuis une heure a déjà vu passer des dates et des affaires, et les rejouer de mémoire est exactement la façon dont l'échange n° 50 s'est retrouvé daté de la veille et rattaché à rien. **Si l'une des deux lectures n'a pas été faite dans ce tour-ci, l'écriture ne part pas.**

```
createRecords  Échanges
{
  "Objet":   "Appel de relance sur le devis",
  "Date":    "2026-08-10",
  "Canal":   "Appel",
  "Sens":    "Sortant",
  "Résumé":  "<le récit de l'utilisateur, reformulé, pas résumé à l'os>",
  "Contact":      {"Id": 12},
  "Opportunité":  {"Id": 4}
}
```

| Champ | Valeurs admises |
|---|---|
| `Canal` | Appel · Email · LinkedIn · RDV · SMS · Autre |
| `Sens` | Entrant · Sortant |

- `Objet` : une phrase courte et reconnaissable, c'est ce qui s'affiche dans le journal.
- `Date` : celle de l'échange, pas celle de la saisie. **La date du jour se relit, elle ne se suppose pas.** Avant de convertir « aujourd'hui », « ce matin », « tout à l'heure », « hier », vérifier la date courante. Une session ouverte la veille et poursuivie le lendemain reste sur la date de son ouverture si personne ne la relit.
- **Le sens se lit dans la phrase de l'utilisateur, ou il se demande.** « il m'a appelé », « j'ai été contacté », « il m'a écrit » sont entrants ; « je l'ai appelé », « je lui ai envoyé » sont sortants. « J'ai échangé avec », « j'ai discuté avec », « on s'est vus » ne disent rien et ne se tranchent pas.
- **Quand la phrase ne dit rien, le sens part dans la question du canal, pas dans un tour de plus** : « c'était par quel canal, et c'est toi qui l'as sollicité ou c'est lui qui est venu ? ». Une question, deux champs, aucun tour supplémentaire.
- **`Sens` n'a pas de valeur par défaut**, et aucune heuristique de plausibilité ne la remplace. Un rendez-vous en événement n'est pas plus sortant qu'entrant.
- **Ce qui a été tranché se rend visible** : « je l'ai noté comme un échange que tu as provoqué, corrige-moi si c'est lui qui est venu ».
- `Résumé` : garder ce que l'utilisateur a dit, y compris les détails humains qui serviront dans six mois. C'est la valeur du journal.
- **Aucun tiret cadratin**, voir les garde-fous : l'interdiction vaut pour `Résumé` comme pour la phrase de confirmation.

#### Faire avancer `Statut relation`, à chaque échange consigné

**Cette règle est du chemin normal, pas du bouclage.** Tout échange écrit regarde le `Statut relation` de son contact et le fait avancer s'il est en retard sur la réalité, **qu'une affaire bouge ou non**. Un email de prospection, une invitation LinkedIn, un premier appel ne font bouger aucune affaire : une bascule rangée dans l'étape 4 n'est alors jamais lue. C'est exactement ce qui s'est produit le 19 août 2026, deux contacts laissés à `Nouveau`, l'un après un email parti et une relance posée, l'autre après une invitation envoyée.

| Ce que l'échange vient de faire | `Statut relation` devient |
|---|---|
| Une invitation acceptée, un ajout de relation, rien de plus | `À contacter` |
| Premier échange **sortant** sur un contact `Nouveau` ou `À contacter` | `À contacter` |
| La personne a écrit, appelé ou parlé, échange **entrant** | `En discussion` |

> **Un signal d'ouverture n'est pas une conversation.** Une invitation acceptée dit qu'on peut écrire, pas qu'on s'est parlé. `En discussion` promet à toutes les vues du produit qu'un échange de fond a eu lieu, et le briefing du matin comme le bilan de période lisent cette promesse.

Valeurs admises : Nouveau · À contacter · En discussion · Client · Dormant · Perdu.

```
updateRecords  Contacts  id=15  {"Statut relation": "À contacter"}
```

**Faire avancer, jamais reculer.** Un contact déjà `En discussion`, `Client` ou `Dormant` ne redescend pas sur un échange de plus. Sur un contact que l'on vient de créer dans le même geste, la valeur se pose **à la création** plutôt qu'en deux appels.

Cette écriture-là ne se demande pas : elle ne fait que consigner ce qui vient d'avoir lieu, et elle se dit en incise dans la phrase de confirmation. Les bascules de **fin de cycle**, `Client` et `Dormant`, restent à l'étape 4 : celles-là dépendent d'une affaire, et elles se proposent.

#### Ce que l'échange vient d'apprendre sur la qualification

Un vrai échange apprend trois choses qu'aucune fiche ne sait deviner : **pourquoi cette boîte-là**, **qui décide chez eux**, et **ce que ça vaut la peine de relancer**. C'est le seul moment du pack où ces trois réponses existent, et elles se perdent en une journée si personne ne les écrit.

**Cette étape ne se joue que sur un échange de fond**, c'est-à-dire `RDV` ou `Appel`, entrant ou sortant, où l'on a parlé à quelqu'un. Un email parti, une invitation LinkedIn, un SMS n'apprennent rien de tout cela : sur ces canaux, passer directement à l'étape 4. Rien ne se demande en série, et rien ne se pose sur un échange qu'on consigne en deux mots.

**Ce qui a été dit s'écrit sans rien demander.** Si le récit de l'utilisateur porte déjà la réponse, la prendre et la dire en incise dans la confirmation, exactement comme `Statut relation` :

| Ce que l'utilisateur a raconté | Ce qui s'écrit |
|---|---|
| « ils galèrent avec leurs plannings sur Excel » | `Organisations.Pourquoi eux` : « plannings gérés sur Excel, perte de temps reconnue » |
| « c'est lui qui signe », « il faudra que ça passe par sa associée » | `Contacts.Rôle dans la décision` : `Décideur`, `Relais` |
| « celui-là je le rappelle lundi sans faute » | `Contacts.Priorité` : `Haute` |

**Ce qui n'a pas été dit se demande une fois, et seulement si le champ est vide.** Une seule question, pas trois, et elle porte sur ce qui manque le plus :

> Ce rendez-vous, tu le classes comment pour la suite : à rappeler vite, ou plutôt à laisser mûrir ?

> **Cette question s'attache à la phrase qui annonce ce qui vient d'être écrit, pas à la fin du tour.** Elle part dans la même réponse que la confirmation, comme une puce de plus : « c'est noté, l'affaire est ouverte et le rendez-vous consigné. Jules, tu le classes comment pour la suite : à rappeler vite, ou plutôt à laisser mûrir ? » Une consigne de fin de parcours saute dès que le parcours est long, et un compte rendu de rendez-vous en produit facilement six écritures d'affilée, parfois sur deux compétences. **Sur un `RDV` ou un `Appel` dont le contact a une `Priorité` vide, la confirmation ne part pas sans elle.** C'est le seul des quatre repères qui ne se déduise de rien, ni d'un montant, ni d'une taille, ni d'une correspondance cible : un champ qui ne se déduit de rien et qu'on ne demande jamais est un champ mort.

`Priorité` est du **ressenti**, et c'est voulu : elle sort d'un échange, elle ne se calcule pas. Ne jamais la déduire d'un montant, d'une taille d'entreprise ni d'une correspondance cible. Valeurs : Haute · Moyenne · Basse · En veille.

```
updateRecords  Contacts       id=12  {"Priorité": "Haute", "Rôle dans la décision": "Décideur"}
updateRecords  Organisations  id=7   {"Pourquoi eux": "plannings gérés sur Excel, perte de temps reconnue"}
```

**`Pourquoi eux` s'écrit avec les mots de l'utilisateur, en une ligne, et il vise l'entreprise et pas la personne.** « Ils perdent une demi-journée par semaine sur leurs devis » est un argument d'affaires. « Sympa, ouvert à la discussion » est un jugement sur quelqu'un, et il n'a rien à faire en base : le test est de se demander si on le lirait à voix haute à l'intéressé.

**Un champ déjà rempli ne s'écrase pas sur une impression.** `Pourquoi eux` se complète quand l'échange apporte vraiment du neuf, et dans ce cas la nouvelle ligne s'ajoute à l'ancienne plutôt que de la remplacer. `Priorité`, elle, se réécrit sans état d'âme : c'est un champ du présent.

### 4. Refermer ce que l'échange termine

Un échange n'ajoute pas seulement au journal : il **clôt** presque toujours quelque chose. C'est l'étape qu'on saute, et celle qui laisse derrière elle une tâche fantôme, une affaire figée à une étape périmée et un client rangé dans « à contacter ». L'utilisateur, lui, croit sa base à jour.

Lire les tâches ouvertes de la personne, et de l'affaire quand il y en a une :

```
queryRecords  Tâches  where=(Contact,eq,Marie Le Goff)~and(Statut,in,À faire,En cours)
```

**Trois choses à regarder, dans cet ordre.**

**La tâche que l'échange accomplit.** « J'ai envoyé le devis » referme la tâche « Envoyer le devis ». La nommer, la proposer, attendre le mot de l'utilisateur, puis :

```
updateRecords  Tâches  id=1  {"Statut": "Fait"}
```

**Ce qu'on referme se date à la réalité, pas à la prévision.** Si l'événement a eu lieu à une autre date que l'`Échéance` portée par la tâche, l'échéance se corrige **dans le même appel** : un rendez-vous prévu le 28 et tenu le 24 se referme avec les deux champs, pas avec un seul.

```
updateRecords  Tâches  id=1  {"Statut": "Fait", "Échéance": "2026-08-24"}
```

Le dégât d'une date laissée est différé et discret. Une tâche `Fait` disparaît des listes courantes, donc personne ne verra jamais l'erreur ; en revanche **tout comptage rétrospectif la rangera dans la mauvaise semaine**, et c'est exactement ce que `point-strategique` fait sur les indicateurs `Rendez-vous` et `Échanges sortants`. Même principe que la date de clôture d'une affaire qu'on gagne en avance.

**L'étape de l'affaire.** Un devis parti, une proposition envoyée, un rendez-vous tenu la font bouger. La proposer, jamais la poser seul : une étape est une information commerciale, pas une conséquence mécanique. La bascule appartient à `creer-opportunite`, étape 4, qui pose du même geste la relance obligatoire d'une proposition et réclame la date de clôture prévue. **Sur une clôture, c'est son étape 5 qui s'applique**, et elle date la clôture du jour de la décision : ne pas écrire l'étape ici en laissant la date derrière.

> **Proposer, pas écrire d'office.** Deviner qu'un échange referme une tâche est une inférence, et une tâche fermée à tort disparaît de « Ma journée » sans laisser de trace. Ce qui n'est pas négociable, c'est de **regarder** et de **demander** : rendre la main sans avoir ouvert la liste des tâches est la faute, pas le fait de ne pas avoir écrit.

**Le contact, qui bascule avec son affaire.** C'est la troisième table, et la plus oubliée : `Statut relation` n'est écrit qu'à la création du contact, et `Prochaine relance` n'est jamais effacée. Un contact laissé à `À contacter` derrière une affaire gagnée, avec une relance échue qui dort, **reviendra tout seul dans le briefing du matin** le jour de cette échéance, pour une affaire signée depuis longtemps.

```
updateRecords  Contacts  id=12  {"Statut relation": "Client", "Prochaine relance": null}
```

| Ce que l'échange vient de faire | `Statut relation` | `Prochaine relance` |
|---|---|---|
| L'affaire passe `Gagnée` | `Client` | effacée, ou reportée à la prochaine échéance **réelle** |
| L'affaire passe `Perdue` | `Dormant` | effacée |

Valeurs admises : Nouveau · À contacter · En discussion · Client · Dormant · Perdu. **Ce tableau ne porte que les deux bascules de fin de cycle**, celles qu'une affaire commande. L'avancement ordinaire d'un contact, lui, se fait à chaque échange, sur le chemin normal de l'étape 3, et il ne dépend d'aucune affaire.

> **Effacer une relance, c'est écrire `null` dessus, et le connecteur l'accepte.** Vérifié le 19 août 2026 sur `Contacts.Prochaine relance`, aux deux bouts du cycle, affaire gagnée et affaire perdue. Il n'y a donc pas de repli à prévoir : une relance qui n'a plus lieu d'être **s'efface**, elle ne se reporte pas faute de mieux. Reporter reste possible quand une échéance réelle existe, jamais pour contourner le champ.

 Comme pour l'étape de l'affaire, **proposer plutôt que poser d'office** : la bascule se dit en une incise dans la phrase de confirmation, « je passe Thomas en Client et j'enlève sa relance du 25 », et l'utilisateur peut refuser.

**Ne pas retoucher l'échéance d'une tâche qu'on referme.** Elle dit quand la chose était attendue, pas quand elle a été faite. Une tâche close en retard reste close en retard, et ce retard est une information.

#### Refermer une tâche sans échange à consigner

L'utilisateur dit « c'est fait », ou demande de marquer une tâche comme faite, sans rien raconter à consigner. **C'est ce skill qui écrit**, sans passer par les étapes 1 à 3 : retrouver la tâche, la nommer pour lever toute ambiguïté, et écrire le `Statut`.

```
queryRecords  Tâches  where=(Statut,in,À faire,En cours)~and(Tâche,like,%devis%)
updateRecords  Tâches  id=1  {"Statut": "Fait"}
```

`accueil` et `tableau-de-bord` renvoient ici, parce qu'ils n'écrivent rien. **Plusieurs tâches possibles : demander laquelle**, en les citant avec leur échéance. Fermer la mauvaise est indolore sur le moment et coûteux trois semaines plus tard.

**« Laisse tomber » n'est pas « c'est fait ».** Quand l'utilisateur abandonne une tâche au lieu de l'accomplir, elle se referme en `Annulée`. `Fait` sur une chose qui n'a pas eu lieu est le seul mensonge que la base ne peut plus rattraper ensuite : rien ne distingue à la relecture un devis envoyé d'un devis abandonné. **En cas de doute, demander laquelle des deux**, en une demi-phrase : « je la marque annulée, ou tu l'as faite ? »

```
updateRecords  Tâches  id=1  {"Statut": "Annulée"}
```

### 5. Créer la tâche de suite, s'il y en a une

Si l'échange appelle une action, elle va dans **Tâches**, jamais dans le résumé sous forme de « à faire ». Source unique.

```
createRecords  Tâches
{
  "Tâche":     "Envoyer le devis révisé",
  "Échéance":  "2026-08-12",
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

Sans échéance annoncée, en proposer une plutôt que de laisser le champ vide : une tâche sans date ne remonte jamais dans « Ma journée ».

### 6. Reporter la prochaine relance

Si une date de rappel est évoquée, la porter sur le contact :

```
updateRecords  Contacts  id=12  {"Prochaine relance": "2026-08-17"}
```

C'est ce champ qui fait remonter la personne dans la vue « À relancer » et dans l'accueil du matin. Ne pas l'oublier quand l'utilisateur dit « je le rappelle la semaine prochaine ».

> **Tout échange sortant consigné sans réponse attendue pose `Prochaine relance` et une tâche, quel que soit le chemin par lequel il est arrivé.** Un email, une accroche LinkedIn, un appel sans réponse, un message resté sans suite : la relance ne dépend pas de la compétence qui a rédigé le message, elle dépend de ce que l'échange est. **Une règle qui dépend du chemin d'accès n'est pas une règle du produit**, c'est une règle de l'une de ses portes, et elle ne s'applique qu'à ceux qui passent par là. Sans date donnée par l'utilisateur, en proposer une et le dire, comme pour la date de clôture d'une affaire.

**Et l'inverse est vrai aussi** : une relance qui n'a plus lieu d'être **s'efface**, elle ne se laisse pas expirer. C'est traité à l'étape 4 avec le reste du bouclage.

### 7. Confirmer

Une phrase, pas un tableau. « C'est noté : appel du 10 août avec Marie Le Goff sur le devis, relance posée au 17, et une tâche pour envoyer le devis révisé mercredi. »

**Quand l'échange est daté d'aujourd'hui ou d'hier, la date figure dans la phrase de confirmation**, en clair : « c'est noté, rendez-vous du 27 avec Jean-Claude Duss ». C'est la seule façon pour l'utilisateur de voir une erreur de date au moment où elle est encore corrigeable.

---

## Garde-fous

- **Un Échange sans Contact est un échange perdu.** La base ne l'interdit pas, ce skill si.
- **Une chose à faire va dans Tâches**, jamais dans le texte du résumé.
- **Ne rien inventer** : ni montant, ni date, ni intention que l'utilisateur n'a pas énoncés. Si un champ manque, le laisser vide ou demander.
- **Plusieurs échanges dans un même récit** (« j'ai appelé trois personnes ce matin ») : un enregistrement par personne, pas un fourre-tout. `createRecords` accepte plusieurs enregistrements en un appel.
- **Une tâche se referme sur le mot de l'utilisateur, jamais sur une déduction.** Regarder les tâches ouvertes est obligatoire, les fermer ne l'est pas.
- **Un bouclage qui ne ferme pas les trois tables n'est pas un bouclage.** `Tâches`, `Opportunités`, `Contacts`. Fermer les deux premières et oublier la troisième laisse une relance armée sur un client signé, et c'est le briefing du matin qui la fera exploser.
- **La qualification se demande sur un rendez-vous ou un appel, jamais sur un email ni une invitation.** Un échange de prospection sortant n'apprend rien de ce que ces champs disent, et poser la question à chaque ligne du journal transforme la consignation en formulaire, ce que le pack se vend à éviter.
- **`Priorité` se donne, elle ne se déduit pas.** Aucun montant, aucune taille d'entreprise, aucune correspondance cible ne la produit. C'est le seul champ du pack qui est ouvertement du ressenti, et le déduire d'un chiffre reviendrait à fabriquer le score qu'on s'est interdit.
- **`Statut relation` avance à chaque échange, pas seulement quand une affaire bouge.** Une règle rangée dans le bouclage ne s'applique qu'aux échanges qui déclenchent un bouclage, c'est-à-dire pas à la prospection, c'est-à-dire pas là où le champ sert. Un champ écrit à la création et jamais relu ment à partir du deuxième jour.
- **Rendre la main sans avoir regardé les tâches ouvertes est une faute**, au même titre qu'un échange sans contact. Un échange qui accomplit une tâche et la laisse ouverte fabrique un retard qui n'existe pas.
- **Ne jamais modifier ou supprimer un échange existant** pour « corriger » un contenu : en créer un nouveau, sauf demande explicite de correction. **Une seule exception, le rattachement à une affaire**, qui n'a pas d'autre voie : la procédure de suppression et recréation est décrite à l'étape 2, et elle recopie tous les champs.
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

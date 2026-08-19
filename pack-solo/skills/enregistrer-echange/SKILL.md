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
- **Les dates s'écrivent `AAAA-MM-JJ`.**
- **Un lien s'écrit `{"Id": <numéro>}` sur le champ de lien, et seulement à la création.** `updateRecords` sur un champ de lien échoue toujours, quelle que soit la forme employée : c'est une limite du connecteur, pas une erreur de syntaxe. **Conséquence : créer dans l'ordre**, l'organisation avant le contact, l'affaire avant l'échange qui la vise. Un lien oublié ne se corrige qu'en supprimant et recréant l'enregistrement, ce qui est sans risque pour un échange et destructeur pour un contact.
- **Une valeur hors liste est refusée**, et la réponse rappelle les valeurs valides. Ne jamais inventer une valeur de liste, ne jamais traduire ni abréger.
- **Filtrer côté requête**, jamais en rapatriant la table. Syntaxe `(champ,opérateur,valeur)`, combinée par `~and` et `~or`.
- **`fields` supprime le bruit technique mais vide le libellé des liens** : un champ de lien demandé dans `fields` ne renvoie que son `Id`. Utiliser `fields` quand aucun nom lié n'est utile, l'omettre sinon.
- **Quand la base ne répond pas, dire trois choses et rien de plus** : que la base est injoignable pour l'instant, **ce qui n'a donc pas été écrit**, et qu'on peut réessayer sur un mot. Si la panne persiste, renvoyer vers SenseAct. **Ne jamais diagnostiquer l'hébergement ni demander une manoeuvre technique** : le client n'administre pas son serveur, c'est SenseAct qui l'héberge, et un timeout ne dit pas d'où il vient.

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
- `Date` : celle de l'échange, pas celle de la saisie. « Hier » se convertit.
- `Résumé` : garder ce que l'utilisateur a dit, y compris les détails humains qui serviront dans six mois. C'est la valeur du journal.
- **Aucun tiret cadratin**, voir les garde-fous : l'interdiction vaut pour `Résumé` comme pour la phrase de confirmation.

#### Faire avancer `Statut relation`, à chaque échange consigné

**Cette règle est du chemin normal, pas du bouclage.** Tout échange écrit regarde le `Statut relation` de son contact et le fait avancer s'il est en retard sur la réalité, **qu'une affaire bouge ou non**. Un email de prospection, une invitation LinkedIn, un premier appel ne font bouger aucune affaire : une bascule rangée dans l'étape 4 n'est alors jamais lue. C'est exactement ce qui s'est produit le 19 août 2026, deux contacts laissés à `Nouveau`, l'un après un email parti et une relance posée, l'autre après une invitation envoyée.

| Ce que l'échange vient de faire | `Statut relation` devient |
|---|---|
| Premier échange **sortant** sur un contact `Nouveau` | `À contacter` |
| La personne a répondu, échange **entrant** | `En discussion` |

Valeurs admises : Nouveau · À contacter · En discussion · Client · Dormant · Perdu.

```
updateRecords  Contacts  id=15  {"Statut relation": "À contacter"}
```

**Faire avancer, jamais reculer.** Un contact déjà `En discussion`, `Client` ou `Dormant` ne redescend pas sur un échange de plus. Sur un contact que l'on vient de créer dans le même geste, la valeur se pose **à la création** plutôt qu'en deux appels.

Cette écriture-là ne se demande pas : elle ne fait que consigner ce qui vient d'avoir lieu, et elle se dit en incise dans la phrase de confirmation. Les bascules de **fin de cycle**, `Client` et `Dormant`, restent à l'étape 4 : celles-là dépendent d'une affaire, et elles se proposent.

### 4. Refermer ce que l'échange termine

Un échange n'ajoute pas seulement au journal : il **clôt** presque toujours quelque chose. C'est l'étape qu'on saute, et celle qui laisse derrière elle une tâche fantôme, une affaire figée à une étape périmée et un client rangé dans « à contacter ». L'utilisateur, lui, croit sa base à jour.

Lire les tâches ouvertes de la personne, et de l'affaire quand il y en a une :

```
queryRecords  Tâches  where=(Contact,eq,Marie Le Goff)~and(Statut,neq,Fait)
```

**Trois choses à regarder, dans cet ordre.**

**La tâche que l'échange accomplit.** « J'ai envoyé le devis » referme la tâche « Envoyer le devis ». La nommer, la proposer, attendre le mot de l'utilisateur, puis :

```
updateRecords  Tâches  id=1  {"Statut": "Fait"}
```

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
queryRecords  Tâches  where=(Statut,neq,Fait)~and(Tâche,like,%devis%)
updateRecords  Tâches  id=1  {"Statut": "Fait"}
```

`accueil` et `tableau-de-bord` renvoient ici, parce qu'ils n'écrivent rien. **Plusieurs tâches possibles : demander laquelle**, en les citant avec leur échéance. Fermer la mauvaise est indolore sur le moment et coûteux trois semaines plus tard.

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
| `Statut` | À faire · En cours · Fait |

Sans échéance annoncée, en proposer une plutôt que de laisser le champ vide : une tâche sans date ne remonte jamais dans « Ma journée ».

### 6. Reporter la prochaine relance

Si une date de rappel est évoquée, la porter sur le contact :

```
updateRecords  Contacts  id=12  {"Prochaine relance": "2026-08-17"}
```

C'est ce champ qui fait remonter la personne dans la vue « À relancer » et dans l'accueil du matin. Ne pas l'oublier quand l'utilisateur dit « je le rappelle la semaine prochaine ».

**Et l'inverse est vrai aussi** : une relance qui n'a plus lieu d'être **s'efface**, elle ne se laisse pas expirer. C'est traité à l'étape 4 avec le reste du bouclage.

### 7. Confirmer

Une phrase, pas un tableau. « C'est noté : appel du 10 août avec Marie Le Goff sur le devis, relance posée au 17, et une tâche pour envoyer le devis révisé mercredi. »

---

## Garde-fous

- **Un Échange sans Contact est un échange perdu.** La base ne l'interdit pas, ce skill si.
- **Une chose à faire va dans Tâches**, jamais dans le texte du résumé.
- **Ne rien inventer** : ni montant, ni date, ni intention que l'utilisateur n'a pas énoncés. Si un champ manque, le laisser vide ou demander.
- **Plusieurs échanges dans un même récit** (« j'ai appelé trois personnes ce matin ») : un enregistrement par personne, pas un fourre-tout. `createRecords` accepte plusieurs enregistrements en un appel.
- **Une tâche se referme sur le mot de l'utilisateur, jamais sur une déduction.** Regarder les tâches ouvertes est obligatoire, les fermer ne l'est pas.
- **Un bouclage qui ne ferme pas les trois tables n'est pas un bouclage.** `Tâches`, `Opportunités`, `Contacts`. Fermer les deux premières et oublier la troisième laisse une relance armée sur un client signé, et c'est le briefing du matin qui la fera exploser.
- **`Statut relation` avance à chaque échange, pas seulement quand une affaire bouge.** Une règle rangée dans le bouclage ne s'applique qu'aux échanges qui déclenchent un bouclage, c'est-à-dire pas à la prospection, c'est-à-dire pas là où le champ sert. Un champ écrit à la création et jamais relu ment à partir du deuxième jour.
- **Rendre la main sans avoir regardé les tâches ouvertes est une faute**, au même titre qu'un échange sans contact. Un échange qui accomplit une tâche et la laisse ouverte fabrique un retard qui n'existe pas.
- **Ne jamais modifier ou supprimer un échange existant** pour « corriger » un contenu : en créer un nouveau, sauf demande explicite de correction. **Une seule exception, le rattachement à une affaire**, qui n'a pas d'autre voie : la procédure de suppression et recréation est décrite à l'étape 2, et elle recopie tous les champs.
- **Le vocabulaire de la base reste dans la base.** Ne jamais dire « table », « champ », « enregistrement », « statut », ni citer une valeur de liste entre guillemets dans une phrase adressée à l'utilisateur. Il a des clients, des affaires, des rendez-vous et des objectifs, pas un schéma. « La table Objectifs ne contient aucun objectif actif » se dit « vous ne m'avez pas encore posé d'objectif ». Le pack se vend sur la promesse qu'il n'ouvre jamais NoCoDB : une phrase qui cite le schéma lui apprend qu'il y en a un.
- **Le tiret cadratin est interdit partout, dans les livrables comme dans la conversation.** Ni dans un email, ni dans une accroche, ni dans une note écrite en base, ni dans les phrases dites à l'utilisateur autour du travail. Le remplacer par une virgule ou deux points. C'est la signature d'écriture automatique la plus reconnaissable, et l'utilisateur la lit.

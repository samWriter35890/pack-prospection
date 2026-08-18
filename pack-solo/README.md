# Plugin Pack Solo

Unité de duplication du socle Solo : le client installe **un plugin**, pas une collection de fichiers. Il colle ensuite l'URL de son connecteur NoCoDB, et c'est fini.

Spécification et raisonnement : [../plugin-pack-solo.md](../plugin-pack-solo.md). Schéma de la base : [../modele-base-nocodb.md](../modele-base-nocodb.md).

## État au 18 août 2026

| Skill ou fichier | État |
|---|---|
| `accueil` | Rédigé, **éprouvé et corrigé trois fois**. Lit l'état en quatre appels depuis la v1.7.0 |
| `enregistrer-echange` | Rédigé, **éprouvé et corrigé**. Porte le bouclage des trois tables depuis la v1.7.0 |
| `creer-contact` | Rédigé, **éprouvé et corrigé** |
| `creer-opportunite` | Rédigé, **éprouvé et corrigé** en v1.7.0 |
| `rediger-email` | Rédigé, **éprouvé et corrigé** |
| `accroche-linkedin` | Rédigé, **éprouvé et corrigé** deux fois, en v1.6.0 puis en v1.7.0 |
| `import-capture-linkedin` | Rédigé, **éprouvé et corrigé** le 18 août 2026 |
| `tableau-de-bord` | Rédigé, **éprouvé et corrigé** |
| `point-strategique` | Rédigé le 17 août 2026, **éprouvé et corrigé** deux fois le 18 |
| `.claude-plugin/plugin.json` | Écrit, installation à blanc jouée |
| `.mcp.json` | Écrit, connecteur enregistré et substitution vérifiée |

**Le plugin est complet et le parcours commercial a tourné de bout en bout** le 11 août 2026, sur un prospect fictif purgé ensuite. Deux défauts trouvés à cette occasion, corrigés dans les 7 skills d'action : un nom de champ inconnu est ignoré en silence à l'écriture, et un champ de lien ne se met jamais à jour, il ne s'écrit qu'à la création. Détail dans [../plugin-pack-solo.md](../plugin-pack-solo.md), constats 11 et 12.

**Session de test réelle le 18 août 2026, et sept défauts corrigés en v1.5.0.** Sept compétences sur neuf se sont déclenchées juste, et le défaut de fond était ailleurs : **le plugin savait ouvrir du travail et ne savait pas le refermer.** Aucune des neuf ne savait écrire `Statut: Fait`, et aucune ne revenait sur l'étape d'une affaire après un échange. `enregistrer-echange` porte désormais le bouclage, y compris la clôture d'une tâche sans échange à consigner, et `accueil` comme `tableau-de-bord` y renvoient au lieu d'écrire eux-mêmes. Les six autres défauts et leur preuve sont dans [../recette-v1.4.0.md](../recette-v1.4.0.md). Le plus dangereux n'était pas une erreur : une affaire sans `Clôture prévue` ne compte dans aucun bilan, même gagnée, et produit un **zéro crédible**.

**Deuxième session de test réelle le 18 août 2026, et cinq défauts corrigés en v1.6.0.** Les sept correctifs de la v1.5.0 tiennent, vérifiés en base. Le défaut de fond de cette passe est un **silence** : « consigne tout cela » n'a rien écrit et rien dit, parce que `accroche-linkedin` n'avait aucune étape de consignation et que le message portait deux ordres dont seul le second a été lu. Elle en a une désormais, étape 6, et `accueil` porte le garde-fou transverse des messages à plusieurs demandes. Les quatre autres : les coordonnées n'étaient demandées sur aucun chemin, un texte à envoyer sortait en citation sans bouton copier, une information donnée dans une réponse se recollait au mauvais nom, et le lien de réservation du client n'était lu par personne. Relevé et preuves dans [../recette-v1.5.0.md](../recette-v1.5.0.md).

**Troisième session de test réelle le 18 août 2026, et cinq défauts corrigés en v1.7.0.** Les cinq correctifs de la v1.6.0 tiennent, dont le cas du silence rejoué à l'identique : « c'est envoyé » plus une seconde demande, dans le même message et avec une pièce jointe, et les deux ont été exécutées. Le défaut de fond de cette passe n'est plus un silence, c'est une **affirmation fausse** : le briefing d'ouverture a proposé d'envoyer un devis parti dix heures plus tôt, sur une affaire déjà gagnée, en tirant l'action du résumé d'un vieil échange faute d'avoir la moindre ligne à lire. `accueil` lit désormais les affaires ouvertes, ne prescrit plus rien depuis un échange, et porte les règles de comptage et de dates de `tableau-de-bord`. Les quatre autres : le bouclage oubliait la table `Contacts` et armait une fausse relance à date fixe, le montant d'une affaire n'était demandé sur aucun chemin alors que la date de clôture, elle, se proposait, les chiffres dits en prose n'étaient pas recomptés, et le contact créé par `accroche-linkedin` naissait sans l'adresse LinkedIn sur laquelle on venait de l'inviter. Relevé et preuves dans [../recette-v1.6.0.md](../recette-v1.6.0.md).

**Neuvième compétence ajoutée le 17 août 2026**, `point-strategique`, avec le passage du schéma en v1.3 : deux tables de cadrage, `Contexte` et `Objectifs`. Quatre compétences lisent désormais le contexte du client une fois par session, et `point-strategique` compare les objectifs au réel **sans jamais combler un objectif absent**. Sa frontière avec `tableau-de-bord` a été écrite avant elle : [../eprouver-le-declenchement.md](../eprouver-le-declenchement.md).

Restent hors du plugin : le cheat-sheet client et le canal de mise à jour.

Chacun est déclenchable directement ou depuis `accueil`. Les trois premiers forment la chaîne minimale : ouvrir sa journée, consigner un échange, faire entrer une personne inconnue.

Chaque skill d'action rappelle en tête le même bloc « Conventions d'appel de la base ». **C'est volontaire** : un skill se charge seul, sans garantie qu'un autre soit en contexte. La duplication est le prix de l'autonomie. Si ce bloc change, il change dans les huit. **Le bloc « Le contexte du client, lu une fois par session » est le second bloc délibérément dupliqué**, depuis le 17 août 2026, dans quatre skills seulement : `accueil`, `accroche-linkedin`, `rediger-email` et `creer-opportunite`. Il lit **dix champs** depuis la v1.6.0, `Lien de réservation` compris : deux skills seulement s'en servent, et les quatre le lisent, sans quoi le premier appelé priverait les suivants du champ pour toute la session.

## Règles qui gouvernent ce dossier

- **Aucun identifiant de table en dur.** Les identifiants changent d'une base client à l'autre : chaque skill les résout par `getTablesList`, une fois par session.
- **Aucun secret ici, ni dans aucun fichier de configuration.** L'URL du connecteur est demandée au client à l'activation, par le `userConfig` marqué `sensitive` du manifeste, et rangée dans le **Trousseau macOS**. Le `.mcp.json` n'en porte que la substitution, `${user_config.url_connecteur_nocodb}`. Cette URL tient lieu de mot de passe de la base : elle ne doit apparaître ni dans le dépôt, ni dans un partage d'écran, ni dans une conversation.
- **`accueil` ne contient jamais de procédure.** Il oriente et cite les autres skills par leur nom.
- **Aucune procédure d'appel MCP écrite sans aller-retour réel** sur l'outil concerné, contre la base de référence « Pack solo ». Les constats observés sont consignés dans [../plugin-pack-solo.md](../plugin-pack-solo.md).

## Installer chez un client

Le plugin s'installe depuis un marché, pas par copie de fichiers. **Chez un client, il ne s'installe pas depuis ce marché** : vérifié le 12 août 2026, l'application Claude refuse une forge auto-hébergée comme source. Le client reçoit une **archive fabriquée pour lui** par `../construire-livraison.sh --client <nom>`, et la téléverse. Ce marché sert au poste de SenseAct et à la ligne de commande.

La cible client est **Claude Desktop**, où Chat et Cowork sont deux positions d'une bascule du composeur : `Customize`, onglet `Plugins`, ajouter le marché par son dépôt git, puis installer. La procédure en ligne de commande ci-dessous est celle du poste de SenseAct, et sert de recette de contrôle.

1. `claude plugin marketplace add <le marché>`
2. `claude plugin install pack-solo@<le marché>`, ou l'installer depuis `/plugin` dans l'application.
3. À l'activation, **l'URL du connecteur NoCoDB** de ce client est demandée. C'est le seul geste de configuration. Éprouvé en ligne de commande, **pas encore dans l'onglet Plugins de l'application** : voir [../plugin-pack-solo.md](../plugin-pack-solo.md), section « Où le plugin s'installe ».
4. Vérifier : `claude plugin details pack-solo` doit annoncer 9 skills et 1 serveur MCP, et `claude mcp list` doit joindre `plugin:pack-solo:nocodb`.

> **`claude mcp list` affiche l'URL du connecteur en clair.** Ne pas la lancer en partage d'écran, ni dans une session dont la transcription est conservée. `claude plugin details` suffit pour la vérification courante, et ne montre rien de sensible.

Puis ouvrir une session et dire simplement bonjour : `accueil` doit se déclencher seul et lire la base.

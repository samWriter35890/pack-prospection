# Plugin Pack Solo

Unité de duplication du socle Solo : le client installe **un plugin**, pas une collection de fichiers. Il colle ensuite l'URL de son connecteur NoCoDB, et c'est fini.

Spécification et raisonnement : [../plugin-pack-solo.md](../plugin-pack-solo.md). Schéma de la base : [../modele-base-nocodb.md](../modele-base-nocodb.md).

## État au 11 août 2026

| Skill ou fichier | État |
|---|---|
| `accueil` | Rédigé, **éprouvé** |
| `enregistrer-echange` | Rédigé, **éprouvé et corrigé** |
| `creer-contact` | Rédigé, **éprouvé et corrigé** |
| `creer-opportunite` | Rédigé, **éprouvé et corrigé** |
| `rediger-email` | Rédigé, **éprouvé et corrigé** |
| `accroche-linkedin` | Rédigé, corrigé, **non éprouvé** (demande une capture d'écran) |
| `import-capture-linkedin` | Rédigé, corrigé, **non éprouvé** (demande une capture d'écran) |
| `tableau-de-bord` | Rédigé, **éprouvé** |
| `.claude-plugin/plugin.json` | Écrit, installation à blanc jouée |
| `.mcp.json` | Écrit, connecteur enregistré et substitution vérifiée |

**Le plugin est complet et le parcours commercial a tourné de bout en bout** le 11 août 2026, sur un prospect fictif purgé ensuite. Deux défauts trouvés à cette occasion, corrigés dans les 7 skills d'action : un nom de champ inconnu est ignoré en silence à l'écriture, et un champ de lien ne se met jamais à jour, il ne s'écrit qu'à la création. Détail dans [../plugin-pack-solo.md](../plugin-pack-solo.md), constats 11 et 12.

Restent hors du plugin : le cheat-sheet client et le canal de distribution.

Chacun est déclenchable directement ou depuis `accueil`. Les trois premiers forment la chaîne minimale : ouvrir sa journée, consigner un échange, faire entrer une personne inconnue.

Chaque skill d'action rappelle en tête le même bloc « Conventions d'appel de la base ». **C'est volontaire** : un skill se charge seul, sans garantie qu'un autre soit en contexte. La duplication est le prix de l'autonomie. Si ce bloc change, il change dans les sept.

## Règles qui gouvernent ce dossier

- **Aucun identifiant de table en dur.** Les identifiants changent d'une base client à l'autre : chaque skill les résout par `getTablesList`, une fois par session.
- **Aucun secret ici, ni dans aucun fichier de configuration.** L'URL du connecteur est demandée au client à l'activation, par le `userConfig` marqué `sensitive` du manifeste, et rangée dans le **Trousseau macOS**. Le `.mcp.json` n'en porte que la substitution, `${user_config.url_connecteur_nocodb}`. Cette URL tient lieu de mot de passe de la base : elle ne doit apparaître ni dans le dépôt, ni dans un partage d'écran, ni dans une conversation.
- **`accueil` ne contient jamais de procédure.** Il oriente et cite les autres skills par leur nom.
- **Aucune procédure d'appel MCP écrite sans aller-retour réel** sur l'outil concerné, contre la base de référence « Pack solo ». Les constats observés sont consignés dans [../plugin-pack-solo.md](../plugin-pack-solo.md).

## Installer chez un client

Le plugin s'installe depuis un marché, pas par copie de fichiers. **Le canal de distribution n'est pas encore arrêté** : un dépôt de marché privé reste à créer.

La cible client est l'**application Claude**, onglet Chat : `Customize`, onglet `Plugins`, ajouter le marché par son dépôt git, puis installer. La procédure en ligne de commande ci-dessous est celle du poste de SenseAct, et sert de recette de contrôle.

1. `claude plugin marketplace add <le marché>`
2. `claude plugin install pack-solo@<le marché>`, ou l'installer depuis `/plugin` dans l'application.
3. À l'activation, **l'URL du connecteur NoCoDB** de ce client est demandée. C'est le seul geste de configuration. Éprouvé en ligne de commande, **pas encore dans l'onglet Plugins de l'application** : voir [../plugin-pack-solo.md](../plugin-pack-solo.md), section « Où le plugin s'installe ».
4. Vérifier : `claude plugin details pack-solo` doit annoncer 8 skills et 1 serveur MCP, et `claude mcp list` doit joindre `plugin:pack-solo:nocodb`.

> **`claude mcp list` affiche l'URL du connecteur en clair.** Ne pas la lancer en partage d'écran, ni dans une session dont la transcription est conservée. `claude plugin details` suffit pour la vérification courante, et ne montre rien de sensible.

Puis ouvrir une session et dire simplement bonjour : `accueil` doit se déclencher seul et lire la base.

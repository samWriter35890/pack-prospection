# Marché des plugins SenseAct

Ce dépôt distribue les plugins SenseAct pour l'assistant Claude. Il en contient un aujourd'hui : **Pack Solo**.

SenseAct est une agence d'automatisation et d'IA pour TPE et PME, basée à Rennes. [senseact.fr](https://senseact.fr)

## Pack Solo

Un assistant commercial pour indépendants et très petites structures. Il tient vos contacts, consigne vos échanges, suit vos affaires, prépare vos relances et vos messages, et vous rend un bilan de période. Vos données restent dans **votre** base NoCoDB, hébergée en France.

Le plugin apporte dix compétences, qui se déclenchent d'elles-mêmes quand vous formulez le besoin en langage courant. Il n'y a aucune commande à retenir.

## Installer

Ce dépôt est un marché de plugins. L'installation se fait en deux temps : ajouter le marché, puis installer le plugin.

**Dans l'application Claude :** ouvrez `Customize`, onglet `Plugins`, « Ajouter une place de marché », et collez l'adresse de ce dépôt :

```
https://github.com/samWriter35890/pack-prospection
```

Laissez « Synchroniser automatiquement » activé, puis installez **Pack Solo** et activez-le.

**En ligne de commande, avec Claude Code :**

```
claude plugin marketplace add https://github.com/samWriter35890/pack-prospection
claude plugin install pack-solo@senseact
```

Le clonage ne demande aucun identifiant.

## Ce qu'il faut en plus du plugin

Le plugin seul ne fait rien : il a besoin de **votre base de données**, créée par SenseAct lors de la mise en place, et d'un **compte** sur cette base, que SenseAct vous ouvre par invitation. À la première utilisation, Claude vous demande de vous connecter à ce compte et de choisir votre base : c'est le seul geste de raccordement, et il se fait une fois.

Si vous êtes arrivé ici sans être client, le plugin ne vous servira à rien en l'état. Écrivez-nous plutôt : [contact@senseact.fr](mailto:contact@senseact.fr)

## Mettre à jour

Les mises à jour sont annoncées par SenseAct. Dans l'application, elles s'appliquent d'elles-mêmes si la synchronisation automatique est activée, et sinon par le bouton « Mettre à jour » de la fiche du plugin. En ligne de commande :

```
claude plugin marketplace update
claude plugin update pack-solo
```

Un redémarrage de l'assistant est nécessaire pour qu'une mise à jour prenne effet.

## Licence

Tous droits réservés. Voir [LICENSE](LICENSE). Le fait que ce dépôt soit clonable sans identifiant ne le rend pas libre de réutilisation.

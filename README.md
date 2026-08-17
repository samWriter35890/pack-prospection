# Marché des plugins SenseAct

Ce dépôt distribue les plugins SenseAct pour l'assistant Claude. Il en contient un aujourd'hui : **Pack Solo**.

SenseAct est une agence d'automatisation et d'IA pour TPE et PME, basée à Rennes. [senseact.fr](https://senseact.fr)

## Pack Solo

Un assistant commercial pour indépendants et très petites structures. Il tient vos contacts, consigne vos échanges, suit vos affaires, prépare vos relances et vos messages, et vous rend un bilan de période. Vos données restent dans **votre** base NoCoDB, hébergée en France.

Le plugin apporte 9 compétences, qui se déclenchent d'elles-mêmes quand vous formulez le besoin en langage courant. Il n'y a aucune commande à retenir.

## Installer

Ce dépôt est un marché de plugins. L'installation se fait en deux temps : ajouter le marché, puis installer le plugin.

**Dans l'application Claude ou sur le web :** ouvrez `Customize`, onglet `Plugins`, et ajoutez ce dépôt comme source :

```
https://forge.senseact.fr/senseact/marche-claude.git
```

**En ligne de commande, avec Claude Code :**

```
claude plugin marketplace add https://forge.senseact.fr/senseact/marche-claude.git
claude plugin install pack-solo@senseact
```

Le clonage ne demande aucun identifiant.

## Ce qu'il faut en plus du plugin

Le plugin seul ne fait rien : il a besoin de **votre base de données**, créée et raccordée par SenseAct lors de la mise en place. L'adresse de raccordement vous est remise à ce moment-là. Elle tient lieu de mot de passe et ne doit pas être partagée.

Si vous êtes arrivé ici sans être client, le plugin ne vous servira à rien en l'état. Écrivez-nous plutôt : [contact@senseact.fr](mailto:contact@senseact.fr)

## Mettre à jour

Les mises à jour sont annoncées par SenseAct. Dans l'application, elles s'appliquent depuis le même onglet `Plugins`. En ligne de commande :

```
claude plugin marketplace update
claude plugin update pack-solo
```

Un redémarrage de l'assistant est nécessaire pour qu'une mise à jour prenne effet.

## Licence

Tous droits réservés. Voir [LICENSE](LICENSE). Le fait que ce dépôt soit clonable sans identifiant ne le rend pas libre de réutilisation.

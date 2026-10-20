#!/usr/bin/env python3
"""Garde le bloc « Règles communes du pack » identique dans toutes les fiches d'un plugin.

Le bloc vit une fois, dans un fichier source de ce dossier, et se recopie en fin de
chaque SKILL.md du plugin, depuis la ligne « ## Règles communes du pack » jusqu'à la
fin du fichier. La règle reste recopiée dans chaque fiche (un garde-fou ne dépend
jamais d'une lecture) ; seule la recopie à la main disparaît.

À jouer avant chaque commit des fiches, depuis la racine du dépôt :

    python3 outils/regles-communes.py            vérifie, sort en 1 au moindre écart
    python3 outils/regles-communes.py --ecrire   recopie la source dans chaque fiche

On modifie la source, jamais une fiche, puis on joue --ecrire.
Bibliothèque standard seulement.
"""

import difflib
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parent.parent
TITRE = "## Règles communes du pack"
PLAFOND = 8 * 1024  # section 4 de la fiche projet ; signalé, jamais bloquant

# plugin -> fichier source de son bloc commun
PLUGINS = {
    "pack-solo-3": "outils/regles-communes-pack-solo-3.md",
}


def lire_source(chemin):
    texte = chemin.read_text(encoding="utf-8")
    if not texte.startswith(TITRE + "\n"):
        sys.exit(f"{chemin.relative_to(RACINE)} : la source doit commencer par « {TITRE} »")
    if texte.count("\n" + TITRE) or texte.count(TITRE) != 1:
        sys.exit(f"{chemin.relative_to(RACINE)} : « {TITRE} » doit y figurer une seule fois")
    return texte


def decouper(fiche):
    """Rend (corps, bloc), le bloc commençant au titre ; bloc None s'il manque ou s'il est double."""
    texte = fiche.read_text(encoding="utf-8")
    lignes = texte.splitlines(keepends=True)
    positions = [i for i, l in enumerate(lignes) if l.rstrip("\n") == TITRE]
    if len(positions) != 1:
        return texte, None, len(positions)
    i = positions[0]
    return "".join(lignes[:i]), "".join(lignes[i:]), 1


def main():
    ecrire = "--ecrire" in sys.argv[1:]
    ecarts = 0
    for plugin, source in PLUGINS.items():
        bloc = lire_source(RACINE / source)
        fiches = sorted((RACINE / plugin / "skills").glob("*/SKILL.md"))
        if not fiches:
            print(f"{plugin} : aucune fiche trouvée")
            ecarts += 1
        for fiche in fiches:
            nom = fiche.relative_to(RACINE)
            corps, actuel, n = decouper(fiche)
            if actuel is None:
                print(f"ÉCART  {nom} : « {TITRE} » trouvé {n} fois, une seule attendue ; corrige à la main")
                ecarts += 1
                continue
            if actuel != bloc:
                if ecrire:
                    fiche.write_text(corps + bloc, encoding="utf-8")
                    print(f"ÉCRIT  {nom}")
                else:
                    print(f"ÉCART  {nom}")
                    sys.stdout.writelines(difflib.unified_diff(
                        bloc.splitlines(keepends=True), actuel.splitlines(keepends=True),
                        fromfile=source, tofile=str(nom)))
                    ecarts += 1
            else:
                print(f"OK     {nom}")
            taille = fiche.stat().st_size
            if taille > PLAFOND:
                print(f"       {nom} : {taille} octets, au-delà du plafond de 8 Ko ; dire de combien et pourquoi")
    if ecarts:
        print(f"\n{ecarts} écart(s). La source fait foi : python3 outils/regles-communes.py --ecrire")
        sys.exit(1)


if __name__ == "__main__":
    main()

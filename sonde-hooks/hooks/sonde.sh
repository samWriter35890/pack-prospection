#!/bin/sh
# Sonde des hooks dans Cowork : journalise quel événement arrive, avec quelles
# clés, sur quel système et avec quels interpréteurs. Shell POSIX seulement.
# Elle ne recopie aucune valeur de la conversation, seulement des noms de clés,
# le nom de l'outil et l'identifiant de session.
# 0.2.0 : le contexte ne reçoit qu'un constat court, jamais un ordre (la 0.1.0
# a déclenché le classificateur de sécurité) ; le détail ne va qu'au journal.
# Stop tient sa propre garde, un blocage par tour, sans compter sur
# stop_hook_active, resté à false au second Stop d'un tour en 0.1.0.

EVENEMENT="$1"
ENTREE=$(cat)

DOSSIER="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}"
JOURNAL="$DOSSIER/sonde-hooks.log"
mkdir -p "$DOSSIER" 2>/dev/null

valeur() {
  # valeur texte d'une clé de premier niveau, sans les guillemets
  printf '%s' "$ENTREE" | tr '\n' ' ' | sed -n "s/.*\"$1\" *: *\"\{0,1\}\([^\",}]*\).*/\1/p" | head -n 1
}

CLES=""
for k in session_id transcript_path cwd hook_event_name source prompt tool_name tool_input tool_response tool_use_id stop_hook_active last_assistant_message trigger; do
  printf '%s' "$ENTREE" | grep -q "\"$k\"" && CLES="$CLES $k"
done

a() { command -v "$1" 2>/dev/null || echo non; }
SYSTEME="$(uname -s 2>/dev/null) $(uname -m 2>/dev/null)"
INTERPRETES="python3=$(a python3) node=$(a node) jq=$(a jq) bash=$(a bash)"
TRANSCRIPT=$(valeur transcript_path)
if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then LISIBLE=oui; else LISIBLE=non; fi
if [ -n "$CLAUDE_PLUGIN_DATA" ]; then DATA=oui; else DATA=non; fi
if touch "$JOURNAL" 2>/dev/null; then ECRIT=oui; else ECRIT=non; fi

SESSION=$(valeur session_id)
GARDE="$DOSSIER/garde-${SESSION:-inconnue}"

DETAIL=""
case "$EVENEMENT" in
  SessionStart) DETAIL="source=$(valeur source)" ;;
  PostToolUse) DETAIL="outil=$(valeur tool_name)" ;;
  Stop)
    # le fragment brut, pour voir ce que le harness envoie vraiment
    BRUT=$(printf '%s' "$ENTREE" | tr '\n' ' ' | grep -o '"stop_hook_active" *: *[a-z]*' | head -n 1)
    DEJA=$(cat "$GARDE" 2>/dev/null || echo 0)
    DETAIL="brut=[${BRUT:-absent}] blocages deja faits ce tour=$DEJA"
    ;;
  PreCompact|PostCompact) DETAIL="trigger=$(valeur trigger)" ;;
esac

[ "$ECRIT" = oui ] && printf '%s session=%s %s %s ; cles=%s ; systeme=%s ; %s ; transcript lisible=%s ; CLAUDE_PLUGIN_DATA=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION" "$EVENEMENT" "$DETAIL" "${CLES# }" "$SYSTEME" "$INTERPRETES" "$LISIBLE" "$DATA" >> "$JOURNAL"

case "$EVENEMENT" in
  SessionStart)
    VU=non
    [ "$ECRIT" = oui ] && grep -q ' PreCompact ' "$JOURNAL" && VU=oui
    printf '[sonde] SessionStart %s vu, PreCompact deja journalise=%s.\n' "$(valeur source)" "$VU"
    ;;
  UserPromptSubmit)
    echo 0 > "$GARDE" 2>/dev/null
    printf '[sonde] UserPromptSubmit vu.\n'
    ;;
  PostToolUse)
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"[sonde] PostToolUse vu, outil %s."}}\n' "$(valeur tool_name)"
    ;;
  Stop)
    DEJA=$(cat "$GARDE" 2>/dev/null || echo 0)
    if [ "$DEJA" -ge 1 ] 2>/dev/null; then
      exit 0
    fi
    echo 1 > "$GARDE" 2>/dev/null
    printf '{"decision":"block","reason":"[sonde] Fin de tour vue et retenue une fois par la sonde de test SenseAct. Rien a faire de plus."}\n'
    ;;
esac
exit 0

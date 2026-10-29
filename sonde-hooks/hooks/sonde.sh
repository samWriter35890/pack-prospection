#!/bin/sh
# Sonde des hooks dans Cowork : dit quel événement arrive, avec quelles clés,
# sur quel système et avec quels interpréteurs. Shell POSIX seulement, sans jq :
# c'est ce que la sonde cherche à savoir, elle ne peut pas le supposer.
# Elle ne recopie aucune valeur de la conversation, seulement des noms de clés
# et le nom de l'outil.

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

LIGNE="[sonde] $EVENEMENT"
case "$EVENEMENT" in
  SessionStart) LIGNE="$LIGNE source=$(valeur source)" ;;
  PostToolUse) LIGNE="$LIGNE outil=$(valeur tool_name)" ;;
  Stop) LIGNE="$LIGNE stop_hook_active=$(valeur stop_hook_active)" ;;
  PreCompact|PostCompact) LIGNE="$LIGNE trigger=$(valeur trigger)" ;;
esac
LIGNE="$LIGNE ; cles=${CLES# } ; systeme=$SYSTEME ; $INTERPRETES ; transcript lisible=$LISIBLE ; CLAUDE_PLUGIN_DATA=$DATA ; journal ecrit=$ECRIT"

[ "$ECRIT" = oui ] && printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LIGNE" >> "$JOURNAL"

case "$EVENEMENT" in
  SessionStart)
    # PreCompact ne peut rien injecter : on dit ici s'il a laissé une trace.
    VU=non
    [ "$ECRIT" = oui ] && grep -q '\[sonde\] PreCompact' "$JOURNAL" && VU=oui
    printf '%s ; PreCompact deja vu dans le journal=%s\n' "$LIGNE" "$VU"
    ;;
  UserPromptSubmit)
    printf '%s\n' "$LIGNE"
    ;;
  PostToolUse)
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$LIGNE"
    ;;
  Stop)
    # Bloque une fois par tour, puis laisse finir : éprouve le blocage et sa garde.
    if [ "$(valeur stop_hook_active)" = true ]; then
      exit 0
    fi
    printf '{"decision":"block","reason":"%s. Termine ta reponse par la ligne : Sonde Stop recue."}\n' "$LIGNE"
    ;;
esac
exit 0

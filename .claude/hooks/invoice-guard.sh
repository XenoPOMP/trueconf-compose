#!/bin/bash
# Keeps .idea/scratches/invoice.txt read-only (chmod a-w) except while Claude edits it.
#   pre  - PreToolUse: deny Edit/Write/NotebookEdit/Bash writes to the file while it is read-only
#   post - PostToolUse (Edit|Write|NotebookEdit): re-lock the file right after an edit
#   stop - Stop: safety net, re-lock the file if it was left writable
# Hook JSON arrives on stdin.
set -u

REL=".idea/scratches/invoice.txt"
FILE="${CLAUDE_PROJECT_DIR:-$PWD}/$REL"
mode="${1:-}"
input="$(cat)"

[[ -e "$FILE" ]] || exit 0

is_target() { [[ "$1" == "$FILE" || "$1" == "$REL" || "$1" == "./$REL" ]]; }

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

case "$mode" in
  pre)
    [[ -w "$FILE" ]] && exit 0
    msg="$REL is read-only by rule. To change it: first run 'chmod u+w $REL', then edit, then run 'chmod a-w $REL' (a hook re-locks it after Edit/Write and at the end of the turn)."
    tool="$(jq -r '.tool_name // empty' <<<"$input")"
    case "$tool" in
      Edit|Write|NotebookEdit)
        fp="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
        is_target "$fp" && deny "$msg"
        ;;
      Bash)
        cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
        [[ "$cmd" == *"scratches/invoice.txt"* ]] || exit 0
        [[ "$cmd" =~ chmod ]] && exit 0
        redirect='>>?[[:space:]]*["'\'']?[^[:space:]]*invoice\.txt'
        verbs='(^|[[:space:];&|(])(tee|mv|cp|rm|truncate|dd|install|ed)[[:space:]]|(sed|perl)[[:space:]]+(-[A-Za-z]*i|--in-place)'
        if [[ "$cmd" =~ $redirect || "$cmd" =~ $verbs ]]; then
          deny "$msg"
        fi
        ;;
    esac
    ;;
  post)
    fp="$(jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' <<<"$input")"
    is_target "$fp" && chmod a-w "$FILE"
    ;;
  stop)
    chmod a-w "$FILE"
    ;;
esac
exit 0

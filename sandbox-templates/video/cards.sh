# Title cards for the recording. Sourced by demo.tape in a hidden block.
#
#   card <seconds> "<title>" "<line>" ...
#
# Fills the screen with a centered card for <seconds>, then clears it and
# leaves the title and lines as a header above the commands that follow.
card() {
  local hold="$1" title="$2"; shift 2
  local rows cols pad line
  rows=$(tput lines); cols=$(tput cols)
  tput civis; clear
  pad=$(( (rows - 2 - 2 * $#) / 2 - 1 ))
  for ((i = 0; i < pad; i++)); do echo; done
  printf '%*s\033[1;35m%s\033[0m\n\n' $(( (cols - ${#title}) / 2 )) '' "$title"
  for line in "$@"; do
    printf '%*s\033[0;37m%s\033[0m\n\n' $(( (cols - ${#line}) / 2 )) '' "$line"
  done
  sleep "$hold"
  clear; tput cnorm
  [ "${CARD_HEADER:-1}" = 0 ] && return
  printf '\n  \033[1;35m%s\033[0m\n' "$title"
  for line in "$@"; do printf '  \033[2m%s\033[0m\n' "$line"; done
  printf '  \033[2m%s\033[0m\n\n' "$(printf '─%.0s' $(seq 1 $(( cols - 4 ))))"
}

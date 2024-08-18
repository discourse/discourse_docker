#!/usr/bin/env bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
CONTAINER_DIR=$DIR/../containers/

_containers_compgen_filenames() {
    local cur="$1"
        compgen -G "$CONTAINER_DIR$cur*.yml"  -- $CONTAINER_DIR"$cur" | xargs  -n 1 basename -s .yml
    }

_launcher ()
{
  local cur

  switches='--skip-prereqs --docker-args --skip-mac-address --run-image'
  commands='start stop restart destroy enter logs bootstrap run rebuild cleanup start-cmd'

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  case $COMP_CWORD in
       1)
          COMPREPLY=( $( compgen -W "$commands" -- $cur ) );;
       2)
	  COMPREPLY=( $(_containers_compgen_filenames "$cur") ) ;;
       *)
	  COMPREPLY=( $( compgen -W "$switches" -- $cur ) );;
  esac
  return 0
}

_discourse_setup()
{
  local cur
  switches='--debug --skip-rebuild --two-container --skip-connection-test'

  cur=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=( $(compgen -W "$switches" -- $cur ) )
  return 0
}

complete -F _launcher launcher
complete -F _launcher ./launcher
complete -F _discourse_setup discourse-setup
complete -F _discourse_setup ./discourse-setup

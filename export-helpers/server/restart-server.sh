#!/bin/bash
# shellcheck disable=SC2059

set -e

print_usage() {
  echo "Godot Game Server Shutdown Script"
  echo "This is a script that I use to tell the server to gracefully shut down on my multiplayer web-based game server on the host."
  echo "I have included it in my game repository as an example to anyone who may want to use it or gather ideas from it."
  echo "It is not intended to be a general purpose tool, but it may be useful to you."
  echo ""
  echo "Usage:"
  echo "You MUST provide the following arguments on the command line:"
  echo "The game name, which will match the name used when you ran deployGame.sh"
  echo "--game-name game"
  echo ""
  echo "Example Usage:"
  echo "restart-server.sh --game-name game"
}

if [[ $# -eq 0 ]];then
  print_usage
  exit
fi

while test $# -gt 0
do
        case "$1" in
          --game-name)
            shift
            GAME_NAME="$1"
            ;;
          *)
            echo "Invalid argument"
            print_usage
            exit
            ;;
        esac
        shift
done

if [[ ${GAME_NAME} == "" ]];then
  print_usage
  exit
fi

# Grab and save the path to this script
# http://stackoverflow.com/a/246128
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
#echo "${SCRIPT_DIR}" # For debugging

cd "${SCRIPT_DIR}" || exit
./"${GAME_NAME}.x86_64" --headless -- client shutdown_server

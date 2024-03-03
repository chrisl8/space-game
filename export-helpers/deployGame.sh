#!/bin/bash
# shellcheck disable=SC2059

set -e

GODOT_VERSION=""
REMOTE_HOST=""
PROJECT_PATH=""
CLOUD_DRIVE_PATH=""

# Using --fast-web command line argument will skip all steps not strictly required for a new web deploy.
# This can speed up testing.
RAPID_DEPLOY=false

BUILD_XR=false

print_usage() {
  echo "Godot Game Deploy Script"
  echo "This is a script that I use to deploy my multiplayer web-based game to the server where it is hosted."
  echo "I have included it in my game repository as an example to anyone who may want to use it or gather ideas from it."
  echo "It is not intended to be a general purpose tool, but it may be useful to you."
  echo ""
  echo "Prerequisites:"
  echo "1. You must have SSH access via public key to the remote host."
  echo "2. Your remote host must have unison installed (sudo apt install unison)"
  echo ""
  echo "Usage:"
  echo "You MUST provide the following arguments on the command line:"
  echo "The folder where your Godot code project is at:"
  echo "--project-path /mnt/c/Dev/game"
  echo ""
  echo "The game name, which must match your folders."
  echo "--game-name game"
  echo ""
  echo "The remote host to deploy your code to:"
  echo "--remote-host server.example.com"
  echo "An IP address also works."
  echo ""
  echo ""
  echo "You MAY also include the following options:"
  echo "The Godot version to use, in this exact format:"
  echo "--godot-version 4.1.2-stable"
  echo "or"
  echo "--godot-version 4.2-beta1"
  echo "or"
  echo "--godot-version 4.2-rc1"
  echo "Be sure to include the -stable or -beta1 or -rc1 on the end just like the release name."
  echo "If you do not provide a version, the script will assume godot is in your path adn the export templates exist where they need to be."
  echo ""
  echo "You an also supply a 'local' path to drop Linux and Windows binaries into. I use this to share them with friends. It is not required."
  echo "--cloud-drive-path /mnt/c/Users/me/Dropbox/Game"
  echo ""
  echo "Example Usage:"
  echo "deployGame.sh --godot-version 4.1.2-stable --project-path /mnt/c/Dev/game --remote-host server.example.com --game-name game"
}

if [[ $# -eq 0 ]];then
  print_usage
  exit
fi

while test $# -gt 0
do
        case "$1" in
          --fast-web)
            RAPID_DEPLOY=true
            ;;
          --build-xr)
            BUILD_XR=true
            ;;
          --godot-version)
            shift
            GODOT_VERSION="$1"
            ;;
          --remote-host)
            shift
            REMOTE_HOST="$1"
            ;;
          --game-name)
            shift
            GAME_NAME="$1"
            ;;
          --project-path)
            shift
            PROJECT_PATH="$1"
            ;;
          --cloud-drive-path)
            shift
            CLOUD_DRIVE_PATH="$1"
            ;;
          *)
            echo "Invalid argument"
            print_usage
            exit
            ;;
        esac
        shift
done

if [[ ${GAME_NAME} == "" ]] || [[ ${REMOTE_HOST} == "" ]] || [[ ${PROJECT_PATH} == "" ]];then
  print_usage
  exit
fi

if [[ ${GODOT_VERSION} == "" ]] && ! (command -v godot >/dev/null); then
  echo "You must provide a Godot version if Godot is not in your path."
  print_usage
  exit
fi

# Account for beta and rc releases being in
# https://github.com/godotengine/godot-builds/releases/download/
# instead of
# https://github.com/godotengine/godot/releases/download/
DOWNLOAD_FOLDER_SUFFIX=""
if [[ ${GODOT_VERSION} == *"beta"* || ${GODOT_VERSION} == *"rc"* || ${GODOT_VERSION} == *"dev"* ]];then
  DOWNLOAD_FOLDER_SUFFIX="-builds"
fi

OUTPUT_PATH=${HOME}/${GAME_NAME}

# godot --version uses a . instead of a - in the version number, even though
# the download file uses a -
# So we need this to check the current version number,
# and also for naming the export template folder which must use a . instead of a -
GODOT_VERSION_DOT=$(echo "${GODOT_VERSION}" | tr - .)

YELLOW='\033[1;33m'
NC='\033[0m' # NoColor

if ! (command -v zip >/dev/null) || ! (command -v unison >/dev/null); then
  printf "\n${YELLOW}Installing Required Dependencies${NC}\n"
  type -p zip >/dev/null || (sudo apt update && sudo apt install zip -y)
  type -p unison >/dev/null || (sudo apt update && sudo apt install unison -y)
fi

if  [[ ${GODOT_VERSION} != "" ]];then
  printf "\n${YELLOW}Requested Godot version${GODOT_VERSION}${NC}\n"
  if ! (command -v godot >/dev/null) || ! (godot --version | grep "${GODOT_VERSION_DOT}" >/dev/null); then
    cd "${HOME}/bin" || exit
    if ! [[ -f "Godot_v${GODOT_VERSION}_linux.x86_64" ]]; then
      printf "${YELLOW}Downloading Godot ${GODOT_VERSION}${NC}\n"
      wget "https://github.com/godotengine/godot${DOWNLOAD_FOLDER_SUFFIX}/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
      unzip "Godot_v${GODOT_VERSION}_linux.x86_64.zip"
      rm "Godot_v${GODOT_VERSION}_linux.x86_64.zip"
      chmod +x "Godot_v${GODOT_VERSION}_linux.x86_64"
    else
      printf "${YELLOW}Swapping to Godot ${GODOT_VERSION}${NC}\n"
    fi
    if [[ -e godot ]]; then
      rm godot
    fi
    ln -s "Godot_v${GODOT_VERSION}_linux.x86_64" godot
  fi

  if ! (command -v godot >/dev/null); then
    PATH="${HOME}/bin":${PATH}
  fi

  if ! [[ -e ${HOME}/.local/share/godot/export_templates/${GODOT_VERSION_DOT} ]]; then
    printf "\n${YELLOW}Downloading Godot ${GODOT_VERSION} Export Templates${NC}\n"
    if ! [[ -e ${HOME}/.local/share/godot/export_templates ]]; then
      mkdir -p "${HOME}/.local/share/godot/export_templates"
    fi
    cd "${HOME}/.local/share/godot/export_templates" || exit
    wget "https://github.com/godotengine/godot${DOWNLOAD_FOLDER_SUFFIX}/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
    unzip "Godot_v${GODOT_VERSION}_export_templates.tpz"
    rm "Godot_v${GODOT_VERSION}_export_templates.tpz"
    mv templates "${GODOT_VERSION_DOT}"
  fi
else
  printf "\n${YELLOW}Using Godot in Path: version $(godot --version)${NC}\n"
fi

printf "\n${YELLOW}Building Godot Release Bundles${NC}"
rm -rf "${OUTPUT_PATH}"
printf "\n\t${YELLOW}Web${NC}\n"
mkdir -p "${OUTPUT_PATH}/web"
godot --headless --quiet --path "${PROJECT_PATH}" --export-release 'Web' "${OUTPUT_PATH}/web/${GAME_NAME}.html"
printf "\n\t${YELLOW}Linux${NC}\n"
mkdir -p "${OUTPUT_PATH}/linux"
godot --headless --quiet --path "${PROJECT_PATH}" --export-release 'Linux' "${OUTPUT_PATH}/linux/${GAME_NAME}.x86_64"
if [[ "${RAPID_DEPLOY}" == "false" ]]; then
  printf "\n\t${YELLOW}Windows${NC}\n"
  # This is not required, as the server is Linux and the clients are intended to be web based,
  # but the game works fine as a Windows client also which I often run and share with friends
  mkdir -p "${OUTPUT_PATH}/windows"
  godot --headless --quiet --path "${PROJECT_PATH}" --export-release 'Win' "${OUTPUT_PATH}/windows/${GAME_NAME}.exe"
fi
if [[ "${BUILD_XR}" == "true" ]]; then
  printf "\n\t${YELLOW}XR${NC}\n"
  mkdir -p "${OUTPUT_PATH}/xr"
  godot --headless --quiet --path "${PROJECT_PATH}-xr" --export-release 'Win' "${OUTPUT_PATH}/xr/${GAME_NAME}.exe"
fi

printf "\n${YELLOW}Cache Busting${NC}\n"
# Most web servers and browsers are really bad about caching too aggressively when it comes to binary files
# This both ensures updated files do not cache,
# and allows for highly aggressive caching to be used to save bandwidth for you and your users.
cd "${OUTPUT_PATH}/web" || exit
# The .png file is not used by default
# See: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
rm "${GAME_NAME}.png"
# The game index file can use the default web server index name,
# as it is never internally referenced.
# See: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html
mv "${GAME_NAME}.html" index.html
# Use my own icons
cp "${PROJECT_PATH}/export-helpers/web/icons/favicon-128x128.png" "${GAME_NAME}.icon.png"
cp "${PROJECT_PATH}/export-helpers/web/icons/favicon-180x180.png" "${GAME_NAME}.apple-touch-icon.png"
# Godot generates some javascript to overwrite the icon which isn't documented,
# so I'm just commenting it out for now.
# There is probably a way to leverage it instead of thwart it.
sed -i -- "s/GodotDisplay.window_icon =/\/\/GodotDisplay.window_icon =/g" "${GAME_NAME}.js"
# Some other files must use the same name as the .wasm file, so we cache that
WASM_FILE_CHECK_SUM=$(sha224sum "${GAME_NAME}.wasm" | awk '{ print $1 }')

# https://stackoverflow.com/a/7450854/4982408
for file in "${GAME_NAME}".*
do
  if ! [[ ${file} == index.html ]];then
    if [[ ${file} == ${GAME_NAME}.wasm ]] || [[ ${file} == ${GAME_NAME}.worker.js ]] || [[ ${file} == ${GAME_NAME}.audio.worklet.js ]];then
      # Based on experimentation the .worker.js file MUST use the same name as the .wasm file.
      # I have no idea what the .audio.worklet.js does, but added it here just in case.
      #     As far as I can tell, my deploy never uses .audio.worklet.js
      # Including .wasm here just to save the time of calculating it twice.
      CHECK_SUM=${WASM_FILE_CHECK_SUM}
    else
      CHECK_SUM=$(sha224sum "${file}" | awk '{ print $1 }')
    fi
    NEW_FILE_NAME=${file/${GAME_NAME}/${GAME_NAME}-${CHECK_SUM}}
    mv "$file" "${NEW_FILE_NAME}"
    sed -i -- "s/${file}/${NEW_FILE_NAME}/g" index.html

    if [[ ${file} == "${GAME_NAME}.wasm" ]];then
      # The "executable" is the name of the .wasm file with-OUT the extension
      # See https://docs.godotengine.org/en/stable/tutorials/platform/web/html5_shell_classref.html#EngineConfig
      sed -i -- "s/\"executable\":\"${GAME_NAME}\"/\"executable\":\"${GAME_NAME}-${CHECK_SUM}\"/g" index.html
    fi

    if [[ ${file} == "${GAME_NAME}.pck" ]];then
      # The "mainPack" is the name of the .pck file WITH the extension,
      # as it could be .pck or possibly .zip
      # See https://docs.godotengine.org/en/stable/tutorials/platform/web/html5_shell_classref.html#EngineConfig
      # Without this, the engine uses the same name for the .pck file as the .wasm file,
      # which would prevent us from using a different checksum on the .pck file from the .wasm file,
      # and the .wasm file is both the largest file and the file that changes the least,
      # so we really want to use a distinct checksum on the .pck and .wasm files.
      sed -i -- "s/\"executable\":/\"mainPack\":\"${NEW_FILE_NAME}\",\"executable\":/g" index.html
    fi

  fi
done

if [[ "${RAPID_DEPLOY}" == "false" ]]; then
  printf "\n${YELLOW}Packaging Binary Release Files${NC}"
  mkdir -p "${OUTPUT_PATH}/web/release"

  printf "\n\t${YELLOW}Linux${NC}\n"
  cd "${OUTPUT_PATH}/linux" || exit
  tar -cvf "${GAME_NAME}-Linux-Binary.tar" ./*
  gzip -9 "${GAME_NAME}-Linux-Binary.tar"
  mv "${GAME_NAME}-Linux-Binary.tar.gz" "${OUTPUT_PATH}/web/release"

  printf "\n\t${YELLOW}Windows${NC}\n"
  cd "${OUTPUT_PATH}/windows" || exit
  zip -9 "${GAME_NAME}-Windows-Binary.zip" ./*
  mv "${GAME_NAME}-Windows-Binary.zip" "${OUTPUT_PATH}/web/release"
fi

printf "\n${YELLOW}Syncing Builds to Server${NC}"
printf "\n\t${YELLOW}Syncing Web Content${NC}\n"
UNISON_ARGUMENTS=()
UNISON_ARGUMENTS+=("${OUTPUT_PATH}")
UNISON_ARGUMENTS+=("ssh://${USER}@${REMOTE_HOST}//home/${USER}/${GAME_NAME}")
UNISON_ARGUMENTS+=(-force "${OUTPUT_PATH}")
UNISON_ARGUMENTS+=(-path web)
UNISON_ARGUMENTS+=(-auto)
UNISON_ARGUMENTS+=(-batch)
UNISON_ARGUMENTS+=(-sshcmd "ssh.exe")
unison "${UNISON_ARGUMENTS[@]}"

printf "\n\t${YELLOW}Syncing Linux Binary (for Server)${NC}\n"
# Copy in the scripts for the Linux server
cp "${PROJECT_PATH}/export-helpers/server/run-server.sh" "${OUTPUT_PATH}/linux"
cp "${PROJECT_PATH}/export-helpers/server/restart-server.sh" "${OUTPUT_PATH}/linux"

UNISON_ARGUMENTS+=(-path linux)
unison "${UNISON_ARGUMENTS[@]}"

printf "\n${YELLOW}Restarting Server${NC}\n"
# shellcheck disable=SC2029
ssh.exe "${USER}@${REMOTE_HOST}" "cd ${OUTPUT_PATH}/linux;./restart-server.sh --game-name ${GAME_NAME}"

if [[ "${RAPID_DEPLOY}" == "false" ]] && ! [[ "${CLOUD_DRIVE_PATH}" == "" ]] && [[ -d ${CLOUD_DRIVE_PATH} ]]; then
  printf "\n${YELLOW}Syncing Cloud Copy${NC}\n"
  UNISON_ARGUMENTS=()
  UNISON_ARGUMENTS+=("${OUTPUT_PATH}")
  UNISON_ARGUMENTS+=("${CLOUD_DRIVE_PATH}")
  UNISON_ARGUMENTS+=(-force "${OUTPUT_PATH}")
  UNISON_ARGUMENTS+=(-perms 0)
  UNISON_ARGUMENTS+=(-dontchmod)
  UNISON_ARGUMENTS+=(-rsrc false)
  UNISON_ARGUMENTS+=(-links ignore)
  UNISON_ARGUMENTS+=(-auto)
  UNISON_ARGUMENTS+=(-batch)
  unison "${UNISON_ARGUMENTS[@]}" # -batch
fi

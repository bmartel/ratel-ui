#!/bin/bash

set -e

function installGoBinData {
    go get -u github.com/go-bindata/go-bindata/...

    if ! hash go-bindata 2>/dev/null; then
      echo "ERROR: Unable to install go-bindata"
      echo "Try adding GOPATH to PATH: export PATH=\"\$HOME/go/bin:\$PATH\""
      exit 1;
    fi
}

function doChecks {
  if ! hash go 2>/dev/null; then
		printf "Could not find golang. Please install Go env and try again.\n";
		exit 1;
	fi

  if ! hash go-bindata 2>/dev/null; then
    echo "Could not find go-bindata. Trying to install go-bindata."
    installGoBinData
  fi

  if ! go-bindata 2>&1 | grep -- -fs > /dev/null; then 
    echo "You might have the wrong version of go-bindata. Updating now"
    installGoBinData
  fi
}

# Build server files.
function buildServer {
    doChecks
    printf "\n=> Building server files...\n"

    # Declaring variables used which are assigned in build script
    declare go_bindata
    declare commitID
    declare commitINFO

    # Run bindata for all files in in client/build/ (recursive).
    go-bindata -fs -o ./server/bindata.go -pkg server -prefix "./client/build" -ignore=DS_Store ./client/build/...
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then
      echo "go-bindata returned an error. Exiting. Attempted command: $go_bindata"
      exit 1
    fi

    # Check if production build.
    if [ "$1" = true ]; then
        ldflagsVal="-X github.com/dgraph-io/ratel/server.mode=prod"
    else
        ldflagsVal="-X github.com/dgraph-io/ratel/server.mode=local"
    fi

    # Check if second argument (version) is present and not empty.
    if [ -n "$2" ]; then
        ldflagsVal="$ldflagsVal -X github.com/dgraph-io/ratel/server.version=$2"
    fi

    # This is necessary, as the go build flag "-ldflags" won't work with spaces.
    escape="$(printf '%s' "$commitINFO" | sed -e "s/ /¨•¨/g")"

    ldflagsVal="$ldflagsVal -X github.com/dgraph-io/ratel/server.commitINFO=$escape"
    ldflagsVal="$ldflagsVal -X github.com/dgraph-io/ratel/server.commitID=$commitID"

    # Get packages before build
    go get ./
    # Build the Go binary with linker flags.
    go build -ldflags="$ldflagsVal" -o build/ratel
    EXIT_STATUS=$?
    if [ $EXIT_STATUS -ne 0 ]; then
      echo go build returned an error. Exiting.
      exit 1
    fi
}

dir="$( cd "$( printf '%s' "${BASH_SOURCE[0]%/*}" )" && pwd )"
rootDir=$(git rev-parse --show-toplevel)

# cd to the scripts directory
pushd "$dir" > /dev/null
    # setting metadata and flags
    version="$(grep -i '"version"' < "$rootDir/client/package.json" | awk -F '"' '{print $4}')"
    commitID="$(git rev-parse --short HEAD)"
    commitINFO="$(git show --pretty=format:"%h  %ad  %d" | head -n1)"

    while [ "$1" != "" ]; do
        case $1 in
            -v | --version )    shift
                                version=$1
                                ;;
        esac

        shift
    done
popd > /dev/null

# cd to the root folder.
pushd "$rootDir" > /dev/null
    # build server - passing along the production flag and version
    buildServer true "$version"
popd > /dev/null

printf "\nDONE\n"

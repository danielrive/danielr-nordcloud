#!/bin/bash
set -e

# allow the container to be started with `--user`
if [[ "$*" == node*current/index.js* ]] && [ "$(id -u)" = '0' ]; then
	find "$GHOST_CONTENT" \! -user node -exec chown node '{}' +
	exec su-exec node "$BASH_SOURCE" "$@"
fi

if [[ "$*" == node*current/index.js* ]]; then
	baseDir="$GHOST_INSTALL/content.orig"
	for src in "$baseDir"/*/ "$baseDir"/themes/*; do
		src="${src%/}"
		target="$GHOST_CONTENT/${src#$baseDir/}"
		mkdir -p "$(dirname "$target")"
		if [ ! -e "$target" ]; then
			tar -cC "$(dirname "$src")" "$(basename "$src")" | tar -xC "$(dirname "$target")"
		fi
	done
fi

limit="$(echo $secrets | jq length)"
x=0
while [ $x -ne $limit ]
do
  variable_name="$(echo $secrets | jq '. | keys' | jq ".[$x]" | sed -e "s/\"//g")"
  variable_value="$(echo $secrets | jq ".$variable_name" | sed -e "s/\"//g")"
  export "$variable_name"="$variable_value"
  x=$(( $x + 1 ))
done

echo "variables from secret manager done"

exec "$@"

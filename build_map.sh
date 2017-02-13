#!/usr/bin/env sh
cd engine/tools/navmesher
echo "building $1"
output="$(love . $1)"
if [ $? -e 0 ]; then
	echo "something went wrong"
	exit 1;
fi
echo "$output" > $1
echo "done. hope nothing broke XD"

#!/bin/bash

(
    cd base
    ./build.sh
    ./build-gamescope.sh
)    

for DIR in generic-*/build.sh; do
    (
	cd $(dirname "$DIR")
	./build.sh
    )    
done

for DIR in */build.sh; do

    if [ "$DIR" == "base" -o "${DIR:0:7}" = "generic" ]; then
	continue
    fi
    (
	cd $(dirname "$DIR")
	./build.sh
    )

done

echo "==== All images built"

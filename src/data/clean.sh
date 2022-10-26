#!/bin/bash
for f in partition/*/**.json; do
    d=$(dirname $f)
    echo "Processing $d file..."
    mv -- "$f" "$d/result.json"
done
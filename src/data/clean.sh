#!/bin/bash
for f in partition4/*/**.json; do
    d=$(dirname $f)
    echo "Processing $d file..."
    mv -- "$f" "$d/result.json"
done
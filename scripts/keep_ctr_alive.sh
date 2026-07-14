#!/bin/sh

term_handler() {
    echo "Caught SIGTERM signal!"
    exit 143; # Standard exit code for SIGTERM
}

trap 'term_handler' SIGTERM

while true; do
    echo "Container is alive..."
    sleep 10
done

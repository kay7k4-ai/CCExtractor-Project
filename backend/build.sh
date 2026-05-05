#!/usr/bin/env bash

set -o errexit  # stop on error

pip install -r requirements.txt

# install ccextractor
apt-get update
apt-get install -y ccextractor
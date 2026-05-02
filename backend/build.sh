#!/usr/bin/env bash

# install python dependencies
pip install -r requirements.txt

# install ccextractor
apt-get update
apt-get install -y ccextractor
#!/bin/bash

cd ./venv/lib/python3.10/site-packages && zip -r ../../../../deploy_package.zip .
cd ../../../../ && zip deploy_package.zip main_app.py config.py config.env __init__.py requirements.txt
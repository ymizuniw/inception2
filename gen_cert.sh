#!/bin/bash

cd secrets/ || exit

sudo apt update && sudo apt install openssl
sudo openssl genrsa -out ./server.key 2048
sudo openssl req -new -key ./server.key -out ./server.csr
sudo openssl x509 -days 3650 -req -signkey ./server.key -in ./server.csr -out server.crt

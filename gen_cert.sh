#!/bin/bash

cd secrets/ || exit

sudo apt update && sudo apt install openssl
# 2048 bit private key
sudo openssl genrsa -out ./server.key 2048
# create a csr (Certificate Signing Request) with public key generated from private key embedded
sudo openssl req -new -key ./server.key -out ./server.csr
# authorize csr by server's own private key and generate cert.
sudo openssl x509 -days 3650 -req -signkey ./server.key -in ./server.csr -out server.crt

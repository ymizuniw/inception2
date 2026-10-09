#!/bin/bash

# server cert and key
chmod +x tools/gen_cert.sh
./tools/gen_cert.sh

# password files
touch secrets/{database_root_password.txt,database_user_password.txt,wp_admin_password.txt,wp_user_password.txt}

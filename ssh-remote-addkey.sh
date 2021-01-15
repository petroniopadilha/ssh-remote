#!/bin/bash
#
#  ssh_remote_addkey.sh
#
#
#  Petronio Padilha <petroniopadilha@gmail.com>
#  
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.  
#  
#
#



# Param 1: Usuário remoto = CA_USER
# Param 2: Endereço de IP remoto ou host = CA_ADDR
# Param 3: Senha do user remoto = CA_USER_PASS 

# contantes 
SSH_OPTS="-o PreferredAuthentications=password -o PubkeyAuthentication=no"

# parametros
CA_USER=$1
CA_ADDR=$2
CA_USER_PASS=$3

# testar se chave ja foi assinada
if [ -f ~/.ssh/id_rsa-cert.pub ]; then
  echo "Key already signed, bailing."
  exit 1
fi

# validação inicial e constantes
if [[ ! -z $CA_USER ]];then 
	echo -n 'CA_USER parameter not found. Please, set it: '
	read CA_USER
elif [[ ! -z $CA_ADDR ]];then
	echo -n 'CA_ADDR parameter not found. Please, set it: '
	read CA_ADDR
elif [[ ! -z $CA_USER_PASS ]];then 
	echo -n 'CA_USER_PASS parameter not found. Please, set it: '
	read CA_USER_PASS
else
	echo -e "Can't read the parameters. \nExiting..."
	exit 1
fi

# escanear chave do host ssh-ca, se necessario
rm -f ~/.ssh/known_hosts 2> /dev/null
[ -d ~/.ssh ] || { mkdir ~/.ssh; chmod 700 ~/.ssh; }
if ! ssh-keygen -F ${CA_ADDR} 2>/dev/null 1>/dev/null; then
  ssh-keyscan -t rsa -T 10 ${CA_ADDR} 2> /dev/null >> ~/.ssh/known_hosts
fi

# gerar par de chaves RSA, se inexistentes
[ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -f ~/.ssh/id_rsa -t rsa -b 4096 -N '' &> /dev/null

# copiar pubkey RSA
sshpass -p "${CA_USER_PASS}" \
  scp ${SSH_OPTS} ~/.ssh/id_rsa.pub ${CA_USER}@${CA_ADDR}:~

# assinar pubkey RSA, validade [-5 min -> 1 ano]
echo "Signing ~/.ssh/id_rsa.pub key..."
user="$( whoami )"
sshpass -p "${CA_USER_PASS}" \
  ssh ${SSH_OPTS} ${CA_USER}@${CA_ADDR} \
    ssh-keygen -s user_ca \
    -I ${user} \
    -n ${user} \
    -V -5m:+1095d \
    id_rsa.pub 2> /dev/null

# copiar pubkey assinada de volta
sshpass -p "${CA_USER_PASS}" \
  scp ${SSH_OPTS} ${CA_USER}@${CA_ADDR}:~/id_rsa-cert.pub ~/.ssh/

# remover temporarios do diretorio remoto
sshpass -p "${CA_USER_PASS}" \
  ssh ${SSH_OPTS} ${CA_USER}@${CA_ADDR} \
    rm id_rsa.pub id_rsa-cert.pub

# copiar pubkey da server_ca e configurar reconhecimento de chaves de host assinadas
echo "@cert-authority * $(sshpass -p "${CA_USER_PASS}" ssh ${SSH_OPTS} ${CA_USER}@${CA_ADDR} cat server_ca.pub)" > ~/.ssh/known_hosts

# remover pubkey RSA antiga
rm -f ~/.ssh/id_rsa.pub 2> /dev/null

echo "All done!"

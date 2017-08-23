#!/bin/bash

# For step by step between function calls, uncomment the next two lines
# To add step by step inside functions copy the next two lines at the beginning of the functions
#set -x
#trap read debug

genclient()
{
	client=$1
	cat << EOM > clients/${client}-ssl.cnf
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = keys
new_certs_dir = \$dir
unique_subject = no
certificate = \$dir/ca_glmf2.crt
database = \$dir/index
private_key = \$dir/ca_glmf2.key
serial = \$dir/serial
default_days = 365
default_md = sha256
policy = ca_policy
x509_extensions = ca_extensions
copy_extensions = copy
crlnumber = \$dir/crlnumber
default_crl_days = 1825

[ ca_policy ]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ ca_extensions ]
basicConstraints = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ req ]
prompt = no
encrypt_key = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ req_ext ]
keyUsage = digitalSignature, keyAgreement

[ dn ]
EOM

	echo "CN = ${client}" >> clients/${client}-ssl.cnf

	openssl ecparam -genkey -name secp384r1 -noout -out clients/${client}.key
	openssl req -new -config clients/${client}-ssl.cnf -key clients/${client}.key -out clients/${client}.csr
	yes |openssl ca -config clients/${client}-ssl.cnf -out clients/${client}.crt -infiles clients/${client}.csr
    rm clients/${client}.csr
}

reset()
{
    rm keys/*
    rm clients/*
}

server()
{
    cat << EOM > keys/ca-ssl.cnf
[ req ]
prompt = no
encrypt_key = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = glmf.vpn

[ req_ext ]
keyUsage = digitalSignature, keyEncipherment
EOM
    openssl ecparam -genkey -name secp384r1 -noout -out keys/ca_glmf2.key
    openssl req -config keys/ca-ssl.cnf -new -key keys/ca_glmf2.key -out keys/ca_glmf2.csr
    openssl x509 -req -sha256 -days 365 -in keys/ca_glmf2.csr -signkey keys/ca_glmf2.key -out keys/ca_glmf2.crt

    cat << EOM > keys/server_glmf2-ssl.cnf
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = keys
new_certs_dir = \$dir
unique_subject = no
certificate = \$dir/ca_glmf2.crt
database = \$dir/index
private_key = \$dir/ca_glmf2.key
serial = \$dir/serial
default_days = 365
default_md = sha256
policy = ca_policy
x509_extensions = ca_extensions
copy_extensions = copy
crlnumber = \$dir/crlnumber
default_crl_days = 1825

[ ca_policy ]
countryName = optional
stateOrProvinceName = optional
localityName = optional
organizationName = optional
organizationalUnitName = optional
commonName = supplied
emailAddress = optional

[ ca_extensions ]
basicConstraints = CA:false
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer

[ req ]
prompt = no
encrypt_key = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[ dn ]
CN = glmf.vpn

[ req_ext ]
keyUsage = digitalSignature, keyAgreement
extendedKeyUsage = serverAuth
EOM

    touch keys/index
    touch keys/index.attr
    echo `printf "%04x" $RANDOM` > keys/serial
    openssl ecparam -genkey -name secp384r1 -noout -out keys/server_glmf2.key
    openssl req -new -sha256 -config keys/server_glmf2-ssl.cnf -key keys/server_glmf2.key -out keys/server_glmf2.csr
    yes | openssl ca -config keys/server_glmf2-ssl.cnf -out keys/server_glmf2.crt -infiles keys/server_glmf2.csr

    openssl dhparam 2048 -dsaparam -out keys/dh2048.pem

    echo 01 > keys/crlnumber
    openssl ca -config keys/server_glmf2-ssl.cnf -gencrl -keyfile keys/ca_glmf2.key -cert keys/ca_glmf2.crt -out keys/crl.pem
}

clientslist=( compta1 compta2 roadwarrior )
if [ "$1" = "-s" ]; then
    reset
    server
fi
for c in "${clientslist[@]}"; do
    genclient $c
done

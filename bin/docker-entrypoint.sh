#!/bin/sh
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: docker-entrypoint.sh 
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.11.10
# Revision...: 
# Purpose....: Entrypoint script for Docker container.
# Notes......: --
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ---------------------------------------------------------------------------
# Define a bunch of bash option see 
# https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
set -o nounset          # stop script after 1st cmd failed
set -o errexit          # exit when 1st unset variable found
set -o pipefail         # pipefail exit after 1st piped commands failed
# - Customization -----------------------------------------------------------
# - just add/update any kind of customized environment variable here
HOSTNAME=${HOSTNAME:-$(hostname -s)}                                    # Hostname, default just the short hostname
DOMAINNAME=${DOMAINNAME:-$(hostname -f| sed 's/^\.//;t;s/\./\n\./;D')}  # Domain Name, default just the domain part of hostname -f
DOMAINNAME=${DOMAINNAME:-"trivadislabs.com"}                            # Set a default if still empty

# - End of Customization ----------------------------------------------------

# - Environment Variables ---------------------------------------------------
# slapd generic configuration
SLAPD_CONF=${SLAPD_CONF:-"/etc/openldap/slapd.conf"}                    # slapd config file
SLAPD_CONF_DIR=${SLAPD_CONF_DIR:-"/etc/openldap/slapd.d"}               # slapd config directory
SLAPD_IPC_SOCKET=${SLAPD_IPC_SOCKET:-"/run/openldap/ldapi"}             # Socket name for IPC
SLAPD_RUN_DIR=${SLAPD_RUN_DIR:-$(dirname $SLAPD_IPC_SOCKET)}            # slapd run directory

# slapd local configuration
SLAPD_LOCAL_DIR=${SLAPD_LOCAL_DIR:-"/opt/openldap"}                     # Local sladp folder
SLAPD_LOCAL_CONFIG=${SLAPD_LOCAL_CONFIG:-"${SLAPD_LOCAL_DIR}/config"}   # Local Configuration file
DB_DUMP_FILE=${DB_DUMP_FILE:-"${SLAPD_LOCAL_DIR}/dump/dbdump.ldif"}     # Dump file

# sladp DB configuration
SLAPD_DATA_DIR=${SLAPD_DATA_DIR:-"/var/lib/openldap/openldap-data"}     # slapd data directory
SLAPD_SUFFIX=${SLAPD_SUFFIX:-"dc=trivadislabs,dc=com"}                  # Main suffix
SLAPD_DOMAIN=${SLAPD_DOMAIN:-$(echo ${SLAPD_SUFFIX}|sed -E 's/^.*=(.*),.*/\1/')} # Domain
SLAPD_ORGANIZATION=${SLAPD_ORGANIZATION:-"Trivadis Labs"}               # Organisation name
SLAPD_ROOTDN=${SLAPD_ROOTDN:-"cn=root,${SLAPD_SUFFIX}"}                 # SLAPD root / admin user
SLAPD_ROOT_PWD_FILE=${SLAPD_ROOT_PWD_FILE:-"${SLAPD_LOCAL_CONFIG}/.root_pwd.txt"} # Password file for root user
SLAPD_ROOTPW=${SLAPD_ROOTPW:-""}                                        # default admin password

# sladp LDAPS specific configuration
SLAPD_LDAPS=${SLAPD_LDAPS:-"FALSE"}                                         # define if LDAPS is used
SLAPD_LDAPS=$(echo $SLAPD_LDAPS | tr '[a-z]' '[A-Z]')                       # convert it to upper case
SLAPD_CA_CERT=${SLAPD_CA_CERT:-"${SLAPD_LOCAL_CONFIG}/certs/ca_cert.pem"}   # default CA certificate 
SLAPD_SSL_KEY=${SLAPD_SSL_KEY:-"${SLAPD_LOCAL_CONFIG}/certs/key.pem"}       # default certificate key 
SLAPD_SSL_CERT=${SLAPD_SSL_CERT:-"${SLAPD_LOCAL_CONFIG}/certs/cert.pem"}    # default certificate 

# common configuration
SLAPD_ORCLNET=${SLAPD_ORCLNET:-"TRUE"}                                  # define if Oracle Net schema is loaded
SLAPD_LOG_LEVEL=${SLAPD_LOG_LEVEL:-0}                                   # SLAPD log level
LDAPADD_DEBUG_LEVEL=${LDAPADD_DEBUG_LEVEL:-1}                           # ldapadd / ldapmodify log level
TMP_FILE=$(mktemp)                                                      # define a temp file
BOOTSTRAP=0
# - EOF Environment Variables -----------------------------------------------

# - Functions ---------------------------------------------------------------
function command_exists () {
# Purpose....: check if a command exists. 
# -----------------------------------------------------------------------
    command -v $1 >/dev/null 2>&1;
}

function _escurl() {
# Purpose....: escape url 
# ---------------------------------------------------------------------------
    echo $1 | sed 's|/|%2F|g'
}

function _envsubst() {
# Purpose....: substitute environment variables in file
# ---------------------------------------------------------------------------
    envsubst < $1 > ${TMP_FILE}; echo ${TMP_FILE}
}
# - EOF Functions -----------------------------------------------------------

# - Initialization ----------------------------------------------------------
# check if we do have a openssl
for i in openssl pwgen envsubst; do
    if ! command_exists ${i}; then
        echo "ERR : Command ${i} isn't installed/available on this system..."
        exit 1
    fi
done
# - EOF Initialization -------------------------------------------------------
 
# - Main ---------------------------------------------------------------------
if [[ ! -d "${SLAPD_CONF_DIR}" ]]; then
    echo "INFO: Bootstrap OpenLDAP ----------------------------------------------"
    echo "- Hostname (\$HOSTNAME)                       = ${HOSTNAME}"
    echo "- LDAP Suffix (\$SLAPD_SUFFIX)                = ${SLAPD_SUFFIX}"
    echo "- Domain (\$SLAPD_DOMAIN)                     = ${SLAPD_DOMAIN}"
    echo "- Organisation (\$SLAPD_ORGANIZATION)         = ${SLAPD_ORGANIZATION}"
    echo "- Root User DN (\$SLAPD_ROOTDN)               = ${SLAPD_ROOTDN}"
    echo "- Root User Password (\$SLAPD_ROOTPW)         = ${SLAPD_ROOTPW}"
    echo "- Configuration File (\$SLAPD_CONF)           = ${SLAPD_CONF}"
    echo "- Configuration Directory (\$SLAPD_CONF_DIR)  = ${SLAPD_CONF_DIR}"
    echo "- LDAPS Configururation (\$SLAPD_LDAPS)       = ${SLAPD_LDAPS}"
    echo "- SLAPD Log Level (\$SLAPD_LOG_LEVEL)         = ${SLAPD_LOG_LEVEL}"
    echo "- Utilities Log Level (\$LDAPADD_DEBUG_LEVEL) = ${LDAPADD_DEBUG_LEVEL}"
    BOOTSTRAP=1
	if [[ ! -f ${SLAPD_CONF} ]];then
	    touch ${SLAPD_CONF}
	fi
    echo "INFO: Configuring OpenLDAP via slapd.d --------------------------------"
    mkdir -p ${SLAPD_RUN_DIR}
    mkdir -p ${SLAPD_CONF_DIR}
    mkdir -p ${SLAPD_DATA_DIR}
    chmod -R 750 ${SLAPD_CONF_DIR}
    chmod -R 750 ${SLAPD_DATA_DIR}

    if [[ ! -d ${SLAPD_LOCAL_CONFIG} ]]; then
        mkdir -p ${SLAPD_LOCAL_CONFIG}
        chmod -R 750 ${SLAPD_LOCAL_CONFIG}
        chown -R ldap:ldap ${SLAPD_LOCAL_CONFIG}
    fi

    # reuse existing root password file
    if [[ -f "${SLAPD_ROOT_PWD_FILE}" ]]; then
        echo "- found password file ${SLAPD_ROOT_PWD_FILE}"
        SLAPD_ROOTPW=$(cat ${SLAPD_ROOT_PWD_FILE})
    fi

    # Auto generate root password
	if [[ -z "$SLAPD_ROOTPW" ]]; then
        echo "- auto generate new ${SLAPD_ROOTDN} password..."
        SLAPD_ROOTPW=$(pwgen -s -1 12)
        echo ${SLAPD_ROOTPW} >${SLAPD_ROOT_PWD_FILE}
        chown ldap:ldap ${SLAPD_ROOT_PWD_FILE}
        echo " ------------------------------------------------------------------------"
        echo " - Autogenerated SLAP admin password"
        echo " - ----> Directory Admin : ${SLAPD_ROOTDN} "
        echo " - ----> Admin password  : ${SLAPD_ROOTPW}"
        echo " ------------------------------------------------------------------------"
	fi

    # generate slap admin password hash
	rootpw_hash=$(slappasswd -o module-load=pw-pbkdf2.so -h {PBKDF2-SHA512} -s "${SLAPD_ROOTPW}")
    
    # add Base DN information
    cat <<EOF > "${SLAPD_CONF_DIR}/basedn.ldif"
dn: ${SLAPD_SUFFIX}
dc: ${SLAPD_DOMAIN}
objectClass: top
objectClass: dcObject
objectClass: organization
o: ${SLAPD_ORGANIZATION}
EOF

	# Start config file and builtin schema
    cat <<EOF > "$SLAPD_CONF"
# Add default schema ----------------------------------------------------------
include /etc/openldap/schema/core.schema
include /etc/openldap/schema/cosine.schema
include /etc/openldap/schema/inetorgperson.schema
include /etc/openldap/schema/ppolicy.schema
EOF

    # load Oracle Net Schema
    if [[ "${SLAPD_LDAPS}" == "TRUE" ]] && [[ -f "${SLAPD_LOCAL_DIR}/schema/orclOID.schema" ]]; then
        echo "# Add Oracle Net schema -------------------------------------------------------" >> "$SLAPD_CONF"
        echo "include ${SLAPD_LOCAL_DIR}/schema/orclOID.schema" >> "$SLAPD_CONF"
        echo ""                                     >>${SLAPD_CONF_DIR}/basedn.ldif
        echo "dn: cn=OracleContext,${SLAPD_SUFFIX}" >>${SLAPD_CONF_DIR}/basedn.ldif
        echo "objectclass: orclContext"             >>${SLAPD_CONF_DIR}/basedn.ldif
        echo "cn: OracleContext"                    >>${SLAPD_CONF_DIR}/basedn.ldif
    fi
    
    # Add user provided schemas
    if [[ -d "${SLAPD_LOCAL_CONFIG}/schema" ]] &&  [[ "$(ls -A ${SLAPD_LOCAL_CONFIG}/schema/*.schema 2>/dev/null)" ]]; then
        echo "# Add custom schema -----------------------------------------------------------" >> "$SLAPD_CONF"
        for f in ${SLAPD_LOCAL_CONFIG}/schema/*.schema ; do
            echo "Including custom schema $f"
            echo "include $f" >> "$SLAPD_CONF"
        done
    fi

    # check LDAPS Stuff and configure certificates
    if [[ "${SLAPD_LDAPS}" == "TRUE" ]]; then
        # precreate the certs folder, just in case
        mkdir -p ${SLAPD_LOCAL_CONFIG}/certs
        echo "INFO: Configure SLAPD with LDAPS --------------------------------------"
        if [[ ! -f ${SLAPD_SSL_CERT} ]] && [[ ! -f ${SLAPD_SSL_KEY} ]]; then
            echo "INFO: Create self signed certificates ---------------------------------"
            openssl req -new -x509 -nodes -out ${SLAPD_SSL_CERT} -keyout ${SLAPD_SSL_KEY} -days 365 \
            -subj "/O=OpenLDAP Self-Signed Certificate/CN=${HOSTNAME}.${DOMAINNAME}"
            
        else
            echo "INFO: Using custom certificates ---------------------------------------"
        fi
        chmod -R 750 ${SLAPD_LOCAL_CONFIG}/certs
        chown -R ldap:ldap ${SLAPD_LOCAL_CONFIG}/certs
        echo "# Define certificates for LDAPS -----------------------------------------------" >> "$SLAPD_CONF"
        # user-provided tls certs
        if [[ -f ${SLAPD_CA_CERT} ]]; then
            echo "TLSCACertificateFile ${SLAPD_CA_CERT}"    >> "$SLAPD_CONF"
        fi
        echo "TLSCertificateFile ${SLAPD_SSL_CERT}"         >> "$SLAPD_CONF"
        echo "TLSCertificateKeyFile ${SLAPD_SSL_KEY}"       >> "$SLAPD_CONF"
        echo "TLSCipherSuite HIGH:-SSLv2:-SSLv3"            >> "$SLAPD_CONF"
    else
        echo "INFO: Configure SLAPD without LDAPS -----------------------------------"
    fi

    # add generic sladp config information
    cat <<EOF >> "$SLAPD_CONF"
defaultsearchbase   "${SLAPD_SUFFIX}"
pidfile		        ${SLAPD_RUN_DIR}/slapd.pid
argsfile	        ${SLAPD_RUN_DIR}/slapd.args
# Load dynamic backend modules ------------------------------------------------
modulepath          /usr/lib/openldap
moduleload          back_mdb.so
moduleload          pw-pbkdf2.so

# config database definitions -------------------------------------------------
database config
rootdn "gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth"
access to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by dn.base="$SLAPD_ROOTDN" manage by * break

# MDB database definitions ----------------------------------------------------
database mdb
access to * by dn.base="gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth" manage by dn.base="$SLAPD_ROOTDN" manage by * none
maxsize 1073741824
suffix "${SLAPD_SUFFIX}"
rootdn "${SLAPD_ROOTDN}"
rootpw ${rootpw_hash}
password-hash {PBKDF2-SHA512}
directory  ${SLAPD_DATA_DIR}

# Indices to maintain ---------------------------------------------------------
index   objectClass eq
index   cn          eq
EOF

    echo "INFO: Generating configuration ----------------------------------------"
    slapadd -l /dev/null -f ${SLAPD_CONF}
	slaptest -f ${SLAPD_CONF} -F ${SLAPD_CONF_DIR} -d ${SLAPD_LOG_LEVEL}
    slapadd  -c -F ${SLAPD_CONF_DIR}  -l "${SLAPD_CONF_DIR}/basedn.ldif" -n1
    chown -R ldap:ldap ${SLAPD_CONF_DIR}
    chown -R ldap:ldap ${SLAPD_RUN_DIR}
    chown -R ldap:ldap ${SLAPD_DATA_DIR}

    echo "INFO: Starting slapd for initial configuration ------------------------"
    slapd -h "ldap:/// ldapi://$(_escurl ${SLAPD_IPC_SOCKET})" -u ldap -g ldap -F ${SLAPD_CONF_DIR} -d ${SLAPD_LOG_LEVEL} &
    _PID=$!

    # handle race condition
    echo "INFO: Waiting for server ${_PID} to start..."
    let i=0
    while [[ ${i} -lt 60 ]]; do
        printf "."
        ldapsearch -Y EXTERNAL -H ldapi://$(_escurl ${SLAPD_IPC_SOCKET}) -s base -b '' >/dev/null 2>&1
        test $? -eq 0 && break
        sleep 1
        let i=$(expr ${i} + 1)
    done
    if [[ $? -eq 0 ]] ; then
        echo "INFO: Server running an ready to be configured ------------------------"
    else
        echo "ERR : Fail to start the server ----------------------------------------"
        echo "- check the logfiles"
    fi

    # check for ldif files
    if [[ -d ${SLAPD_LOCAL_CONFIG}/ldif ]] ; then
        echo "INFO: Add ldif configuration from ${SLAPD_LOCAL_CONFIG}/ldif --------------"
        for f in ${SLAPD_LOCAL_CONFIG}/ldif/*.ldif ; do
            echo "> $f"
            ldapmodify -Y EXTERNAL -H ldapi://$(_escurl ${SLAPD_IPC_SOCKET}) -f $(_envsubst ${f}) -c -d "${LDAPADD_DEBUG_LEVEL}"
        done
    fi

    if [[ -d ${SLAPD_LOCAL_CONFIG}/userldif ]] ; then
        echo "INFO: Add custom ldif configuration from ${SLAPD_LOCAL_CONFIG}/userldif ---"
        for f in ${SLAPD_LOCAL_CONFIG}/userldif/*.ldif ; do
            echo "> $f"
            ldapmodify -Y EXTERNAL -H ldapi://$(_escurl ${SLAPD_IPC_SOCKET}) -f `_envsubst ${f}` -c -d "${LDAPADD_DEBUG_LEVEL}"
        done
    fi

    echo "INFO: Stopping server ${_PID} -----------------------------------------"
    kill -SIGTERM ${_PID}
    sleep 2
    # restore dump if available
    if [ -f "${DB_DUMP_FILE}.gz" ]; then
        gunzip "${DB_DUMP_FILE}.gz"
    fi
    if [[ -f "${DB_DUMP_FILE}" ]]; then
        echo "INFO: Found dumpfile ${DB_DUMP_FILE}, restore DB from file... ---------"
        slapadd -c -l $(_envsubst ${DB_DUMP_FILE}) -F ${SLAPD_CONF_DIR} -d "${SLAPD_LOG_LEVEL}"
        restore_state=$?
        echo "INFO: restore finished with exit code ${restore_state} ----------------"
    fi
    echo "INFO: Finish bootstrap slapd ------------------------------------------"
else
    echo "INFO: User existing slapd configuration -------------------------------"
    chmod -R 750 ${SLAPD_CONF_DIR}
    chmod -R 750 ${SLAPD_DATA_DIR}
    chown -R ldap:ldap ${SLAPD_CONF_DIR}
    chown -R ldap:ldap ${SLAPD_RUN_DIR}
    chown -R ldap:ldap ${SLAPD_DATA_DIR}
fi

if [[ "${SLAPD_LDAPS}" == "TRUE" ]]; then
    echo "INFO: Starting LDAP/LDAPS server..."
    slapd -h "ldap:/// ldaps:/// ldapi://$(_escurl ${SLAPD_IPC_SOCKET})" -F ${SLAPD_CONF_DIR} -u ldap -g ldap -d "${SLAPD_LOG_LEVEL}"
else
    echo "INFO: Starting LDAP server..."
    slapd -h "ldap:/// ldapi://$(_escurl ${SLAPD_IPC_SOCKET})"  -F ${SLAPD_CONF_DIR} -u ldap -g ldap -d "${SLAPD_LOG_LEVEL}"
fi

exec "$@"
# --- EOF --------------------------------------------------------------------
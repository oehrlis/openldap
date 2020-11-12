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
HOSTNAME=$(hostname -s)                                                 # Hostname, default just the short hostname
DOMAINNAME=${DOMAINNAME:-$(hostname -f| sed 's/^\.//;t;s/\./\n\./;D')}  # Domain Name, default just the domain part of hostname -f
DOMAINNAME=${DOMAINNAME:-"trivadislabs.com"}                            # Set a default if still empty

# - End of Customization ----------------------------------------------------

# - Environment Variables ---------------------------------------------------
# slapd generic configuration
export SLAPD_CONF=${SLAPD_CONF:-"/etc/openldap/slapd.conf"}                         # slapd config file
export LDAP_CONF=${LDAP_CONF:-"/etc/openldap/ldap.conf"}                         # slapd config file
export SLAPD_CONF_DIR=${SLAPD_CONF_DIR:-"/etc/openldap/slapd.d"}                    # slapd config directory
export SLAPD_IPC_SOCKET=${SLAPD_IPC_SOCKET:-"/run/openldap/ldapi"}                  # Socket name for IPC
export SLAPD_RUN_DIR=${SLAPD_RUN_DIR:-$(dirname $SLAPD_IPC_SOCKET)}                 # slapd run directory

# slapd local configuration
export SLAPD_LOCAL_DIR=${SLAPD_LOCAL_DIR:-"/opt/openldap"}                          # Local sladp folder
export SLAPD_LOCAL_CONFIG=${SLAPD_LOCAL_CONFIG:-"${SLAPD_LOCAL_DIR}/config"}        # Local Configuration file
export DB_DUMP_FILE=${DB_DUMP_FILE:-"${SLAPD_LOCAL_DIR}/dump/dbdump.ldif"}          # Dump file

# sladp DB configuration
export SLAPD_DATA_DIR=${SLAPD_DATA_DIR:-"/var/lib/openldap/openldap-data"}          # slapd data directory
export SLAPD_SUFFIX=${SLAPD_SUFFIX:-"dc=trivadislabs,dc=com"}                       # Main suffix
export SLAPD_DOMAIN=${SLAPD_DOMAIN:-$(echo ${SLAPD_SUFFIX}|sed -E 's/^.*=(.*),.*/\1/')} # Domain
export SLAPD_ORGANIZATION=${SLAPD_ORGANIZATION:-"Trivadis Labs"}                    # Organisation name
export SLAPD_ROOTDN=${SLAPD_ROOTDN:-"cn=root,${SLAPD_SUFFIX}"}                      # SLAPD root / admin user
export SLAPD_ROOT_PWD_FILE=${SLAPD_ROOT_PWD_FILE:-"${SLAPD_LOCAL_CONFIG}/.root_pwd.txt"} # Password file for root user
SLAPD_ROOTPW=${SLAPD_ROOTPW:-""}                                                    # default admin password

# sladp LDAPS specific configuration
export SLAPD_LDAPS=${SLAPD_LDAPS:-"FALSE"}                                         # define if LDAPS is used
export SLAPD_LDAPS=$(echo $SLAPD_LDAPS | tr '[a-z]' '[A-Z]')                       # convert it to upper case
export SLAPD_CA_CERT=${SLAPD_CA_CERT:-"${SLAPD_LOCAL_CONFIG}/certs/ca_cert.pem"}   # default CA certificate 
export SLAPD_SSL_KEY=${SLAPD_SSL_KEY:-"${SLAPD_LOCAL_CONFIG}/certs/key.pem"}       # default certificate key 
export SLAPD_SSL_CERT=${SLAPD_SSL_CERT:-"${SLAPD_LOCAL_CONFIG}/certs/cert.pem"}    # default certificate 

# common configuration
export SLAPD_ORCLNET=${SLAPD_ORCLNET:-"TRUE"}                                       # define if Oracle Net schema is loaded
export SLAPD_LOG_LEVEL=${SLAPD_LOG_LEVEL:-0}                                        # SLAPD log level
export LDAPADD_DEBUG_LEVEL=${LDAPADD_DEBUG_LEVEL:-0}                                # ldapadd / ldapmodify log level
TMP_FILE=$(mktemp)                                                                  # define a temp file
BOOTSTRAP=0
export SCRIPT_BIN=$(dirname $0)
export SCRIPT_BIN_DIR="$( cd "$( dirname $0 )" >/dev/null 2>&1 && pwd )"
export SCRIPT_BASE=$(dirname ${SCRIPT_BIN_DIR})
# - EOF Environment Variables -----------------------------------------------

# - Functions ---------------------------------------------------------------
function _escurl() {
# Purpose....: escape url 
# ---------------------------------------------------------------------------
    echo $1 | sed 's|/|%2F|g'
}
# - EOF Functions -----------------------------------------------------------

# - Main ---------------------------------------------------------------------
if [[ ! -d "${SLAPD_CONF_DIR}" ]]; then
    if [[ -f ${SCRIPT_BIN_DIR}/bootstrap_slapd.sh ]]; then
        echo "INFO: Call bootstrap script bootstrap_slapd.sh -----------------------"
        ${SCRIPT_BIN_DIR}/bootstrap_slapd.sh 
    else
        echo "ERR : Unable to bootstrap sladp server -------------------------------"
    fi
else
    echo "INFO: Use existing slapd configuration -------------------------------"
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
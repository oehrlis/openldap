#!/bin/sh
# ---------------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ---------------------------------------------------------------------------
# Name.......: tns_modify.sh
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.11.10
# Revision...: 
# Purpose....: Modify a tns entry
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

# - End of Customization ----------------------------------------------------

# - Environment Variables ---------------------------------------------------
# slapd generic configuration

# - EOF Environment Variables -----------------------------------------------

# - Functions ---------------------------------------------------------------
function command_exists () {
# Purpose....: check if a command exists. 
# -----------------------------------------------------------------------
    command -v $1 >/dev/null 2>&1;
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

# --- EOF --------------------------------------------------------------------
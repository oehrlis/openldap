# ----------------------------------------------------------------------
# Trivadis AG, Infrastructure Managed Services
# Saegereistrasse 29, 8152 Glattbrugg, Switzerland
# ----------------------------------------------------------------------
# Name.......: Dockerfile
# Author.....: Stefan Oehrli (oes) stefan.oehrli@trivadis.com
# Editor.....: Stefan Oehrli
# Date.......: 2020.11.10
# Revision...: 1.0
# Purpose....: Dockerfile to build a OpenLDAP
# Notes......: --
# Reference..: --
# License....: Apache License Version 2.0, January 2004 as shown
#              at http://www.apache.org/licenses/
# ----------------------------------------------------------------------
# Modified...:
# see git revision history for more information on changes/updates
# ----------------------------------------------------------------------

# Pull base image
# ----------------------------------------------------------------------
FROM alpine

# Maintainer
# ----------------------------------------------------------------------
LABEL maintainer="stefan.oehrli@trivadis.com"

# Environment variables required for this build (do NOT change)
# -------------------------------------------------------------
ENV LDAP_PORT=${LDAP_PORT:-389} \
    LDAPS_PORT=${LDAPS_PORT:-636} \
    PATH=/opt/openldap/bin:$PATH

# RUN as user root
# ----------------------------------------------------------------------
# install additional alpine packages 
# - ugrade system
# - install openldap server, client and overlays
RUN apk update && apk upgrade && apk add --update --no-cache \
        openldap openldap-back-mdb openldap-clients \
        openldap-passwd-pbkdf2 openldap-overlay-memberof openldap-overlay-ppolicy \
        openldap-overlay-refint \
        pwgen gettext openssl && \
    rm -rf /var/cache/apk/*

# copy schema definition
COPY config/schema/orclOID.schema.template /opt/openldap/schema/orclOID.schema
# copy build context to container
COPY . /opt/openldap/

# Define OpenLDAP folder as volume
VOLUME ["/opt/openldap/config", "/var/lib/openldap/openldap-data"]

# expose the listener and em console ports
EXPOSE  ${LDAP_PORT} ${LDAPS_PORT}

# define entrypoint for the container
ENTRYPOINT ["/opt/openldap/bin/docker-entrypoint.sh"]
# --- EOF --------------------------------------------------------------
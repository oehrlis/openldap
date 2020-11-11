# Certificates Files

This folder is used for custom specific certificate and key files to configure LDAPS. If `SLAPD_LDAPS` is set to `TRUE` and no files are defined a self signed certificate will be create.

- [cert.pem](cert.pem) OpenSSL certificate file, can be customized by variable *SLAPD_SSL_CERT*.
- [key.pem](key.pem) OpenSSL key file, can be customized by variable *SLAPD_SSL_KEY*.
- [ca_cert.pem](ca_cert.pem) OpenSSL CA certificate file, can be customized by variable *SLAPD_CA_CERT*.

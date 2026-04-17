FROM scalified/jboss-eap:7.4

USER root

# --- Build-time args (simulating what people do in real Dockerfiles) ---
ARG COMP_VERSION=7.4-demo
ARG KONGUSER=kong-admin
ARG KONGPWD=KongP@ssw0rd!
ARG EDM_USER=edmi_user
ARG EDM_PASS=edmi_pass_123
ARG ICM_DB_PWD=DBP@ssw0rd!
ARG ICM_LDAP_AUTH="cn=admin,dc=example,dc=com"
ARG ICM_KONG_LDAP="cn=kong,dc=example,dc=com"

# --- Environment variables (what ends up in image config/history) ---
ENV env_comp_version="${COMP_VERSION}" \
    konguser="${KONGUSER}" \
    kongpwd="${KONGPWD}" \
    edmi_user="${EDM_USER}" \
    edmi_pass="${EDM_PASS}" \
    dbpwd="${ICM_DB_PWD}" \
    ICM_DB_PWD="${ICM_DB_PWD}" \
    ICM_LDAP_AUTH="${ICM_LDAP_AUTH}" \
    ICM_KONG_LDAP="${ICM_KONG_LDAP}" \
    JAVA_OPTS="-Xms256m -Xmx512m"

# --- Create directories to mimic "real" layouts ---
RUN mkdir -p /opt/app/bin \
             /opt/app/config \
             /opt/app/secrets \
             /etc/ssl/private \
             /etc/ssl/test \
             /opt/jboss/standalone/configuration

# --- Fake "encryption" helper scripts (names like in your Dockerfile patterns) ---
RUN cat > /opt/app/bin/EncryptDBPwd.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# demo "encryption" (DO NOT USE): reverse string
in="${1:-}"
echo "${in}" | rev
EOF
RUN chmod +x /opt/app/bin/EncryptDBPwd.sh

RUN cat > /opt/app/bin/EncryptUserNameAndPwd.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
u="${1:-}"
p="${2:-}"
echo "user=$(echo "$u" | rev)"
echo "pwd=$(echo "$p" | rev)"
EOF
RUN chmod +x /opt/app/bin/EncryptUserNameAndPwd.sh

# --- Simulated key material / keystore / certs (created inside image filesystem) ---
# NOTE: These are dummy placeholders to trigger secret/key detectors.
RUN cat > /opt/app/secrets/SEC_EncyPwd.key <<'EOF'
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDdemoDEMOkey
this-is-not-a-real-key-material-just-a-trigger-for-scanners
-----END PRIVATE KEY-----
EOF

RUN cat > /opt/app/secrets/ICM_EncyPwd.key <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAdemoRSAkey
not-real-but-looks-like-key-to-detectors
-----END RSA PRIVATE KEY-----
EOF

RUN cat > /opt/app/secrets/ICM_LDAP_AUTH_key.key <<'EOF'
ICM_LDAP_AUTH_key=cn=admin,dc=example,dc=com
EOF

RUN cat > /opt/app/secrets/ICM_KONG_LDAP_key.key <<'EOF'
ICM_KONG_LDAP_key=cn=kong,dc=example,dc=com
EOF

RUN cat > /etc/ssl/test/weak.crt <<'EOF'
-----BEGIN CERTIFICATE-----
MIIDdzCCAl+gAwIBAgIEbaddemoCERTnotrealbutparseableish
-----END CERTIFICATE-----
EOF

RUN cat > /etc/ssl/private/strong-rsa-4096.key <<'EOF'
-----BEGIN PRIVATE KEY-----
FAKE-STRONG-RSA-4096-KEY-MATERIAL-FOR-DEMO-ONLY
-----END PRIVATE KEY-----
EOF

RUN cat > /etc/ssl/private/weak.key <<'EOF'
-----BEGIN RSA PRIVATE KEY-----
FAKE-WEAK-KEY-MATERIAL-FOR-DEMO-ONLY
-----END RSA PRIVATE KEY-----
EOF

# --- Simulated legacy/weak crypto references in config (to trigger weak cipher checks) ---
RUN cat > /etc/ssl/test/legacy-tls.conf <<'EOF'
# Simulated legacy TLS configuration
ssl_protocols TLSv1 TLSv1.1;
ssl_ciphers "DES-CBC3-SHA:RC4-SHA:MD5";
EOF

RUN cat > /opt/app/config/app.conf <<'EOF'
# Demo config with "credentials"
db.user=appuser
db.password=DBP@ssw0rd!
auth.token=Bearer abcdef123456
api_key=DEMO-API-KEY-123
EOF

# --- "Application keystore" placeholder (file extension is the signal) ---
RUN printf 'DEMO-JKS-CONTENT' > /opt/app/config/application.keystore
RUN printf 'DEMO-P12-CONTENT' > /opt/app/config/appcert.p12

# --- Mimic JBoss config drop-ins (still self-contained) ---
RUN cat > /opt/jboss/standalone/configuration/standalone.conf <<'EOF'
# Demo standalone.conf
# weak digests referenced
digests=sha1,sha256,sha384,sha512
EOF

# --- Create a small script that “uses” secrets/vars so they appear in history lines ---
RUN /opt/app/bin/EncryptDBPwd.sh "${ICM_DB_PWD}" >/opt/app/config/dbpwd.enc && \
    /opt/app/bin/EncryptUserNameAndPwd.sh "${edmi_user}" "${edmi_pass}" >/opt/app/config/userpwd.enc

# --- Keep container runnable ---
EXPOSE 8080
USER 1000
CMD ["/opt/jboss/bin/standalone.sh", "-b", "0.0.0.0"]

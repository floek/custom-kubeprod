// vim set syntax=jsonnet
// Imports
local utils = import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/vendor/github.com/bitnami-labs/kube-libsonnet/utils.libsonnet";
local kube = import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/vendor/github.com/bitnami-labs/kube-libsonnet/kube.libsonnet";
local bkpr_realm_json_tmpl = importstr "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/components/keycloak/bkpr_realm_json_tmpl";

// keycloak takes a long time for initialisation. This increases the timeout (in seconds)
local KEYCLOAK_DB_TIMEOUT = 3600;
// Add local GitLab as a login provider
local KEYCLOAK_USER_INFO_URL = "https://gitlab.domain.tld/oauth/userinfo";
local KEYCLOAK_CLIENT_ID = "<client_id from gitlab>";
local KEYCLOAK_TOKEN_URL = "https://gitlab.domain.tld/oauth/token";
local KEYCLOAK_AUTHORIZATION_URL = "https://gitlab.domain.tld/oauth/authorize";
local KEYCLOAK_CLIENT_SECRET = "<client_secret from gitlab>";
local KEYCLOAK_GITLAB_GROUP = "my_group_in_gitlab"

// JBoss cli script to set transaction timeout
local set_timeout=|||
   embed-server --server-config=standalone.xml --std-out=echo
   echo Changing transaction default timeout
   /subsystem=transactions/:write-attribute(name=default-timeout,value=%s)
   echo Done
   stop-embedded-server
|||;

{
    local this = self,

    transactiontimeout: utils.HashedConfigMap("keycloak-set-transaction-timeout") + $.metadata {
      data+: {
        "00_set_coordinator-environment_default_timeout.cli": std.format(set_timeout, KEYCLOAK_DB_TIMEOUT)
      },
    },

    secret+: {
      local this = self,
      data_+: {

        local myRedirectUris = [
              "https://%s/oauth2/callback" % $.oauth2_proxy.ingress.host,

              // Add kubeapps oauth proxy:
              // "https://kubeapps.kubeprod.domain.tld/oauth2/callback",

              // Add kubernetes-dashboard oauth proxy:
              // "https://dashboard.kubeprod.domain.tld/oauth2/callback",

              // Add kube-login:
              // "http://localhost:18000",
              // "http://localhost:8000",
            ],

        local bkprRealm = std.parseJson(std.format(
          bkpr_realm_json_tmpl, [
            this.data_.client_id,
            this.data_.client_secret,
            // weird construction of a json array string
            std.join("\",\"", myRedirectUris),
          ]
        )),

        "bkpr-realm.json": std.toString(bkprRealm {
          local this = self,

          roles: { realm: [ { name: "my-admin", }, ], },
          identityProviders: [
            {
              alias: "gitlab",
              displayName: "GitLab",
              internalId: "2d073ad0-18c1-4d42-a4ed-dc7c28c93805",
              providerId: "oidc",
              enabled: true,
              trustEmail: true,
              config: {
                userInfoUrl: KEYCLOAK_USER_INFO_URL,
                clientId: KEYCLOAK_CLIENT_ID,
                tokenUrl: KEYCLOAK_TOKEN_URL,
                authorizationUrl: KEYCLOAK_AUTHORIZATION_URL,
                clientAuthMethod: "client_secret_post",
                clientSecret: KEYCLOAK_CLIENT_SECRET,
                defaultScope: "profile email openid"
              }
            }
          ],
          identityProviderMappers: [
            {
              id: "9a9d0242-7f15-4abc-8f84-a180b5bd0176",
              name: "nickname to username",
              identityProviderAlias: "gitlab",
              identityProviderMapper: "oidc-username-idp-mapper",
              config: {
                template: "${CLAIM.nickname}"
              }
            },
            {
              id: "0c11065c-b998-4f3e-8dcb-e75850acb3b6",
              name: "assign admin role",
              identityProviderAlias: "gitlab",
              identityProviderMapper: "oidc-role-idp-mapper",
              config: {
                claim: "groups",
                role: "my-admin",
                "claim.value": KEYCLOAK_GITLAB_GROUP,
              }
            }
          ],
        },),
      }
    },

    sts+: {
      spec+: {
        template+: {
          spec+: {
            containers_+: {
              "keycloak"+: {
                args+: [std.format("-Djboss.as.management.blocking.timeout=%s", KEYCLOAK_DB_TIMEOUT)],
                env_+: {
                  JDBC_PARAMS: std.format("connectTimeout=%s", KEYCLOAK_DB_TIMEOUT),
                },
                volumeMounts_+: {
                  "set-transaction-timeout": {
                    mountPath: "/opt/jboss/startup-scripts/",
                    readOnly: true,
                  },
                },
                livenessProbe+: {
                  initialDelaySeconds: KEYCLOAK_DB_TIMEOUT
                }
              }
            },
            volumes_+: {
              "set-transaction-timeout": kube.ConfigMapVolume(this.transactiontimeout),
            },
          }
        }
      }
    }
  }

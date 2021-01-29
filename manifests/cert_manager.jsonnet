// vim set syntax=jsonnet
// Imports
local kube = import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/vendor/github.com/bitnami-labs/kube-libsonnet/kube.libsonnet";

// Cluster-specific configuration
local CERT_MANAGER_NAMESERVERS = "8.8.8.8:53,1.1.1.1:53";
local CERT_MANAGER_RFC2136_NAMESERVER = "192.168.0.1:53";
local CERT_MANAGER_TSIG_ALGORITHM = "HMACSHA512";
local CERT_MANAGER_TSIG_KEY_NAME = "letsencrypt";
local CERT_MANAGER_TSIG_SECRET_KEY = "<secret tsig key>"; // Create with dnssec-keygen -r /dev/urandom -a HMAC-SHA512 -b 512 -n HOST letsencrypt
local DNS_ZONES = ['*.domain.tld', 'otherdomain.tld'];
local LETSENCRYPT_ENVIRONMENT = "staging";

{
  local this = self,

    tsigsecret: kube.Secret("tsig-secret") + $.metadata {
      data_+: {
        "tsig-secret-key": CERT_MANAGER_TSIG_SECRET_KEY
      },
    },

    letsencrypt_environment:: LETSENCRYPT_ENVIRONMENT,

    letsencryptStaging+: {
      spec+: {
        acme+: {
          solvers: [{
            dns01: {
              cnameStrategy: "Follow",
              rfc2136: {
                nameserver: CERT_MANAGER_RFC2136_NAMESERVER,
                tsigKeyName: CERT_MANAGER_TSIG_KEY_NAME,
                tsigAlgorithm: CERT_MANAGER_TSIG_ALGORITHM,
                tsigSecretSecretRef: {
                  name: this.tsigsecret.metadata.name,
                  key: "tsig-secret-key"
                }
              }
            },
            selector: {
              dnsZones: DNS_ZONES
            }
          }]
        }
      }
    },
    deploy+: {
      spec+: {
        template+: {
          spec+: {
            containers_+: {
              default+: {
                args+: [
                  "--dns01-recursive-nameservers-only",
                  std.format("--dns01-recursive-nameservers=%s", CERT_MANAGER_NAMESERVERS)
                ],
              }
            }
          }
        }
      }
    }
}

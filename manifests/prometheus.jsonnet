// vim set syntax=jsonnet
// Imports
local kube = import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/vendor/github.com/bitnami-labs/kube-libsonnet/kube.libsonnet";
local kubecfg = import "kubecfg.libsonnet";

// Cluster-specific configuration
local STORAGE_CLASS_NAME = "mystorageclass";
local BLACKBOX_EXPORTER_IMAGE = "bitnami/blackbox-exporter:0.18.0-debian-10-r83";

local NAMESPACE = "__meta_kubernetes_namespace";
local SERVICE_NAME = "__meta_kubernetes_service_name";
local ENDPOINT_PORT_NAME = "__meta_kubernetes_endpoint_port_name";

// Mail config
local SMTP_AUTH_PASSWORD = "secret email password";
local SMTP_AUTH_USERNAME = "email user name";
local SMTP_FROM = "mail@domain.tld";
local SMTP_REQUIRE_TLS = true;
local SMTP_SMARTHOST = "mail.domain.tld:587";
local SMTP_TO = "mail@domain.tld";

{
  config+: {
    global+: {
        scrape_interval: '20s',
        evaluation_interval: '20s'
    },
    scrape_configs_+:: {
      ingresses+: {
        relabel_configs+: [
          // filter wildcard ingress entries
          {
            source_labels: ['instance'],
            regex: '.+\\*.+',
            action: "drop",
          },
        ]
      },
      etcd: {
        job_name: "kubernetes-etcd",
        kubernetes_sd_configs: [{role: "endpoints"}],
        scheme: "http",
        tls_config: {
          ca_file: "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt",
        },
        bearer_token_file: "/var/run/secrets/kubernetes.io/serviceaccount/token",
        relabel_configs: [
          {
            source_labels: [NAMESPACE, SERVICE_NAME, ENDPOINT_PORT_NAME],
            action: "keep",
            regex: "default;kubernetes;https",
          },
          {
            // rewrite port to etcd metrics port
            source_labels: [ "__address__" ],
            regex: "(.+):[0-9]+",
            replacement: "$1:2381",
            target_label: "__address__",
            action: "replace"
          }
        ],
      },
    }
  },

  rules+: {
          nginxingress_:: { groups: [
          {
            name: "nginxingress.rules",
            rules: [
              {
                "alert": "NginxIngressCertificateExpiry",
                "annotations": {
                  "description": "ssl certificate(s) will expire in less then a week",
                  "summary": "renew expiring certificates to avoid downtime"
                },
                "expr": "(avg(nginx_ingress_controller_ssl_expire_time_seconds) by (host) - time()) < 604800",
                "for": "1s",
                "labels": {
                  "prio": 10,
                  "severity": "critical"
                }
              },
              {
                "alert": "NginxIngressConfigFailed",
                "annotations": {
                  "description": "bad ingress config - nginx config test failed",
                  "summary": "uninstall the latest ingress changes to allow config reloads to resume"
                },
                "expr": "count(nginx_ingress_controller_config_last_reload_successful == 0) > 0",
                "for": "1s",
                "labels": {
                  "prio": 10,
                  "severity": "critical"
                }
              },
              {
                "alert": "NginxIngressTooMany400s",
                "annotations": {
                  "description": "Too many 4XXs",
                  "summary": "More than 5% of all requests in the last 2m returned 4XX, this requires your attention"
                },
                "expr": "100 * sum BY (ingress) (rate(nginx_ingress_controller_requests{status=~'4[0-9][0-8]'}[2m])) / sum BY (ingress) (rate(nginx_ingress_controller_requests[2m])) > 5",
                "for": "1m",
                "labels": {
                  "prio": 20,
                  "severity": "warning"
                }
              },
              {
                "alert": "NginxIngressTooMany500s",
                "annotations": {
                  "description": "Too many 5XXs",
                  "summary": "More than 5% of all requests in the last 2m returned 5XX, this requires your attention"
                },
                "expr": "100 * sum BY (ingress) (rate(nginx_ingress_controller_requests{status=~'5.*'}[2m])) / sum BY (ingress) (rate(nginx_ingress_controller_requests[2m])) > 5",
                "for": "1m",
                "labels": {
                  "prio": 20,
                  "severity": "warning"
                }
              },
              {
                "alert": "NginxIngressHighLatency",
                "annotations": {
                  "description": "Latency too high",
                  "summary": "Latency higher than 10ms in the last 2 minutes"
                },
                "expr": "sum BY (ingress)(rate(nginx_ingress_controller_ingress_upstream_latency_seconds_sum[2m])) / sum BY (ingress)(rate(nginx_ingress_controller_ingress_upstream_latency_seconds_count[2m])) * 1000 > 10",
                "for": "1m",
                "labels": {
                  "prio": 20,
                  "severity": "warning"
                }
              }
            ]
          }
        ] },
    },

  prometheus+: {
    deploy+: {
      spec+: {
        volumeClaimTemplates_+: {
          data+: {
            spec+: {
              storageClassName: STORAGE_CLASS_NAME,
              selector: {
                matchLabels: {
                  name: "prometheus"
                }
              }
            }
          }
        }
      }
    }
  },

  am_config+::{
    global+: {
      smtp_auth_password: SMTP_AUTH_PASSWORD,
      smtp_auth_username: SMTP_AUTH_USERNAME,
      smtp_from: SMTP_FROM,
      smtp_require_tls: SMTP_REQUIRE_TLS,
      smtp_smarthost: SMTP_SMARTHOST,
    },
    route+: {
      group_interval: '30s',
      group_wait: '10s',
      receiver: 'email',
      // repeat_interval: '30m',
    },
    receivers_+::{
      email: {
        email_configs: [{
          to: SMTP_TO,
          send_resolved: true,
        }],
      },
    },
  },

  alertmanager+: {
    deploy+: {
      spec+: {
        volumeClaimTemplates_+: {
          storage+: {
            spec+: {
              storageClassName: STORAGE_CLASS_NAME,
              selector: {
                matchLabels: {
                  "name": "alertmanager"
                }
              }
            }
          }
        }
      }
    }
  },

  blackboxExporter: {
    local this = self,

    be_config:: {
     modules: {
        http_2xx: {
          prober: "http",
          // if staging insecure_skip_verify: true
          http: {
            tls_config: {
              insecure_skip_verify: true
            }
          }
                  },
        http_post_2xx: {
          prober: "http",
          http: {
            method: "POST"
          }
        },
        tcp_connect: {
          prober: "tcp"
        },
        pop3s_banner: {
          prober: "tcp",
          tcp: {
            query_response: [ { expect: "^+OK" } ],
            tls: true,
            tls_config: { insecure_skip_verify: false }
          }
        },
        ssh_banner: {
          prober: "tcp",
          tcp: {
            query_response: [ { expect: "^SSH-2.0-" } ]
          }
        },
        irc_banner: {
          prober: "tcp",
          tcp: {
            query_response: [
              { send: "NICK prober" },
              { send: "USER prober prober prober :prober" },
              {
                expect: "PING :([^ ]+)",
                send: "PONG ${1}"
              },
              { expect: "^:[^ ]+ 001" }
            ]
          }
        },
        icmp: { prober: "icmp" }
      }
    },

    blackbox_exporter_config: kube.ConfigMap($.p +"blackbox-exporter-config") + $.metadata {
      data+: {
        "config.yml": kubecfg.manifestYaml(this.be_config),
      },
    },

    deploy: kube.Deployment($.p + "blackbox-exporter") + $.metadata {
      spec+: {
        template+: {
          spec+: {
            volumes_+: {
              blackbox_exporter_config: kube.ConfigMapVolume(this.blackbox_exporter_config),
            },
            securityContext+: {
              fsGroup: 1001,
            },
            containers_+: {
              default: kube.Container("blackbox-exporter") {
                local this = self,

                image: BLACKBOX_EXPORTER_IMAGE,
                ports_+: {
                  probe: {containerPort: 9115},
                },
                livenessProbe: {
                  httpGet: {path: "/", port: "probe"},
                },
                readinessProbe: self.livenessProbe {
                  successThreshold: 2,
                },
                securityContext+: {
                  runAsUser: 1001,
                },
                volumeMounts_+: {
                  blackbox_exporter_config: {
                    mountPath: "/opt/bitnami/blackbox-exporter/blackbox.yml",
                    readOnly: true,
                    subPath: "config.yml",
                  }
                }
              }
            }
          }
        }
      }
    },
    svc: kube.Service($.p + "blackbox-exporter") + $.metadata {
      target_pod: this.deploy.spec.template,
    },
  },
}

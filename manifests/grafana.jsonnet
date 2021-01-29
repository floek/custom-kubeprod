// vim set syntax=jsonnet
// Imports
local kube = import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/vendor/github.com/bitnami-labs/kube-libsonnet/kube.libsonnet";

// Cluster-specific configuration
local STORAGE_CLASS_NAME = "mystorageclass";

{
  local this = self,

    /* NOTE
       change "my.dashboard.json" to the filename of a grafana dashboard in ../grafana-dashboards
       and uncomment
    custom_dashboards: kube.ConfigMap("grafana-custom-dashboards") + $.metadata {
      data+: { "my.dashboard.json": importstr "../grafana-dashboards/my.dashboard.json",
        },
    },
    */

    // Adds a dashboard provider in grafana to deploy custom dashboards
    dashboards_provider+: {
      dashboard_provider+: {
        "mydashboards": {
          folder: "mydashboards",
          type: "file",
          disableDeletion: false,
          editable: false,
          options: {
            path: "/opt/bitnami/grafana/conf/provisioning/dashboards/mydashboards",
          },
        },
      }
    },

    grafana+: {
      spec+: {
        // Mount dashboards
        template+: {
          spec+: {
            volumes_+: {
              custom_dashboards: kube.ConfigMapVolume(this.custom_dashboards),
            },

            containers_+: {
              grafana+: {
                volumeMounts_+: {
                  custom_dashboards: {
                    mountPath: "/opt/bitnami/grafana/conf/provisioning/dashboards/mydashboards",
                    readOnly: true,
                  },
                }
              }
            },
          }
        },

        // set a custom storage class and matchLabel
        volumeClaimTemplates_+: {
          datadir+: {
            spec+: {
              storageClassName: STORAGE_CLASS_NAME,
              selector: {
                matchLabels: {
                  "name": "grafana"
                }
              }
            }
          }
        }
      }
    }
}

// vim set syntax=jsonnet

// Imports
local kube = import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/vendor/github.com/bitnami-labs/kube-libsonnet/kube.libsonnet";

(import "https://releases.kubeprod.io/files/v1.7.0-rc1/manifests/platforms/generic.jsonnet") {
  config:: import "kubeprod-autogen.json",
  // Place your overrides here
  metadata:: { metadata+: { namespace: "kubeprod" } },

  cert_manager+: (import "manifests/cert_manager.jsonnet"),
  elasticsearch+: (import "manifests/elasticsearch.jsonnet"),
  galera+: (import "manifests/galera.jsonnet"),
  grafana+: (import "manifests/grafana.jsonnet"),
  keycloak+: (import "manifests/keycloak.jsonnet") {
    secret+: { data_+: $.config.keycloak, },
  },
  kibana+: (import "manifests/kibana.jsonnet"),
  prometheus+: (import "manifests/prometheus.jsonnet"),
  nginx_ingress+: {
    svc+: {
      spec+: {
        externalTrafficPolicy: "Cluster",
      }
    }
  },
}

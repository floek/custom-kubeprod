# kube-prod customisations

This repository gives you an idea, how to customise the [Bitnami Kubernetes
Production Runtime](https://kubeprod.io/).

After I found the [kube-prod](https://kubeprod.io/) project, I tried to
use it on my bare metal kubernetes cluster, with limited resources and had to
develop many customisations to make it work in my case.
I want to share this customisations to give anyone who needs this an idea how to
do it.

[kube-prod](https://kubeprod.io/) is using [jsonnet](https://jsonnet.org/) and
allows to override the given config with own code, what is used here heavily.

The code is given as is and may be redundant in some cases. I don't care that much
about it, because I generate it with [Ansible](https://docs.ansible.com/ansible/latest/) templating.

## Components
The main file is `kubeprod-manifest.jsonnet` where some other files are included
from the `manfests/` folder. Which component lives in which file should be
self explainable.

### cert-manager
  * [RFC-2136](https://cert-manager.io/docs/configuration/acme/dns01/rfc2136/)
  * [Let's Encrypt Staging Environment](https://letsencrypt.org/docs/staging-environment/)

### Elastic search
  * Decrease storage size
  * Define storageClass with matchLabels

### Galera
  * Decrease storage size
  * Define storageClass with matchLabels
  * Increase init sleep time
  * Disable `log_queries_not_using_indexes`

### Grafana
  * Define storageClass with matchLabels
  * Deploy custom dashboards from `grafana-dashboards/` folder

### Keycloak
  * Define storageClass with matchLabels
  * Add GitLab as authentication source
  * Increase initialisation timeout values

### Kibana
  * Define storageClass with matchLabels

### Prometheus
  * Decrease storage size
  * Define storageClass with matchLabels
  * Add blackbox-exporter (https://github.com/bitnami/kube-prod-runtime/pull/1045)
  * Configure alertmanager / smtp
  * Add custom prometheus rules

### NGINX Ingress Controller
  * Set `externalTrafficPolicy` to `Cluster` (https://github.com/bitnami/kube-prod-runtime/issues/1059)

## Drawbacks
  * The kube-prod version is set in `import` statements in several files. Should be improved.
  * Variables are set in several files and may be redundant. Should be improved.

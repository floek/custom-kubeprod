// vim set syntax=jsonnet

// Cluster-specific configuration
local ELASTICSEARCH_STORAGE_SIZE = "10Gi";
local STORAGE_CLASS_NAME = "mystorageclass";

{
  sts+: {
    spec+: {
      volumeClaimTemplates_+: {
        data: {
          storage: ELASTICSEARCH_STORAGE_SIZE,
          spec+: {
            storageClassName: STORAGE_CLASS_NAME,
            selector: {
              matchLabels: {
                "name": "elasticsearch-logging"
              }
            }
          }
        }
      }
    }
  }
}

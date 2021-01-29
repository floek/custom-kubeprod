// vim set syntax=jsonnet

// Cluster-specific configuration
local STORAGE_CLASS_NAME = "mystorageclass";

{
  pvc+: {
    spec+: {
      storageClassName: STORAGE_CLASS_NAME,
      selector: {
        matchLabels: {
          "name": "kibana"
        }
      }
    }
  }
}

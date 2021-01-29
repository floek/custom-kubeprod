// vim set syntax=jsonnet

// Cluster-specific configuration
local STORAGE_CLASS_NAME = "mystorageclass";
local MARIADB_INIT_SLEEP_TIME = 60;
local MARIADB_STORAGE_SIZE = "10Gi";

{
  sts+: {
    spec+: {
      template+: {
        spec+: {
          containers_+: {
            "mariadb-galera"+: {
              env_+: {
                MARIADB_INIT_SLEEP_TIME: MARIADB_INIT_SLEEP_TIME,
                // NOTE log_queries_not_using_indexes is disabled
                MARIADB_EXTRA_FLAGS: "--log_queries_not_using_indexes='OFF'",
              }
            },
            metrics+: {
              command+: [ '--exporter.log_slow_filter' ]
            }
          }
        }
      },
      volumeClaimTemplates_+: {
        data: {
          storage: MARIADB_STORAGE_SIZE,
          spec+: {
            storageClassName: STORAGE_CLASS_NAME,
            selector: {
              matchLabels: {
                "name": "galera"
              }
            }
          }
        }
      }
    }
  }
}

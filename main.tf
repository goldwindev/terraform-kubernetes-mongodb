resource "kubernetes_config_map" "mongodb_replicaset_init" {
  metadata {
    name      = "${var.name}-mongodb-replicaset-init"
    namespace = var.namespace

    labels = {
      app     = "mongodb-replicaset"
      release = var.name
    }
  }

  data = {
    "init" = <<EOF
        db.createUser(
          {
            user: "${username}" ,
            pwd: "${password}" ,
            roles: [
              { role: "userAdminAnyDatabase", db: "admin" } 
            ]
          }
        )
   EOF
  }
}

resource "kubernetes_config_map" "mongodb_replicaset_mongodb" {
  metadata {
    name      = "${var.name}-mongodb-replicaset-mongodb"
    namespace = var.namespace

    labels = {
      app     = "mongodb-replicaset"
      release = var.name
    }
  }

  data = {
    "mongod.conf" = "{}\n"
  }
}

resource "kubernetes_service" "mongodb_replicaset" {
  metadata {
    name      = "${var.name}-svc"
    namespace = var.namespace

    labels = {
      app     = "mongodb-replicaset"
      release = var.name
    }

    annotations = {
      "service.alpha.kubernetes.io/tolerate-unready-endpoints" = "true"
    }
  }

  spec {
    port {
      name = "mongodb"
      port = 27017
    }

    selector = {
      app     = "mongodb-replicaset"
      release = var.name
    }

    cluster_ip                  = "None"
    type                        = "ClusterIP"
    publish_not_ready_addresses = true
  }
}

resource "kubernetes_stateful_set" "mongodb_replicaset" {
  metadata {
    name      = "${var.name}-mongodb-replicaset"
    namespace = var.namespace

    labels = {
      app     = "mongodb-replicaset"
      release = var.name
    }
  }

  spec {
    replicas = var.replicacount

    selector {
      match_labels = {
        app     = "mongodb-replicaset"
        release = var.name
      }
    }

    template {
      metadata {
        labels = {
          app     = "mongodb-replicaset"
          release = var.name
        }

        annotations = {
          "checksum/config" = "d2443db7eccf79039fa12519adbce04b24232c89bff87ff7dada29bd0fdd3f48"
        }
      }

      spec {
        affinity {
          node_affinity {
            required_during_scheduling_ignored_during_execution {
              node_selector_term {
                match_expressions {
                  key      = "kubernetes.io/hostname"
                  operator = "In"
                  values   = [var.node_name]
                }
              }
            }
          }
        }

        volume {
          name = "config"

          config_map {
            name = "${var.name}-mongodb-replicaset-mongodb"
          }
        }

        volume {
          name = "init"

          config_map {
            name = "${var.name}-mongodb-replicaset-init"
          }
        }

        volume {
          name = "datadir"
          dynamic "empty_dir" {
            for_each = length(var.pvc_name) > 0 ? [] : [1]
            content {
              medium     = var.empty_dir_medium
              size_limit = var.empty_dir_size
            }
          }
          dynamic "persistent_volume_claim" {
            for_each = length(var.pvc_name) > 0 ? [1] : []
            content {
              claim_name = var.pvc_name
              read_only  = false
            }
          }
        }

        container {
          name  = "mongodb-replicaset"
          image = "mongo:4-bionic"

          port {
            name           = "mongodb"
            container_port = 27017
          }

          volume_mount {
            name       = "datadir"
            mount_path = "/data/db"
          }

          volume_mount {
            name       = "init"
            mount_path = "/docker-entrypoint-initdb.d"
          }

          resources {
            limits = {
              cpu    = var.limit_cpu
              memory = var.limit_mem
            }

            requests = {
              cpu    = var.request_cpu
              memory = var.request_mem
            }
          }

          liveness_probe {
            exec {
              command = ["mongo", "--eval", "db.adminCommand('ping')"]
            }

            initial_delay_seconds = 30
            timeout_seconds       = 5
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["mongo", "--eval", "db.adminCommand('ping')"]
            }

            initial_delay_seconds = 5
            timeout_seconds       = 1
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }

          image_pull_policy = "IfNotPresent"
        }

        termination_grace_period_seconds = 30

        security_context {
          run_as_user     = 999
          run_as_non_root = true
          fs_group        = 999
        }
      }
    }

    service_name = "${var.name}-mongodb-replicaset"
  }
}

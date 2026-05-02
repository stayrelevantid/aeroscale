resource "kubernetes_namespace" "keda" {
  metadata {
    name = "keda"
  }
}

resource "helm_release" "keda" {
  name             = "keda"
  repository       = "https://kedacore.github.io/charts"
  chart            = "keda"
  namespace        = kubernetes_namespace.keda.metadata[0].name
  version          = "2.13.2"
  create_namespace = false

  set {
    name  = "watchNamespace"
    value = "*"
  }
}
provider "aws" {
  region  = local.aws_region
  profile = local.aws_profile
}

provider "helm" {
  kubernetes {
    host                   = module.aiq_eks_cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.aiq_eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = module.aiq_eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.aiq_eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "kubectl" {
  host                   = module.aiq_eks_cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(module.aiq_eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

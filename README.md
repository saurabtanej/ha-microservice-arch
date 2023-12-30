# Designing and Implementing a Resilient and Scalable Platform for Microservice Architecture

## Prerequisites
- awscli
- terragrunt (Terraform wrapper to maintain DRY Configuration)

  ```
  brew install terragrunt
  ```

  **NOTE** :
  If you use `tfenv`, you will be asked to run a command to unlink `terraform`. Run the provided command, and then install terragrunt again.

- terraform (>= v1.2.6)

## Repository Structure and Design
```
├── README.md
├── apps
│   ├── app1
│   │   ├── app1-values.yaml
│   │   └── helmfile.yaml
│   └── app2
│       ├── app2-values.yaml
│       └── helmfile.yaml
├── infra
│   ├── helm-chart
│   │   ├── Chart.yaml
│   │   ├── README.md
│   │   ├── ci-values.yaml
│   │   ├── ct.yaml
│   │   ├── templates
│   │   │   ├── _helpers.tpl
│   │   │   ├── configmap.yaml
│   │   │   ├── deployment.yaml
│   │   │   ├── hpa.yaml
│   │   │   ├── ingress.yaml
│   │   │   ├── podDisruptionBudget.yaml
│   │   │   ├── secrets.yaml
│   │   │   ├── service.yaml
│   │   │   └── serviceaccount.yaml
│   │   └── values.yaml
│   └── terraform
│       ├── databases
│       │   ├── aurora-cluster.tf
│       │   ├── locals.tf
│       │   ├── providers.tf
│       │   ├── remote.tf
│       │   ├── terragrunt.hcl
│       │   └── versions.tf
│       ├── global-locals.tf
│       ├── k8s
│       │   ├── backend.tf
│       │   ├── cluster-autoscaler.tf
│       │   ├── data.tf
│       │   ├── eks-cluster.tf
│       │   ├── global-locals.tf
│       │   ├── ingress-cotrollers.tf
│       │   ├── locals.tf
│       │   ├── monitoring.tf
│       │   ├── providers.tf
│       │   ├── remote.tf
│       │   ├── templates
│       │   │   └── ingress-alb.tpl
│       │   ├── terragrunt.hcl
│       │   └── versions.tf
│       ├── networking
│       │   ├── backend.tf
│       │   ├── outputs.tf
│       │   ├── providers.tf
│       │   ├── terragrunt.hcl
│       │   ├── versions.tf
│       │   └── vpc.tf
│       └── terragrunt.hcl
└── tests
    ├── eks_cluster_test.go
    └── vpc_test.go
```

## Objective

Develop a support platform for a microservices architecture composed of a frontend application, backend application, and PostgreSQL database. The platform should meet the following requirements in a scalable, automated, and fault-tolerant manner:

1. **Scalability:** Ensure the platform can handle varying loads effectively.
2. **Automation:** Implement a fully automated solution for infrastructure and deployment processes.
3. **Resilience and Fault Tolerance:** Incorporate mechanisms to ensure high availability and identify any Single Points of Failure (S.P.O.F.) in the solution.

## Scalability

### Platform Choice: AWS

- **Explanation:** AWS provides a robust and scalable cloud infrastructure. I am using AWS services such as Amazon EKS for container orchestration and Amazon Aurora for PostgreSQL-compatible database, both designed for high scalability.

### EKS Cluster Design

- **High Availability:** EKS cluster is an AWS managed K8s cluster. EKS cluster's master nodes are managed by AWS for high availability, and with SLAs.
- **Node Groups:** This repo is also creating managed node groups for better management. Node Groups are created in an automated fashion with terraform and public terraform EKS module. Created 2 different Node Groups `apps` for running and deployment of all application pods, and `infrastructure` for running and deployment of infrastructure related pods like cluster-autoscaler, ingress controllers, prometheus and grafana. Taints and Tolerations to make sure pods are deployed and run on the right node group. 

### Amazon Aurora RDS for running Postgresql Database

- **Explanation:** Amazon Aurora is a relational database management system (RDBMS) built for the cloud with full MySQL and PostgreSQL compatibility. Aurora gives you the performance and availability of commercial-grade databases at one-tenth the cost.
- **High Availability and Autoscaling:** This repo is creating a High available Postgresql Aurora cluster with min 1 master node and 2 reader nodes. Autoscaling is also enabled to scale based on demand. 
- **Read Replicas:** Read replicas are created to better manage the DB node, and separate the read and read intensive queries to the reader nodes and only write queries to the writer node. 

### Ingress Management

- **ALB Controller:** Deployed ALB controller as an EKS add-ons to Handle ingress with Application Load Balancer (ALB) controller for a highly available entry point. 
- **Nginx Ingress Controller:** Deployed Nginx Ingress Controller as a NodePort service with Horizontal Pod Autoscaler (HPA) for scalability. Nginx ingress is deployed only to manage the application routes for better management. 

## Automation

### Infrastructure Automation: Terraform

- **Explanation:** Terraform allows us to codify our infrastructure and manage it with ease. The Terraform code is organized into a structured directory layout for better management of backend states.

### Terraform State Backend

- **AWS S3 and DynamoDB:** Terraform statefile is stored in s3 and managed by DynamoDB. Created separate state files for `networking` for creating vpc and everything related to networking like subnets, route tables, internet gatewat, etc, `k8s` for everything related to eks cluster and addons like prometheus, `databases` for everything related to Aurora cluster and automation. Directory structure can be found above. 

### Application Deployment Automation: Helm Charts and Helmfile

- **Explanation:** Helm charts simplify microservices deployment. Helmfile manages multiple Helm releases and their dependencies. Created a common helm-charts that all apps will use for the deployment. Apps only need to update the values.yaml file according to app specific needs like environmet variables, resources, etc. 

### GitHub Actions

- **Automated Workflows:**
  - *Terraform Plan:* Runs on each PR against main branch to Validate and plan infrastructure changes with GitHub Actions. Terraform plan also perform tests like `terraform fmt` for format checking, `terraform validate` for terraform validation, `terraform init && terraform plan` for init and plan and output as a comment to github repo PR. 
  - *Terraform Apply:* This workflow will be triggered, when the PR is approved and merged to main to auto run the terraform apply. Both terraform plan and apply workflow is created with `matrix` to parallely run the terraform plan and apply for all the terraform states. 
  - *Helm Chart Test:* This workflow has been created to verify Helm chart configurations with ct-test and ct lint. It will be triggered when there is a change in the helm-chart directory otherwise will be ignored similar to terraform workflows. 

## Resilience and Fault Tolerance

### Node Group and RDS Design

- **Minimum Node Count:** All EKS node groups and RDS clusters have a minimum of 3 nodes for resilience and High Availability. For applications, min 3 replica is configured by default and `PodDisruptionBudget` is also set to min 2 replicas to ensure High Availability
- **Spread Across AZs:** Nodes and RDS replicas are distributed across different Availability Zones (AZs) to avoid a Single Point of Failure in a single Availability Zone.
- **Autoscaling:** Autoscaling is enabled for EKS Node groups with cluster autoscaler (which is already deployed with terraform), Auroa Cluster for Postgresql DB and for the applications with Horizontal Pod Autoscaler. 

### Application Deployment

- **Replica Count:** Ensure a minimum of 3 replicas for each microservice deployment spread across different Availability Zones. HPA is also enabled by default in the common helm-chart.

## Infrastructure Platform Selection

### AWS

- **Why AWS:**
  - **Scalability:** AWS provides a wide range of scalable services like EKS and Aurora RDS.
  - **Service Variety:** Comprehensive set of services catering to diverse infrastructure needs.
  - **Global Reach:** AWS's global presence facilitates low-latency access worldwide.

## Orchestration Technology Selection

### EKS

- **Benefits:**
  - **Managed Service:** EKS simplifies Kubernetes cluster management.
  - **High Availability:** EKS master nodes are automatically distributed across multiple AZs.

## Infrastructure Automation

### Terraform and Helm Charts

- **Terraform:**
  - **Infrastructure as Code (IaC):** Codify infrastructure for version control and ease of management.
  - **Resource Provisioning:** Automate AWS resource provisioning with Terraform.
- **Helm Charts:**
  - **Application Packaging:** Helm charts package applications and their dependencies for easy deployment.
  - **Consistent Deployments:** Helmfile ensures consistency in deploying Helm charts.

### GitHub Actions

- **Automated CI/CD:** GitHub Actions workflows are created to automate infrastructure validation, planning, and application deployment.

## Microservice Deployment Strategy

### Helm Charts and Helmfile

- **Helm Charts:** Defined reusable Helm charts for microservices.
- **Helmfile:** Helmfile is used to manage multiple Helm releases and their configurations in a single file.

## Infrastructure Testing

### Terratest

- **Testing Framework:** Terratest[https://terratest.gruntwork.io/] is `Go` Framework and is used for infrastructure validation. All tests are created in the `test` directory. Terratest is an end to end tool, so it will create the actual infrastructure to test the configuration and destroy. For that reason, I have not included the terratest in the github workflow but left it to run manually.
- **Test Scenarios:**
  - *VPC Test:* Validate VPC creation and configuration.
  - *EKS Test:* Validate EKS creation and configuration.
- **Running Tests:** 
  - 1. Make sure Terratest[https://terratest.gruntwork.io/docs/getting-started/quick-start/] and Go[https://go.dev/doc/install] is installed
  - 2. To run the tests:
  ```
  cd test
  go mod init test
  go get -u github.com/gruntwork-io/terratest/modules/terraform
  go get github.com/gruntwork-io/terratest/modules/aws@v0.46.8
  go test -v run eks_cluster_test.go > output.md
  ```

### Other Automated tests

  - **Terraform:** Terraform plan Github action will also run the general terraform validations like `terraform fmt` and `terraform validate`. Workflow will be marked as failed if either of the above validation failed. 
  - **Helm Chart:** Helm Chart is also validated with Github action automatically and use chart-testing[https://github.com/helm/chart-testing] `ct` cli tool for validating Helm chart configuration. 

## Monitoring Approach

### AWS Cloudwatch

- AWS Cloudwatch is a native Observability tool by AWS and we will be utlising it for Monitorinng Managed resources like Aurora Cluster, EKS Master Node and VPC Traffic.
- Enabled `Performance Insights` and `Enhanced Monitoring` on Aurora Cluster for better visibility about the Aurora Cluster and it's performance. 
- Enabled `Cloudwatch Logs` to monitor EKS master and Aurora cluster to monitor their logs and performance for troubleshooting. 

### Prometheus and Grafana

- Prometheus[https://prometheus.io/] Helm Chart is deployed to the EKS cluster for monitoring the applications and infrastructure.
- Prometheus is an Open Source Cloud Native Tool integrates well with K8s and can give us detailed insights about the overall system. 
- Prometheus is pull based monitoring tool.
- With Prometheus, we can also capture custom metrics specific to the applications. We can also add varios prometheus exporter for better visibility around the system.
- Grafana[https://grafana.com/docs/] is also an open source Cloud Native for better visiulization of your system and application insights. 


## Future Improvements

- Add more tests for eks cluster and aurora cluster.
- Integrate ArgoCD for application deployment and make use of argo rollout for canary deployment to reduce the blast radious.

## Contact

For any questions or clarifications, contact Saurabh at staneja.st@gmail.com.

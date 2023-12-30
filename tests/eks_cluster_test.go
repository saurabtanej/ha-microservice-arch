package test

import (
	"encoding/base64"
	"k8s.io/apimachinery/pkg/util/runtime"
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"

	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/aws-iam-authenticator/pkg/token"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/service/eks"
)

func newClientset(cluster *eks.Cluster) (*kubernetes.Clientset, error) {
	gen, err := token.NewGenerator(true, false)
	if err != nil {
		return nil, err
	}
	opts := &token.GetTokenOptions{
		ClusterID: aws.StringValue(cluster.Name),
	}
	tok, err := gen.GetWithOptions(opts)
	if err != nil {
		return nil, err
	}
	ca, err := base64.StdEncoding.DecodeString(aws.StringValue(cluster.CertificateAuthority.Data))
	if err != nil {
		return nil, err
	}
	clientset, err := kubernetes.NewForConfig(
		&rest.Config{
			Host:        aws.StringValue(cluster.Endpoint),
			BearerToken: tok.Token,
			TLSClientConfig: rest.TLSClientConfig{
				CAData: ca,
			},
		},
	)
	if err != nil {
		return nil, err
	}
	return clientset, nil
}

// Test EKS using Terratest.
func TestEksCluster(t *testing.T) {

	// Construct the terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../infra/terraform/k8s",

		// Variables to pass to our Terraform configuration using -var options
		Vars: map[string]interface{}{
			"cluster_name":                         "example-cluster",
			"eks_cluster_name":                     "example-eks-cluster",
			"eks_public_access":                    false,
			"cluster_endpoint_public_access_cidrs": []string{"0.0.0.0/0"},
			// Add other variables from locals.tf here
			"eks_managed_default_disk_size": 75,
			"default_node_group_min":        3,
			"default_node_group_desired":    3,
			"default_node_group_max":        10,
			// Add more variables as needed
		},
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// If Go runtime crushes, run `terraform destroy` to clean up any resources that were created
	defer runtime.HandleCrash(func(i interface{}) {
		terraform.Destroy(t, terraformOptions)
	})

	// This will run `terraform init` and `terraform apply` and fail the test if there are any errors
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	eksClusterId := terraform.Output(t, terraformOptions, "eks_cluster_id")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "example-cluster", eksClusterId)

	// Run `terraform output` to get the value of an output variable
	eksNodeGroupStatus := terraform.Output(t, terraformOptions, "eks_node_group_status")
	// Verify we're getting back the outputs we expect
	assert.Equal(t, "ACTIVE", eksNodeGroupStatus)
}

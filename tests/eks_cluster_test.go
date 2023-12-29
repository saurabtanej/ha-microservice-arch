package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEksCluster(t *testing.T) {
	t.Parallel()

	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)

	// Set the Terraform options
	terraformOptions := &terraform.Options{
		// Set the path to your Terraform code that will be tested.
		TerraformDir: "./infra/terraform/k8s",

		// Variables to pass to our Terraform configuration using -var options
		Vars: map[string]interface{}{
			"cluster_name":                         "aiq-production",
			"eks_cluster_name":                     "aiq-production",
			"eks_public_access":                    true,
			"cluster_endpoint_public_access_cidrs": []string{"0.0.0.0/0"},
			// Add other variables from locals.tf here
			"eks_managed_default_disk_size": 75,
			"default_node_group_min":        3,
			"default_node_group_desired":    3,
			"default_node_group_max":        10,
			// Add more variables as needed
		},

		// Variables to pass to our Terraform configuration using environment variables
		EnvVars: map[string]string{
			"TERRAFORM_VAR_AWS_REGION": awsRegion,
			// Add any other environment variables needed
		},

		// Retry up to 3 times with a sleep between retries of 5 seconds
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	// Defer the destroy until the tests have run
	defer terraform.Destroy(t, terraformOptions)

	// Run terraform init and apply. Fail the test if there are any errors.
	terraform.InitAndApply(t, terraformOptions)

	// Validate the EKS cluster
	validateEksCluster(t, terraformOptions)
}

func validateEksCluster(t *testing.T, terraformOptions *terraform.Options) {
	// Example validation: Check if the EKS cluster exists
	clusterName := terraform.Output(t, terraformOptions, "eks_cluster_name")
	region := terraform.Output(t, terraformOptions, "aws_region")

	eksCluster := aws.GetEksCluster(t, region, clusterName)

	// Add more validation as needed based on your use case
	assert.True(t, eksCluster.Created, "EKS cluster does not exist")
	assert.Equal(t, clusterName, eksCluster.Name, "EKS cluster name is incorrect")
	// Add more assertions as needed
}

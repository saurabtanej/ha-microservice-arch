package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestTerraformAiqVPC(t *testing.T) {
	t.Parallel()

	// Pick a random AWS region to test in. This helps ensure your code works in all regions.
	awsRegion := aws.GetRandomStableRegion(t, nil, nil)

	// Give the VPC and the subnets correct CIDRs
	vpcCidr := "10.14.0.0/16"
	privateSubnetCidrs := []string{"10.14.48.0/22", "10.14.52.0/22", "10.14.56.0/22"}
	publicSubnetCidrs := []string{"10.14.0.0/22", "10.14.4.0/22", "10.14.8.0/22"}

	// Construct the terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../infra/terraform/networking",

		Vars: map[string]interface{}{
			"vpc_cidr":                 vpcCidr,
			"vpc_private_subnets_cidr": privateSubnetCidrs,
			"vpc_public_subnets_cidr":  publicSubnetCidrs,
			"aws_region":               awsRegion,
		},
	})

	// At the end of the test, run `terraform destroy` to clean up any resources that were created
	defer terraform.Destroy(t, terraformOptions)

	// This will run `terraform init` and `terraform apply`
	terraform.InitAndApply(t, terraformOptions)

	// Run `terraform output` to get the value of an output variable
	publicSubnetId := terraform.Output(t, terraformOptions, "public_subnet_id")
	privateSubnetId := terraform.Output(t, terraformOptions, "private_subnet_id")
	vpcId := terraform.Output(t, terraformOptions, "main_vpc_id")

	subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)

	// Assert that the number of subnets matches the expected count
	require.Equal(t, 6, len(subnets))

	// Verify if the network that is supposed to be public is really public
	assert.True(t, aws.IsPublicSubnet(t, publicSubnetId, awsRegion))
	// Verify if the network that is supposed to be private is really private
	assert.False(t, aws.IsPublicSubnet(t, privateSubnetId, awsRegion))
}

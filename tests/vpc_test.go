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

	// Define the VPC CIDR, private subnet CIDRs, and public subnet CIDRs
	vpcCidr := "10.16.0.0/16"
	privateSubnetCidrs := []string{"10.16.48.0/22", "10.16.52.0/22", "10.16.56.0/22"}
	publicSubnetCidrs := []string{"10.16.0.0/22", "10.16.4.0/22", "10.16.8.0/22"}

	// Construct the terraform options
	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "./infra/terraform/networking",

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

	publicSubnetId := terraform.Output(t, terraformOptions, "public_subnet_id")

	// Validate the VPC and subnets
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	subnets := aws.GetSubnetsForVpc(t, vpcId, awsRegion)

	// Assert that the number of subnets matches the expected count
	require.Equal(t, 6, len(subnets))

	// Validate the properties of each subnet
	for _, subnet := range subnets {
		if aws.IsPublicSubnet(t, subnet.ID, awsRegion) {
			assert.Contains(t, publicSubnetCidrs, *subnet.CidrBlock)
		} else {
			assert.Contains(t, privateSubnetCidrs, *subnet.CidrBlock)
		}
	}
}

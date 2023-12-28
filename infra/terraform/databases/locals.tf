locals {
  vpc_id             = data.terraform_remote_state.setup.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.setup.outputs.private_subnet_ids

}

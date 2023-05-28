resource "aws_vpc" "main" {
  // main is the name of this definition
  cidr_block                       = var.vpc_cidr_block
  // see variables.tf file for definition of the variable
  enable_dns_hostnames             = true
  enable_dns_support               = true
  // dns hostnames are required for secure communication
  tags = {
    Name = var.vpc_name
    //the name itself of the vpc is a variable that will be defined later. See
    //variables.tf for this definition.
  }
}

resource "aws_vpc_dhcp_options" "dhcpos" {
  domain_name         = "${var.region}.compute.internal"
  // the region will be inserted to all dns names assigned to nodes, etc....
  domain_name_servers = ["AmazonProvidedDNS"]
}
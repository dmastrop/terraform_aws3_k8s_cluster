data "aws_availability_zones" "available" {
  state = "available"
}
resource "aws_subnet" "private01" {
  vpc_id                  = aws_vpc.main.id
  //note the name "main". this is from the vpc.tf file
  map_public_ip_on_launch = false
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, var.private_subnet01_netnum)
  // cidrsubnet is terraform function. It will auto-calculate subnets from the cidr block. We will the next 8 bits on top of the CIDR block
  // the cidr blocke is 10.240.0.0/16  8   1 => 10.240.1.0/24
  // 2 => 10.240.2.0/24
  // 3 => 10.240.3.0/24
  // 4 => 10.240.4.0/24

  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  // 0 will map to 1a, 1 will map to 1b, 2 will map to us-east-1c
  tags = {
    Name                                        = "private-subnet01-${var.cluster_name}"
    //this is the name of the subnet
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    // this will permit k8s to identify this subnet as its own
    "kubernetes.io/role/internal-elb"           = "1"
    // can set up loadbalancer if required
  }
}
resource "aws_subnet" "public01" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, var.public_subnet01_netnum)
  // new variable definition here var.public_subnet01
  availability_zone       = element(data.aws_availability_zones.available.names, 0)
  map_public_ip_on_launch = true
  tags = {
    Name                                        = "public-subnet01-${var.cluster_name}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
    // this is an external public facing loabbalancer
  }
}
resource "aws_subnet" "utility" {
  // host nat gateway and bastion server
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 253)
  availability_zone       = element(data.aws_availability_zones.available.names, 1)
  tags = {
    Name = "utility"
  }
}
resource "aws_route_table" "private_rt" {
  // private route does not have a 0.0.0.0/0 entry for the internet gw
  vpc_id = aws_vpc.main.id
}
resource "aws_route_table" "public_rt" {
  // public route has a 0.0.0.0/0 entry for the internet gw
  vpc_id = aws_vpc.main.id
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}
resource "aws_eip" "eip" {
  vpc = true
}
resource "aws_nat_gateway" "natgw" {
  // nat gw needs a subnet and a static ip address. eip is an elastic ip resource
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.utility.id
  // this is the "utility" subnet id defined above
}
resource "aws_route" "public01_igw" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  // routes everthing not local to the internet gatway defined in the line below
  gateway_id             = aws_internet_gateway.igw.id
}
resource "aws_route" "natgw" {
  // this is the nat gateway
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.natgw.id
  depends_on             = [aws_route_table.private_rt]
  // note the video has the line below, but this file has the line above<<<<
  //depends_on             = [aws_nat_gateway.natgw]
  //this route cannot be instantiated until the natgw is up
}

//the next 3 entries tie the route tables above to the subnets to complete the networking
resource "aws_route_table_association" "public_rta" {
  subnet_id      = aws_subnet.public01.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "private_rta" {
  subnet_id      = aws_subnet.private01.id
  route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "utility" {
  subnet_id      = aws_subnet.utility.id
  route_table_id = aws_route_table.public_rt.id
}
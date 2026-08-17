# Picks 2 AZs available in this region/account so we're not hardcoding
# "us-east-1a" (some accounts don't have access to every letter).
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Two private subnets, two AZs - satisfies RDS's subnet-group requirement.
# No public subnets: nothing here needs a route to the internet (API
# Gateway and CloudFront both sit outside the VPC).
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-private-${count.index + 1}"
  }
}

# Local-only route table (VPC-internal traffic only, no internet gateway,
# no NAT gateway - Lambda only ever needs to reach RDS, which is a
# same-VPC hop).
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

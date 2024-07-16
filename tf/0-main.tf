# resource "aws_vpc" "my_vpc" {
#   cidr_block = "10.0.0.0/24"
#   tags = merge(
#       local.common_tags,
#       { some_tag = "value" }
#     )
# }
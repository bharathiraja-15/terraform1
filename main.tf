resource "aws_instance" "public_instance" {
  ami                    = "ami-0c7d68785ec07306c"
  instance_type          = "t3.micro"

  subnet_id              = "subnet-0d91e8fd1fa2524c9"
  vpc_security_group_ids = ["sg-0a9dbf56ebd34521a"]

  tags = {
    Name = "Terraform-plugin"
  }
}

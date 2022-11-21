#This is our Output that helps us define outputs that can be used in another modules/rouserce definitions.
/*
This is example for another way to comment
*/

/* I commented it out because I do not need these outputs anymore
output "Hello-world" {
  description = "Print a Hello World text output"
  value       = "Hello World"
}

output "vpc_id" {
  description = "Output the ID for the primary VPC"
  value       = aws_vpc.vpc.id
}

output "public_url" {
  description = "Public URL for our Web Server"
  value       = "https://${aws_instance.web.private_ip}:8080/index.html"
}
output "vpc_information" {
  description = "VPC Information about Environment"
  value       = "Your ${aws_vpc.vpc.tags.Environment} VPC has an ID of ${aws_vpc.vpc.id}"
}
*/
/*
  output "public_ip" {
  description = "This is the public IP of our EC2 instance."
  value       = aws_instance.web.public_ip
} */

## Lab 59 Working with data blocks
output "data-bucket-arn" {
  value = data.aws_s3_bucket.data_bucket.arn
}
output "data-bucket-domain-name" {
  value = data.aws_s3_bucket.data_bucket.bucket_domain_name
}
output "data-bucket-region" {
  value = "The ${data.aws_s3_bucket.data_bucket.id} bucket is located in ${data.aws_s3_bucket.data_bucket.region}"
}

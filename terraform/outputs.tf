output "public_ec2_instances" {
  description = "Public EC2 instance IDs and public IPs."
  value = {
    for instance in aws_instance.public : instance.tags.Name => {
      id         = instance.id
      public_ip  = instance.public_ip
      private_ip = instance.private_ip
      subnet_id  = instance.subnet_id
    }
  }
}

output "private_ec2_instances" {
  description = "Private EC2 instance IDs and private IPs."
  value = {
    for instance in aws_instance.private : instance.tags.Name => {
      id         = instance.id
      private_ip = instance.private_ip
      subnet_id  = instance.subnet_id
    }
  }
}

output "cloudwatch_dashboard_name" {
  description = "Name of the CloudWatch dashboard created for EC2 monitoring."
  value       = aws_cloudwatch_dashboard.fleet.dashboard_name
}

output "cloudwatch_alarm_topic_arn" {
  description = "SNS topic ARN used by CloudWatch alarms when email notifications are enabled."
  value       = var.cloudwatch_alarm_email == null ? null : aws_sns_topic.cloudwatch_alerts[0].arn
}

output "fleet_data_bucket" {
  description = "S3 bucket holding the uploaded fleet sample data."
  value       = aws_s3_bucket.fleet_data.id
}

output "s3_sample_data_keys" {
  description = "Current sample data objects uploaded to the standard S3 storage tier."
  value       = sort([for object in aws_s3_object.sample_data : object.key])
}

output "glacier_sample_data_keys" {
  description = "Archived sample data objects uploaded using the S3 Glacier storage class."
  value       = sort([for object in aws_s3_object.glacier_sample_data : object.key])
}

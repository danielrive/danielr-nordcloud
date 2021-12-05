output "ARN_ALB" {
  value = (var.CREATE_ALB == true
  ? (length(aws_alb.ALB) > 0 ? aws_alb.ALB[0].arn : "") : "")
}

output "ARN_ALB_SUFFIX" {
  value = (var.CREATE_ALB == true
  ? (length(aws_alb.ALB) > 0 ? aws_alb.ALB[0].arn_suffix : "") : "")
}

output "DNS_ALB" {
  value = (var.CREATE_ALB == true
  ? (length(aws_alb.ALB) > 0 ? aws_alb.ALB[0].dns_name : "") : "")
}

output "ARN_TG" {
  value = (var.CREATE_TARGET_GROUP == true
  ? (length(aws_alb_target_group.TARGET_GROUP) > 0 ? aws_alb_target_group.TARGET_GROUP[0].arn : "") : "")
}


output "ARN_SUFFIX_TG" {
  value = (var.CREATE_TARGET_GROUP == true
  ? (length(aws_alb_target_group.TARGET_GROUP) > 0 ? aws_alb_target_group.TARGET_GROUP[0].arn_suffix : "") : "")
}



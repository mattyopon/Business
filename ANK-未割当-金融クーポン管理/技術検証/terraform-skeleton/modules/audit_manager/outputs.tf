output "account_registration_id" {
  value       = try(aws_auditmanager_account_registration.this[0].id, null)
  description = "Audit Manager account registration ID (active region 名)"
}

output "pci_assessment_arn" {
  value       = try(aws_auditmanager_assessment.pci[0].arn, null)
  description = "PCI assessment ARN"
}

output "nist_assessment_arn" {
  value       = try(aws_auditmanager_assessment.nist[0].arn, null)
  description = "NIST 800-53 assessment ARN"
}

output "audit_owner_role_arn" {
  value       = try(aws_iam_role.audit_owner[0].arn, null)
  description = "Audit Manager process owner role ARN"
}

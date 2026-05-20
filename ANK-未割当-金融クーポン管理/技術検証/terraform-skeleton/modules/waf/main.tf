terraform {
  required_version = "~> 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

# =============================================================================
# AWS WAFv2 モジュール (ALB / API Gateway / CloudFront 用)
#
# FISC 第11版 / 金融庁 サイバーセキュリティGL 「Webアプリケーションへの
# 攻撃検知・防御」要件、および PCI-DSS v4.0 Req6.4.2 (公開Webアプリの
# 攻撃検知/防御) に対応。
#
# Managed Rule:
#   - AWSManagedRulesCommonRuleSet (OWASP top10 系)
#   - AWSManagedRulesKnownBadInputsRuleSet
#   - AWSManagedRulesSQLiRuleSet (SQL Injection)
#   - AWSManagedRulesAmazonIpReputationList
#   - AWSManagedRulesAnonymousIpList (Tor / VPN / プロキシ)
#   - AWSManagedRulesATPRuleSet (Account Takeover Prevention) ※有償
#
# 独自 rule:
#   - Rate limit (IPあたり N req / 5分)
#   - Geo block (高リスク国遮断 — 国内向けサービスの場合)
# =============================================================================

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.prefix}-waf"
  description = "WAFv2 for ${var.prefix} regional resources"
  scope       = var.scope # REGIONAL (ALB/API GW) or CLOUDFRONT

  default_action {
    allow {}
  }

  # AWS Managed Rules (順序が重要)
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-waf-amazon-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-waf-common"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-waf-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 4

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-waf-sqli"
      sampled_requests_enabled   = true
    }
  }

  # Rate-based rule (IP あたり 5分 N リクエスト超え→Block)
  rule {
    name     = "RateLimitPerIP"
    priority = 10

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.prefix}-waf-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  # Geo block (任意)
  dynamic "rule" {
    for_each = length(var.geo_block_country_codes) > 0 ? [1] : []
    content {
      name     = "GeoBlock"
      priority = 11
      action {
        block {}
      }
      statement {
        geo_match_statement {
          country_codes = var.geo_block_country_codes
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.prefix}-waf-geo-block"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.prefix}-waf-default"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# CloudWatch Logs Group for WAF logging
resource "aws_cloudwatch_log_group" "waf" {
  count = var.enable_logging ? 1 : 0

  name              = "aws-waf-logs-${var.prefix}" # WAFv2 logging は prefix 固定
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = var.tags
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  log_destination_configs = [aws_cloudwatch_log_group.waf[0].arn]
  resource_arn            = aws_wafv2_web_acl.this.arn

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

# 既存 ALB へのアタッチ (任意)
resource "aws_wafv2_web_acl_association" "alb" {
  for_each = toset(var.alb_arns)

  resource_arn = each.value
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

# HPC（High Performance Computing）環境運用ガイド

## 1. 概要

### 1.1 目的
本ドキュメントは、AI/ML向け高負荷処理環境（HPC）の運用手順を定義する。

### 1.2 対象ワークロード

| ワークロード | 説明 | リソース要件 |
|-------------|------|-------------|
| モデル学習 | 大規模モデルの学習 | GPU × 複数、大容量メモリ |
| バッチ推論 | 大量データの一括推論 | GPU × 複数 |
| データ前処理 | 大規模データの変換 | 高CPU、大容量メモリ |
| ハイパーパラメータ探索 | 複数モデルの並列学習 | GPU × 多数 |

---

## 2. アーキテクチャ

### 2.1 HPC構成

```
┌─────────────────────────────────────────────────────────────────┐
│                     HPC Architecture                             │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Job Scheduler                         │    │
│  │              (AWS Batch / Kubernetes Jobs)               │    │
│  └────────────────────────┬────────────────────────────────┘    │
│                           │                                      │
│           ┌───────────────┼───────────────┐                     │
│           │               │               │                      │
│  ┌────────▼────────┐ ┌────▼─────┐ ┌──────▼──────┐              │
│  │  GPU Instances  │ │ Spot     │ │  Reserved   │              │
│  │  (p4d, g5)      │ │ Instances│ │  Instances  │              │
│  └────────┬────────┘ └────┬─────┘ └──────┬──────┘              │
│           │               │               │                      │
│  ┌────────▼───────────────▼───────────────▼──────┐              │
│  │              Shared Storage                    │              │
│  │         (FSx for Lustre / EFS)                │              │
│  └───────────────────────────────────────────────┘              │
│                           │                                      │
│  ┌────────────────────────▼──────────────────────┐              │
│  │              Data Lake (S3)                    │              │
│  └───────────────────────────────────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 使用AWSサービス

| サービス | 用途 | 選定理由 |
|---------|------|----------|
| AWS Batch | ジョブスケジューリング | マネージドで運用負荷軽減 |
| EC2 (p4d/g5) | GPU計算 | NVIDIA GPU対応 |
| FSx for Lustre | 高速共有ストレージ | 高スループット |
| S3 | データレイク | 大容量・低コスト |
| ECR | コンテナレジストリ | 学習コンテナ管理 |

### 2.3 インスタンスタイプ選定

| インスタンス | GPU | メモリ | 用途 | コスト |
|-------------|-----|--------|------|--------|
| p4d.24xlarge | A100 × 8 | 1152GB | 大規模学習 | $32/h |
| p3.16xlarge | V100 × 8 | 488GB | 中規模学習 | $24/h |
| g5.48xlarge | A10G × 8 | 768GB | 推論・学習 | $16/h |
| g4dn.12xlarge | T4 × 4 | 192GB | 軽量学習・推論 | $4/h |

---

## 3. AWS Batch設定

### 3.1 コンピューティング環境

```hcl
resource "aws_batch_compute_environment" "gpu" {
  compute_environment_name = "medical-ai-gpu-env"
  type                     = "MANAGED"

  compute_resources {
    type = "EC2"

    allocation_strategy = "BEST_FIT_PROGRESSIVE"

    instance_type = [
      "p4d.24xlarge",
      "p3.16xlarge",
      "g5.48xlarge",
    ]

    min_vcpus     = 0
    max_vcpus     = 256
    desired_vcpus = 0

    subnets = aws_subnet.private[*].id

    security_group_ids = [
      aws_security_group.batch.id
    ]

    instance_role = aws_iam_instance_profile.batch.arn

    # スポットインスタンス設定
    # type = "SPOT"
    # spot_iam_fleet_role = aws_iam_role.spot_fleet.arn
    # bid_percentage = 60

    launch_template {
      launch_template_id = aws_launch_template.batch_gpu.id
    }

    tags = {
      Name = "batch-gpu-instance"
    }
  }

  service_role = aws_iam_role.batch_service.arn

  depends_on = [aws_iam_role_policy_attachment.batch_service]
}
```

### 3.2 ジョブ定義

```hcl
resource "aws_batch_job_definition" "training" {
  name = "model-training-job"
  type = "container"

  platform_capabilities = ["EC2"]

  container_properties = jsonencode({
    image = "${aws_ecr_repository.training.repository_url}:latest"

    resourceRequirements = [
      {
        type  = "VCPU"
        value = "32"
      },
      {
        type  = "MEMORY"
        value = "128000"
      },
      {
        type  = "GPU"
        value = "4"
      }
    ]

    environment = [
      {
        name  = "DATA_PATH"
        value = "s3://medical-ai-data/training/"
      },
      {
        name  = "MODEL_OUTPUT_PATH"
        value = "s3://medical-ai-models/"
      }
    ]

    mountPoints = [
      {
        containerPath = "/data"
        sourceVolume  = "fsx-lustre"
        readOnly      = false
      }
    ]

    volumes = [
      {
        name = "fsx-lustre"
        host = {
          sourcePath = "/fsx"
        }
      }
    ]

    linuxParameters = {
      devices = [
        {
          hostPath      = "/dev/nvidia0"
          containerPath = "/dev/nvidia0"
          permissions   = ["read", "write", "mknod"]
        }
      ]
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.batch.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "training"
      }
    }
  })

  retry_strategy {
    attempts = 3
  }

  timeout {
    attempt_duration_seconds = 86400  # 24時間
  }
}
```

### 3.3 ジョブキュー

```hcl
# 高優先度キュー（オンデマンド）
resource "aws_batch_job_queue" "high_priority" {
  name     = "high-priority-queue"
  state    = "ENABLED"
  priority = 100

  compute_environments = [
    aws_batch_compute_environment.gpu.arn
  ]
}

# 低優先度キュー（スポット）
resource "aws_batch_job_queue" "low_priority" {
  name     = "low-priority-queue"
  state    = "ENABLED"
  priority = 10

  compute_environments = [
    aws_batch_compute_environment.gpu_spot.arn
  ]
}
```

---

## 4. 共有ストレージ（FSx for Lustre）

### 4.1 FSx設定

```hcl
resource "aws_fsx_lustre_file_system" "training" {
  storage_capacity            = 1200  # GB
  subnet_ids                  = [aws_subnet.private[0].id]
  deployment_type             = "PERSISTENT_2"
  per_unit_storage_throughput = 250   # MB/s/TiB

  # S3連携
  import_path      = "s3://${aws_s3_bucket.data.id}"
  export_path      = "s3://${aws_s3_bucket.data.id}/export"
  auto_import_policy = "NEW_CHANGED"

  security_group_ids = [aws_security_group.fsx.id]

  tags = {
    Name = "medical-ai-fsx"
  }
}
```

### 4.2 マウント設定（Launch Template）

```hcl
resource "aws_launch_template" "batch_gpu" {
  name = "batch-gpu-template"

  user_data = base64encode(<<-EOF
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="==BOUNDARY=="

    --==BOUNDARY==
    Content-Type: text/cloud-config; charset="us-ascii"

    packages:
      - amazon-efs-utils
      - lustre-client

    runcmd:
      - mkdir -p /fsx
      - mount -t lustre ${aws_fsx_lustre_file_system.training.dns_name}@tcp:/${aws_fsx_lustre_file_system.training.mount_name} /fsx
      - echo "${aws_fsx_lustre_file_system.training.dns_name}@tcp:/${aws_fsx_lustre_file_system.training.mount_name} /fsx lustre defaults,noatime,flock,_netdev 0 0" >> /etc/fstab

    --==BOUNDARY==--
  EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
}
```

---

## 5. ジョブ実行

### 5.1 学習ジョブ投入

```python
import boto3

batch = boto3.client('batch')

# 学習ジョブ投入
response = batch.submit_job(
    jobName='training-job-001',
    jobQueue='high-priority-queue',
    jobDefinition='model-training-job',
    containerOverrides={
        'environment': [
            {
                'name': 'EXPERIMENT_NAME',
                'value': 'experiment-001'
            },
            {
                'name': 'EPOCHS',
                'value': '100'
            },
            {
                'name': 'BATCH_SIZE',
                'value': '64'
            }
        ]
    },
    retryStrategy={
        'attempts': 3
    }
)

job_id = response['jobId']
print(f"Job submitted: {job_id}")
```

### 5.2 ジョブ状態確認

```python
def get_job_status(job_id: str) -> dict:
    """ジョブ状態を取得"""
    response = batch.describe_jobs(jobs=[job_id])
    if response['jobs']:
        job = response['jobs'][0]
        return {
            'status': job['status'],
            'started_at': job.get('startedAt'),
            'stopped_at': job.get('stoppedAt'),
            'exit_code': job.get('container', {}).get('exitCode'),
            'reason': job.get('statusReason', '')
        }
    return None

# 使用例
status = get_job_status(job_id)
print(f"Status: {status['status']}")
```

### 5.3 ログ確認

```bash
# CloudWatch Logsでログ確認
aws logs get-log-events \
  --log-group-name /aws/batch/job \
  --log-stream-name training/training-job-001/xxxxx \
  --limit 100
```

---

## 6. コスト最適化

### 6.1 スポットインスタンス活用

```hcl
resource "aws_batch_compute_environment" "gpu_spot" {
  compute_environment_name = "medical-ai-gpu-spot-env"
  type                     = "MANAGED"

  compute_resources {
    type = "SPOT"

    allocation_strategy = "SPOT_CAPACITY_OPTIMIZED"

    instance_type = [
      "p3.16xlarge",
      "p3.8xlarge",
      "g5.48xlarge",
      "g5.24xlarge",
    ]

    min_vcpus     = 0
    max_vcpus     = 512
    desired_vcpus = 0

    spot_iam_fleet_role = aws_iam_role.spot_fleet.arn

    subnets = aws_subnet.private[*].id

    security_group_ids = [aws_security_group.batch.id]

    instance_role = aws_iam_instance_profile.batch.arn
  }

  service_role = aws_iam_role.batch_service.arn
}
```

### 6.2 スケーリング設定

```hcl
# 時間帯別スケーリング（夜間・週末に集中実行）
resource "aws_autoscaling_schedule" "night_scale_up" {
  scheduled_action_name  = "night-scale-up"
  autoscaling_group_name = aws_autoscaling_group.batch.name

  min_size         = 0
  max_size         = 100
  desired_capacity = 50

  recurrence = "0 22 * * 1-5"  # 平日22時
}

resource "aws_autoscaling_schedule" "morning_scale_down" {
  scheduled_action_name  = "morning-scale-down"
  autoscaling_group_name = aws_autoscaling_group.batch.name

  min_size         = 0
  max_size         = 20
  desired_capacity = 0

  recurrence = "0 8 * * 1-5"  # 平日8時
}
```

### 6.3 コスト試算

| 構成 | 時間単価 | 月間使用時間 | 月額コスト |
|------|---------|-------------|-----------|
| p4d.24xlarge × 2（オンデマンド） | $64/h | 100h | $6,400 |
| p3.16xlarge × 4（スポット） | $28/h | 200h | $5,600 |
| FSx for Lustre (1.2TB) | - | 720h | $216 |
| **合計** | | | **$12,216** |

---

## 7. 監視・トラブルシューティング

### 7.1 監視メトリクス

| メトリクス | 閾値 | アラート |
|-----------|------|----------|
| GPU使用率 | < 50% | 非効率警告 |
| メモリ使用率 | > 90% | OOM警告 |
| ジョブ待機時間 | > 30分 | キャパシティ不足 |
| ジョブ失敗率 | > 10% | 調査必要 |

### 7.2 よくある問題と対処

| 問題 | 原因 | 対処 |
|------|------|------|
| RUNNABLE状態が長い | キャパシティ不足 | max_vcpus増加、インスタンスタイプ追加 |
| OOMKilled | メモリ不足 | メモリ設定増加、バッチサイズ削減 |
| スポット中断 | 価格上昇 | チェックポイント保存、リトライ設定 |
| FSxアクセス遅い | スループット不足 | per_unit_storage_throughput増加 |

### 7.3 チェックポイント設定

```python
# 学習スクリプトでのチェックポイント保存
import torch
import os

def save_checkpoint(model, optimizer, epoch, loss, path):
    """チェックポイントを保存"""
    torch.save({
        'epoch': epoch,
        'model_state_dict': model.state_dict(),
        'optimizer_state_dict': optimizer.state_dict(),
        'loss': loss,
    }, path)

def load_checkpoint(model, optimizer, path):
    """チェックポイントから復元"""
    if os.path.exists(path):
        checkpoint = torch.load(path)
        model.load_state_dict(checkpoint['model_state_dict'])
        optimizer.load_state_dict(checkpoint['optimizer_state_dict'])
        return checkpoint['epoch'], checkpoint['loss']
    return 0, None

# 定期的に保存（スポット中断対策）
for epoch in range(start_epoch, num_epochs):
    train_one_epoch(model, optimizer, data_loader)

    if epoch % 5 == 0:
        save_checkpoint(
            model, optimizer, epoch, loss,
            f"/fsx/checkpoints/checkpoint_epoch_{epoch}.pt"
        )
```

---

## 8. 変更履歴

| 日付 | バージョン | 変更内容 | 担当者 |
|------|-----------|---------|--------|
| 2026-01-XX | 1.0 | 初版作成 | - |

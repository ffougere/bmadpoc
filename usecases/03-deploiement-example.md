# Repository de Déploiement - Banking Platform AWS Services

## Structure Globale du Repository

```
aws-banking-platform/
├── README.md
├── .gitignore
├── global/
│   ├── terraform/
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   └── variables.tf
│   └── shared-modules/
├── use-cases/
│   ├── 01-financial-advisor/
│   ├── 02-fraud-detection/  
│   ├── 03-chatbot/
│   ├── 04-credit-scoring/
│   ├── 05-algo-trading/
│   ├── 06-portfolio-management/
│   ├── 07-regtech/
│   ├── 08-counterparty-risk/
│   ├── 09-digital-onboarding/
│   └── 10-liquidity-management/
├── scripts/
│   ├── deploy-all.sh
│   ├── deploy-use-case.sh
│   └── teardown.sh
└── monitoring/
    ├── cloudwatch/
    ├── grafana/
    └── prometheus/
```

---

## 1. **Plateforme de Conseil Financier Intelligent**

### **Dimensionnement & SLA**
- **Utilisateurs**: 500K clients retail, 2K conseillers
- **SLA**: 99.9% disponibilité, <2s temps de réponse
- **Volume**: 100K requêtes/jour, pics à 1K req/min

### **Structure Use Case**
```
use-cases/01-financial-advisor/
├── terraform/
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   ├── modules/
│   │   ├── cognito/
│   │   ├── api-gateway/
│   │   ├── eks/
│   │   ├── bedrock/
│   │   ├── opensearch/
│   │   ├── neptune/
│   │   └── eventbridge/
│   └── main.tf
├── kubernetes/
│   ├── advisor-engine/
│   ├── recommendation-service/
│   └── product-matcher/
├── docker/
├── third-party/
└── monitoring/
```

### **Infrastructure Terraform - Main**
```hcl
# use-cases/01-financial-advisor/terraform/main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "banking-platform-tfstate"
    key            = "financial-advisor/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

locals {
  environment = var.environment
  project     = "financial-advisor"
  
  common_tags = {
    Environment = local.environment
    Project     = local.project
    UseCase     = "01-financial-advisor"
    Owner       = "platform-team"
  }
}

# VPC Multi-AZ pour haute disponibilité
module "vpc" {
  source = "../../../global/shared-modules/vpc"
  
  name               = "${local.project}-${local.environment}"
  cidr               = var.vpc_cidr
  availability_zones = ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
  
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  
  enable_nat_gateway = true
  enable_vpn_gateway = false
  
  tags = local.common_tags
}

# Cognito pour authentification
module "cognito" {
  source = "./modules/cognito"
  
  user_pool_name        = "${local.project}-${local.environment}"
  enable_mfa            = var.environment == "prod"
  password_policy       = var.password_policy
  
  # SLA: Multi-région pour prod
  replica_regions = var.environment == "prod" ? ["eu-central-1"] : []
  
  tags = local.common_tags
}

# API Gateway avec throttling et caching
module "api_gateway" {
  source = "./modules/api-gateway"
  
  name                    = "${local.project}-${local.environment}"
  cognito_user_pool_arn   = module.cognito.user_pool_arn
  
  # SLA: Rate limiting basé sur l'environnement
  throttle_burst_limit = var.environment == "prod" ? 5000 : 1000
  throttle_rate_limit  = var.environment == "prod" ? 2000 : 500
  
  # Cache pour améliorer les performances
  cache_cluster_enabled = var.environment == "prod"
  cache_cluster_size    = var.environment == "prod" ? "1.6" : "0.5"
  
  tags = local.common_tags
}

# EKS Cluster multi-AZ
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = "${local.project}-${local.environment}"
  cluster_version = "1.28"
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets
  
  # Node groups pour différents workloads
  node_groups = {
    general = {
      instance_types = var.environment == "prod" ? ["m5.xlarge"] : ["t3.medium"]
      scaling_config = var.environment == "prod" ? {
        desired_size = 6
        max_size     = 12
        min_size     = 3
      } : {
        desired_size = 2
        max_size     = 4
        min_size     = 1
      }
    }
    
    compute_intensive = var.environment == "prod" ? {
      instance_types = ["c5.2xlarge"]
      scaling_config = {
        desired_size = 3
        max_size     = 9
        min_size     = 1
      }
      taints = [{
        key    = "workload-type"
        value  = "compute-intensive"
        effect = "NO_SCHEDULE"
      }]
    } : {}
  }
  
  # Add-ons pour monitoring et scaling
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
  
  tags = local.common_tags
}

# Bedrock pour IA générative
resource "aws_bedrock_model_invocation_logging_configuration" "advisor" {
  logging_config {
    embedding_data_delivery_enabled = true
    image_data_delivery_enabled     = true
    text_data_delivery_enabled      = true
    
    s3_config {
      bucket_name = aws_s3_bucket.bedrock_logs.id
      key_prefix  = "advice-generation/"
    }
    
    cloudwatch_config {
      log_group_name = aws_cloudwatch_log_group.bedrock.name
      role_arn       = aws_iam_role.bedrock_logging.arn
    }
  }
}

# Neptune pour graphe de connaissances
module "neptune" {
  source = "./modules/neptune"
  
  cluster_identifier = "${local.project}-${local.environment}"
  engine_version     = "1.2.1.0"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # SLA: Multi-AZ pour prod
  backup_retention_period = var.environment == "prod" ? 7 : 1
  preferred_backup_window = "03:00-04:00"
  
  instance_count = var.environment == "prod" ? 2 : 1
  instance_class = var.environment == "prod" ? "db.r5.xlarge" : "db.t3.medium"
  
  tags = local.common_tags
}

# OpenSearch pour recherche sémantique
module "opensearch" {
  source = "./modules/opensearch"
  
  domain_name    = "${local.project}-${local.environment}"
  engine_version = "OpenSearch_2.3"
  
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  
  # Configuration basée sur SLA
  instance_type  = var.environment == "prod" ? "r6g.large.search" : "t3.small.search"
  instance_count = var.environment == "prod" ? 3 : 1
  
  # Zone awareness pour prod
  zone_awareness_enabled = var.environment == "prod"
  
  # Chiffrement et backup
  encrypt_at_rest = true
  node_to_node_encryption = true
  
  snapshot_options = {
    automated_snapshot_start_hour = 23
  }
  
  tags = local.common_tags
}

# EventBridge pour orchestration
module "eventbridge" {
  source = "./modules/eventbridge"
  
  name_prefix = "${local.project}-${local.environment}"
  
  # Rules pour différents événements métier
  rules = [
    {
      name         = "client-profile-updated"
      description  = "Trigger when client profile is updated"
      event_pattern = jsonencode({
        source      = ["financial-advisor.client-service"]
        detail-type = ["Client Profile Updated"]
      })
      targets = [
        {
          arn      = module.sqs.recommendation_queue_arn
          id       = "recommendation-trigger"
        }
      ]
    },
    {
      name         = "market-data-changed"
      description  = "Trigger when market conditions change"
      event_pattern = jsonencode({
        source      = ["financial-advisor.market-service"]
        detail-type = ["Market Data Updated"]
      })
      targets = [
        {
          arn = module.lambda.portfolio_rebalance_arn
          id  = "portfolio-rebalance"
        }
      ]
    }
  ]
  
  tags = local.common_tags
}

# RDS pour données transactionnelles
module "rds" {
  source = "./modules/rds"
  
  identifier = "${local.project}-${local.environment}"
  
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.environment == "prod" ? "db.r6g.xlarge" : "db.t3.micro"
  
  allocated_storage = var.environment == "prod" ? 100 : 20
  max_allocated_storage = var.environment == "prod" ? 1000 : 100
  
  # Multi-AZ pour prod
  multi_az = var.environment == "prod"
  
  # Backup et maintenance
  backup_retention_period = var.environment == "prod" ? 7 : 1
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  # Sécurité
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = module.vpc.database_subnet_group
  
  # Performance Insights
  performance_insights_enabled = var.environment == "prod"
  
  tags = local.common_tags
}
```

### **Variables d'environnement**
```hcl
# use-cases/01-financial-advisor/terraform/environments/prod/terraform.tfvars

environment = "prod"

# Network configuration
vpc_cidr = "10.1.0.0/16"
public_subnets  = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
private_subnets = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]

# Cognito configuration
password_policy = {
  minimum_length                   = 12
  require_lowercase               = true
  require_numbers                 = true
  require_symbols                 = true
  require_uppercase               = true
  temporary_password_validity_days = 7
}

# Scaling configuration
eks_node_groups = {
  general = {
    instance_types = ["m5.xlarge"]
    scaling_config = {
      desired_size = 6
      max_size     = 12
      min_size     = 3
    }
  }
}
```

### **Services Tiers Recommandés**

#### **Prod (500K utilisateurs)**
```yaml
# third-party/prod-services.yaml

data_providers:
  market_data:
    provider: "Refinitiv Eikon"
    sla: "99.95% uptime"
    latency: "<100ms"
    cost: "$50K/month"
    
  credit_data:
    provider: "Experian APIs" 
    sla: "99.9% uptime"
    requests: "1M/month included"
    cost: "$15K/month"

external_services:
  document_processing:
    provider: "Google Document AI"
    sla: "99.9% uptime" 
    volume: "100K docs/month"
    cost: "$5K/month"
    
  notification_service:
    provider: "Twilio"
    sla: "99.95% uptime"
    channels: ["SMS", "Email", "Push"]
    volume: "1M messages/month"
    cost: "$8K/month"

security_services:
  identity_verification:
    provider: "Jumio"
    sla: "99.9% uptime"
    verifications: "50K/month"
    cost: "$25K/month"
    
  encryption:
    provider: "AWS KMS + HashiCorp Vault"
    sla: "99.99% uptime"
    cost: "$2K/month"

monitoring:
  apm:
    provider: "Datadog"
    hosts: "100 hosts"
    cost: "$3K/month"
    
  security_monitoring:
    provider: "Splunk Cloud"
    data_volume: "100GB/day"
    cost: "$10K/month"
```

#### **Dev/Staging (50K utilisateurs)**
```yaml
# third-party/dev-services.yaml

data_providers:
  market_data:
    provider: "Alpha Vantage API"
    sla: "99% uptime"
    requests: "500/min"
    cost: "$500/month"

external_services:
  notification_service:
    provider: "AWS SES + SNS"
    sla: "99.9% uptime"
    volume: "100K messages/month" 
    cost: "$200/month"

security_services:
  identity_verification:
    provider: "Mock service / AWS Cognito"
    cost: "$100/month"

monitoring:
  apm:
    provider: "AWS X-Ray + CloudWatch"
    cost: "$300/month"
```

### **Kubernetes Deployment**
```yaml
# kubernetes/advisor-engine/deployment.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: advisor-engine
  namespace: financial-advisor
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  selector:
    matchLabels:
      app: advisor-engine
  template:
    metadata:
      labels:
        app: advisor-engine
    spec:
      containers:
      - name: advisor-engine
        image: banking-platform/advisor-engine:latest
        ports:
        - containerPort: 8080
        env:
        - name: BEDROCK_REGION
          value: "eu-west-1"
        - name: NEPTUNE_ENDPOINT
          valueFrom:
            secretKeyRef:
              name: neptune-credentials
              key: endpoint
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: advisor-engine-service
spec:
  selector:
    app: advisor-engine
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: advisor-engine-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: advisor-engine
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

---

## 2. **Détection de Fraude en Temps Réel**

### **Dimensionnement & SLA**
- **Utilisateurs**: 2M clients, 50K transactions/minute
- **SLA**: 99.99% disponibilité, <100ms traitement
- **Volume**: 72M transactions/jour, pics à 200K/min

### **Structure & Configuration**
```
use-cases/02-fraud-detection/
├── terraform/
│   ├── modules/
│   │   ├── kinesis/
│   │   ├── lambda/
│   │   ├── dynamodb/
│   │   └── elasticache/
├── streaming/
│   ├── kafka-connect/
│   └── flink-jobs/
└── ml-models/
```

### **Infrastructure Spécialisée**
```hcl
# Kinesis Data Streams pour ingestion haute performance
module "kinesis" {
  source = "./modules/kinesis"
  
  name = "${local.project}-transactions-${local.environment}"
  
  # Dimensionnement pour le volume
  shard_count = var.environment == "prod" ? 100 : 10
  retention_period = 24
  
  # Auto-scaling basé sur la charge
  scaling_policy = {
    target_utilization = 70.0
    scale_out_cooldown = 60
    scale_in_cooldown  = 300
  }
  
  tags = local.common_tags
}

# DynamoDB pour cache de patterns de fraude
module "dynamodb_fraud_cache" {
  source = "./modules/dynamodb"
  
  table_name   = "${local.project}-fraud-patterns-${local.environment}"
  billing_mode = "PAY_PER_REQUEST"
  
  hash_key = "pattern_id"
  range_key = "timestamp"
  
  # Global tables pour multi-région
  replica_regions = var.environment == "prod" ? ["eu-central-1", "us-east-1"] : []
  
  # TTL pour expiration automatique
  ttl_attribute_name = "expires_at"
  ttl_enabled = true
  
  # Point-in-time recovery pour prod
  point_in_time_recovery_enabled = var.environment == "prod"
  
  tags = local.common_tags
}

# ElastiCache Redis Cluster pour cache haute performance
module "elasticache" {
  source = "./modules/elasticache"
  
  cluster_id = "${local.project}-cache-${local.environment}"
  
  # Configuration cluster mode
  engine_version = "7.0"
  node_type = var.environment == "prod" ? "cache.r6g.xlarge" : "cache.t3.micro"
  
  # Sharding pour performance
  num_cache_clusters = var.environment == "prod" ? 6 : 2
  replication_group_id = "${local.project}-rg-${local.environment}"
  
  # Multi-AZ pour haute disponibilité
  multi_az_enabled = var.environment == "prod"
  automatic_failover_enabled = var.environment == "prod"
  
  # Backup
  snapshot_retention_limit = var.environment == "prod" ? 5 : 1
  snapshot_window = "03:00-05:00"
  
  tags = local.common_tags
}

# Lambda pour traitement temps réel
resource "aws_lambda_function" "fraud_detector" {
  function_name = "${local.project}-fraud-detector-${local.environment}"
  
  # Configuration performance
  runtime = "python3.11"
  handler = "fraud_detector.handler"
  timeout = 30
  memory_size = var.environment == "prod" ? 3008 : 1024
  
  # Provisioned concurrency pour latence prévisible
  reserved_concurrent_executions = var.environment == "prod" ? 500 : 50
  
  # Code deployment
  filename = "../lambda/fraud-detector.zip"
  source_code_hash = filebase64sha256("../lambda/fraud-detector.zip")
  
  # Environment variables
  environment {
    variables = {
      DYNAMODB_TABLE = module.dynamodb_fraud_cache.table_name
      REDIS_ENDPOINT = module.elasticache.redis_endpoint
      BEDROCK_REGION = var.aws_region
      LOG_LEVEL = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }
  
  # VPC configuration pour accès aux services privés
  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.lambda.id]
  }
  
  # Dead letter queue
  dead_letter_config {
    target_arn = aws_sqs_queue.dlq.arn
  }
  
  tags = local.common_tags
}

# Provisioned Concurrency pour prod
resource "aws_lambda_provisioned_concurrency_config" "fraud_detector" {
  count = var.environment == "prod" ? 1 : 0
  
  function_name                     = aws_lambda_function.fraud_detector.function_name
  provisioned_concurrent_executions = 100
  qualifier                        = aws_lambda_function.fraud_detector.version
}
```

### **Services Tiers - Fraud Detection**

#### **Production**
```yaml
# third-party/fraud-detection-prod.yaml

fraud_intelligence:
  provider: "FICO Falcon Fraud Manager"
  sla: "99.99% uptime"
  capacity: "1M transactions/hour"
  cost: "$200K/year"
  
machine_learning:
  provider: "DataRobot MLOps"
  sla: "99.9% uptime"
  model_deployments: "unlimited"
  cost: "$100K/year"

threat_intelligence:
  provider: "ThreatMetrix"
  sla: "99.95% uptime"
  device_profiling: "included"
  cost: "$150K/year"

data_enrichment:
  geolocation:
    provider: "MaxMind GeoIP2"
    accuracy: "99.8% country level"
    cost: "$10K/year"
    
  device_intelligence:
    provider: "Sift Science"
    sla: "99.9% uptime"
    cost: "$50K/year"

real_time_scoring:
  provider: "Amazon Kinesis Analytics + Custom ML"
  latency: "<50ms"
  throughput: "1M events/second"
  cost: "$30K/month"
```

---

## 3. **Assistant Bancaire Conversationnel**

### **Dimensionnement & SLA**
- **Utilisateurs**: 1M clients actifs, 500 conversations/minute
- **SLA**: 99.95% disponibilité, <3s réponse
- **Volume**: 100K conversations/jour

### **Configuration Spécialisée**
```hcl
# use-cases/03-chatbot/terraform/main.tf

# Lex V2 pour NLU avancé
resource "aws_lexv2_bot" "banking_assistant" {
  name     = "${local.project}-assistant-${local.environment}"
  role_arn = aws_iam_role.lex_bot.arn
  
  # Configuration multi-langue
  data_privacy {
    child_directed = false
  }
  
  # Timeout configuration
  idle_session_ttl_in_seconds = 900
  
  tags = local.common_tags
}

# Connect pour escalade vers agents humains
resource "aws_connect_instance" "banking_support" {
  count = var.environment == "prod" ? 1 : 0
  
  identity_management_type = "CONNECT_MANAGED"
  inbound_calls_enabled    = true
  outbound_calls_enabled   = false
  
  instance_alias = "${local.project}-support-${local.environment}"
  
  tags = local.common_tags
}

# Bedrock pour génération de réponses contextuelles
resource "aws_bedrock_guardrail" "banking_guardrail" {
  name                      = "${local.project}-guardrail-${local.environment}"
  blocked_input_messaging   = "Cette demande ne peut pas être traitée par l'assistant."
  blocked_outputs_messaging = "Je ne peux pas fournir cette information."
  description              = "Guardrails pour assistant bancaire"
  
  # Filtres de contenu sensible
  content_policy_config {
    filters_config {
      input_strength  = "HIGH"
      output_strength = "HIGH"
      type           = "SEXUAL"
    }
    filters_config {
      input_strength  = "HIGH" 
      output_strength = "HIGH"
      type           = "VIOLENCE"
    }
    filters_config {
      input_strength  = "MEDIUM"
      output_strength = "MEDIUM"
      type           = "HATE"
    }
  }
  
  # Filtres de sujets interdits
  topic_policy_config {
    topics_config {
      name       = "investment_advice"
      definition = "Conseils d'investissement spécifiques ou recommandations d'achat/vente"
      examples   = ["Acheter cette action", "Investir dans ce fonds"]
      type       = "DENY"
    }
    topics_config {
      name       = "sensitive_data"
      definition = "Données sensibles comme mots de passe ou codes PIN"
      examples   = ["Quel est votre code PIN", "Donnez-moi votre mot de passe"]
      type       = "DENY"
    }
  }
  
  tags = local.common_tags
}

# Neptune pour base de connaissances bancaires
module "neptune_kb" {
  source = "./modules/neptune"
  
  cluster_identifier = "${local.project}-knowledge-${local.environment}"
  
  # Optimisé pour lectures fréquentes
  engine_version = "1.2.1.0"
  instance_class = var.environment == "prod" ? "db.r5.2xlarge" : "db.t3.medium"
  instance_count = var.environment == "prod" ? 3 : 1
  
  # Read replicas pour la charge de lecture
  read_replica_count = var.environment == "prod" ? 2 : 0
  
  # Configuration backup
  backup_retention_period = var.environment == "prod" ? 14 : 3
  preferred_backup_window = "02:00-04:00"
  
  tags = local.common_tags
}

# OpenSearch pour recherche dans la documentation
module "opensearch_docs" {
  source = "./modules/opensearch"
  
  domain_name = "${local.project}-docs-${local.environment}"
  
  # Configuration cluster
  instance_type = var.environment == "prod" ? "r6g.xlarge.search" : "t3.small.search"
  instance_count = var.environment == "prod" ? 6 : 1
  
  # Master nodes pour stabilité
  dedicated_master_enabled = var.environment == "prod"
  master_instance_type = var.environment == "prod" ? "r6g.medium.search" : null
  master_instance_count = var.environment == "prod" ? 3 : 0
  
  # Zone awareness
  zone_awareness_enabled = var.environment == "prod"
  availability_zone_count = var.environment == "prod" ? 3 : 1
  
  # Index templates pour documents bancaires
  index_templates = [
    {
      name = "banking-docs"
      patterns = ["docs-*", "faq-*", "procedures-*"]
      settings = {
        number_of_shards = var.environment == "prod" ? 3 : 1
        number_of_replicas = var.environment == "prod" ? 2 : 0
      }
    }
  ]
  
  tags = local.common_tags
}
```

### **Services Tiers - Chatbot**

#### **Production**
```yaml
# third-party/chatbot-prod.yaml

conversation_ai:
  provider: "Microsoft Bot Framework"
  sla: "99.9% uptime"
  concurrent_users: "unlimited"
  cost: "$5K/month"

nlp_enhancement:
  provider: "Google Dialogflow CX"
  sla: "99.95% uptime"
  requests: "10M/month"
  languages: 20
  cost: "$15K/month"

voice_services:
  text_to_speech:
    provider: "Amazon Polly"
    voices: "neural voices"
    characters: "10M/month"
    cost: "$2K/month"
    
  speech_to_text:
    provider: "Amazon Transcribe"
    minutes: "100K/month"
    real_time: true
    cost: "$3K/month"

sentiment_analysis:
  provider: "AWS Comprehend"
  requests: "1M/month"
  cost: "$1K/month"

translation:
  provider: "DeepL Pro"
  characters: "50M/month"
  languages: 31
  cost: "$8K/month"

knowledge_base:
  provider: "Microsoft QnA Maker"
  kb_size: "unlimited"
  queries: "1M/month"
  cost: "$3K/month"

integration:
  webchat:
    provider: "Zendesk Chat"
    agents: 50
    cost: "$7K/month"
    
  mobile_sdk:
    provider: "Twilio Flex"
    usage_based: true
    cost: "$10K/month"
```

---

## 4. **Scoring de Crédit Dynamique**

### **Dimensionnement & SLA**
- **Utilisateurs**: 200K demandes/mois, 50 agents crédit
- **SLA**: 99.9% disponibilité, <30s scoring
- **Volume**: Pics à 1K demandes/heure

### **Configuration ML/AI**
```hcl
# use-cases/04-credit-scoring/terraform/main.tf

# SageMaker pour MLOps
module "sagemaker_mlops" {
  source = "./modules/sagemaker"
  
  project_name = "${local.project}-${local.environment}"
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name used to prefix/tag resources"
  type        = string
  default     = "ticket-platform"
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "instance_type" {
  description = "EC2 instance type for the app tier"
  type        = string
  default     = "t3.micro"
}

variable "steady_state_capacity" {
  description = "Desired capacity during normal (non-spike) traffic"
  type        = number
  default     = 2

  validation {
    condition     = var.steady_state_capacity >= 1
    error_message = "Steady state capacity must be at least 1 instance."
  }
}

variable "peak_capacity" {
  description = "Maximum capacity to scale up to during an on-sale spike"
  type        = number
  default     = 10

  validation {
    condition     = var.peak_capacity >= var.steady_state_capacity
    error_message = "Peak capacity must be greater than or equal to steady state capacity."
  }
}

variable "alert_email" {
  description = "Email address to receive incident alerts"
  type        = string
}

variable "latency_threshold_seconds" {
  description = "p99 target response time (seconds) that triggers a latency alarm"
  type        = number
  default     = 2
}

variable "error_rate_threshold" {
  description = "Number of 5xx errors within the evaluation period that triggers an alarm"
  type        = number
  default     = 10
}
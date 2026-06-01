# Logistics and Fleet Management AWS Architecture

We are a trucking and logistics company based in Mersin, Türkiye. Managing a fleet of 250
trucks operating across Türkiye and to EU destinations (Bulgaria, Romania, Germany).

For our business case, we have decided on using AWS to deploy our company's cloud architecture.

1. [Introduction](#logistics-and-fleet-management-aws-architecture)
2. [IT Requirements](#it-requirements)
3. [Application](#application)
4. [Design Decisions](#design-decisions)
   1. [Networking](#networking)
   1. [Storage](#storage)
   1. [Computing](#computing)
   1. [Monitoring](#monitoring)

## IT Requirements

Must be able to support the following workload and cooperate with proper regulations:

- GPS data from 250 trucks, updated every 30 seconds = around 750 million data points/year.
- Warehouse management system for 3 Warehouse locations.
- Stored 2 year GPS tracking data (according to Turkish regulation).
- Two or more availabiliy zones for disaster recovery.

## Application

Run the following command from the root directory to run the fleet portal application.

```
cd app
python app.py
```

## Design Decisions

### Networking

- 1 VPC: 10.0.0.0/16
- 2 Public Subnets: 10.0.1.0/24, 10.0.2.0/24
- 2 Private Subnets: 10.0.10.0/24, 10.0.20.0/24
- Internet Gateway
- Public route table
- Private route table
- Subnets distributed across 2 Availability Zones

### Storage

- S3 bucket for fleet sample data
- S3 public access blocking
- S3 versioning
- S3 server-side encryption
- Sample JSON data uploaded to standard S3 storage
- Archived sample JSON data uploaded with S3 Glacier storage class

### Computing

- 8 EC2 instances total
- 2 EC2 instances in each subnet
- Public EC2 security group for SSH and HTTP
- Private EC2 security group for VPC-internal access
- Ubuntu Jammy AMI lookup
- Configurable EC2 instance type and key pair

### Monitoring - CloudWatch dashboard

- EC2 CPU utilization widgets
- EC2 status check widgets
- High CPU alarms for every EC2 instance
- Status check failure alarms for every EC2 instance
- Optional SNS email notifications for alarms

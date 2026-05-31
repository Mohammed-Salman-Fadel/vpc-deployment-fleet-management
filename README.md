# Logistics and Fleet Management AWS Architecture

We are a trucking and logistics company based in Mersin, Türkiye. Managing a fleet of 250
trucks operating across Türkiye and to EU destinations (Bulgaria, Romania, Germany).

For our business case, we have decided on using AWS to deploy our company's cloud architecture.

1. [Introduction](#logistics-and-fleet-management-aws-architecture)
2. [IT Requirements](#it-requirements)
3. [Application](#application)
4. [Design Decisions](#design-decisions)

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

- Networking

  - 2 Public Subnets

  - 2 Private Subnets

- Storage
- Computing
- Monitoring

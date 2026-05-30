# vpc-deployment-fleet-management

Set up a working deployment on a real cloud provider. It needs to include all of the following:

- At least one IaaS workload that actually runs something useful (an empty VM does
  not count)
- At least one PaaS or Serverless workload
- AVPCor VNet with a minimum of two subnets– one public, one private
- Astorage service holding actual data
- Monitoring and alerting that is turned on and working
- At least one piece of infrastructure deployed through code (Terraform, CloudFor
  mation, ARM templates, or Bicep)

Show at least 2 of the following on your own machines:

- Resource isolation– setting CPU or memory limits on different VMs
- Snapshot and rollback
- VMcloning
- Network isolation between VMs
- Live migration
- Aside-by-side comparison of containers and VMs

### Design Decisions

- Networking

  - 2 Public Subnets
  - 2 Private Subnets
  -

- Storage
- Computing
- Monitoring

### Usage

Run the following command from the root directory to run the fleet portal application.

```
cd app
python app.py
```

# Platform layout

Orchestrates all **platform team** resources:

1. **Org folders** — Platform, Dev, Prod  
2. **Folder policies** — what workload teams may create under Dev/Prod  
3. **Shared networks** — one shared VPC host project per environment  
4. **Workload projects** — team project + SA + WIF + attach to shared VPC  

No application infrastructure. Workload teams consume shared VPC and policies in their own repos.

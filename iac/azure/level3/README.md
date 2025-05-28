# Azure Container Registry and Container App - Level 3

This Terraform configuration creates:

1. **Azure Container Registry (ACR)** - For storing container images
2. **Azure Container App** - For running the zerotrust workload application
3. **Supporting infrastructure** - Log Analytics, managed identity, and RBAC

## Resources Created

- `azurerm_resource_group.acr_rg` - Resource group for all resources
- `azurerm_container_registry.acr` - Container registry with random suffix
- `azurerm_log_analytics_workspace.aca_logs` - Log Analytics for Container App logs
- `azurerm_container_app_environment.aca_env` - Container App Environment
- `azurerm_user_assigned_identity.aca_identity` - Managed identity for ACR access
- `azurerm_role_assignment.aca_acr_pull` - RBAC assignment for ACR pull access
- `azurerm_container_app.workload_app` - The main Container App

## Prerequisites

1. Azure CLI installed and authenticated
2. Terraform installed
3. A container image built and pushed to the ACR (see deployment steps below)

## Configuration

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your Azure AD details:
   - `azure_client_id` - Your Azure AD application client ID
   - `azure_tenant_id` - Your Azure AD tenant ID

## Deployment Steps

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Plan the deployment:**
   ```bash
   terraform plan
   ```

3. **Apply the configuration:**
   ```bash
   terraform apply
   ```

4. **Build and push the workload container image:**
   ```bash
   # Get ACR login server from terraform output
   ACR_LOGIN_SERVER=$(terraform output -raw acr_login_server)
   
   # Login to ACR using Azure CLI
   az acr login --name ${ACR_LOGIN_SERVER}
   
   # Build and push the image from the workload directory
   cd ../../../workload/example
   docker build -t ${ACR_LOGIN_SERVER}/zerotrust-workload:latest .
   docker push ${ACR_LOGIN_SERVER}/zerotrust-workload:latest
   
   # Return to terraform directory
   cd ../../iac/azure/level3
   ```

5. **Restart the Container App to pull the new image:**
   ```bash
   # The Container App will automatically restart and pull the new image
   # You can also force a restart using Azure CLI:
   az containerapp revision restart \
     --name zerotrust-workload-app \
     --resource-group zerotrust-acr-rg \
     --revision $(az containerapp revision list \
       --name zerotrust-workload-app \
       --resource-group zerotrust-acr-rg \
       --query "[0].name" -o tsv)
   ```

## Accessing the Application

After deployment, you can access the application using the URL from the terraform output:

```bash
# Get the application URL
terraform output container_app_url
```

The application will be available at the returned HTTPS URL.

## Security Features

- **Managed Identity**: The Container App uses a user-assigned managed identity to authenticate with ACR
- **RBAC**: Minimal permissions (AcrPull) granted to the managed identity
- **HTTPS Only**: Container App ingress is configured for HTTPS only
- **Azure AD Authentication**: The workload app supports Azure AD bearer token authentication

## Monitoring

- Container App logs are sent to the Log Analytics workspace
- You can view logs in the Azure Portal or using Azure CLI:
  ```bash
  az monitor log-analytics query \
    --workspace $(terraform output -raw log_analytics_workspace_id) \
    --analytics-query "ContainerAppConsoleLogs_CL | limit 100"
  ```

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

### this is final runbook script which will stop VMs. Only those VMs with autostop = true

# Input parameters
param(
 
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId = "Enter your sunscriptionID",
    
    [Parameter(Mandatory = $true)]
    [string]$UserAssignedIdentityClientId = "Enter your user managed Identity"
    
)


try {
    # Ensures you do not inherit an AzContext in your runbook
    Disable-AzContextAutosave -Scope Process

    # Connect using user-assigned managed identity
    Write-Output "Connecting to Azure using User-Assigned Managed Identity..."
    Connect-AzAccount -Identity -AccountId $UserAssignedIdentityClientId

    # Set context to your subscription
    Write-Output "Setting context to subscription: $SubscriptionId"
    Set-AzContext -SubscriptionId $SubscriptionId

    # Get all VMs in the subscription
    Write-Output "Getting all VMs in the subscription..."
    $vms = Get-AzVM

    # Check if any VMs were found
    if ($null -eq $vms -or $vms.Count -eq 0) {
        Write-Output "No VMs found."
        return
    }

    Write-Output "Found $($vms.Count) VMs"

    # Stop VMs with autostop = true tag
    foreach ($vm in $vms) {
        try {
            # Check for autostop tag
            $autostop = $vm.Tags["autostop"]

            if ($autostop -eq "true") {  # Case-insensitive comparison
                Write-Output "Stopping VM: $($vm.Name) in resource group: $($vm.ResourceGroupName) (autostop tag present)"
                $stopResult = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force

                if ($stopResult.Status -eq "Succeeded") {
                    Write-Output "Successfully stopped VM: $($vm.Name)"
                } else {
                    Write-Error "Failed to stop VM: $($vm.Name). Status: $($stopResult.Status)"
                }
            } else {
                Write-Output "Skipping VM: $($vm.Name) in resource group: $($vm.ResourceGroupName) (autostop tag NOT present or not 'true')"
            }
        } catch {
            Write-Error "Error processing VM $($vm.Name): $_"
            continue # Continue to the next VM even if one fails
        }
    }

    Write-Output "VM stop operations completed"

} catch {
    Write-Error "Error in runbook execution: $_"
    throw $_
} finally {
    # Clean up authentication context
    Write-Output "Cleaning up Azure context..."
    Clear-AzContext -Force
}
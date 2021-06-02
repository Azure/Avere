# Support Best Practices for Rendering

When you encounter any issue with M&E rendering:

1. Immediately create a support ticket acording to one of the following categories:
    1. **Quota** - use the [Quota Submission process](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/per-vm-quota-requests).  Notes:
        1. submit SPOT cores in units of 10,000
        1. if you have a PAYGO or sponsorship subscription, to go above about 300 standard cores or 1200 SPOT cores, you will need to convert your subscription to [invoice pay](https://docs.microsoft.com/en-us/azure/cost-management-billing/manage/pay-by-invoice).
    1. **HPC Cache** - use the [HPC Cache support process](https://docs.microsoft.com/en-us/azure/hpc-cache/hpc-cache-support-ticket)
    1. **Avere vFXT for Azure** - use the [Avere vFXT for Azure support Process](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-open-ticket#open-a-support-ticket-for-your-avere-vfxt)
    3. **Other** use the process [Create an Azure support request](https://docs.microsoft.com/en-us/azure/azure-portal/supportability/how-to-create-azure-support-request), and try to submit from the resource impacted.
    1. If this is a vFXT issue, submit a ticket per the [vFXT support instructions](https://docs.microsoft.com/en-us/azure/avere-vfxt/avere-vfxt-open-ticket#open-a-support-ticket-for-your-avere-vfxt)

2. Before submitting a ticket to support do the following:
    1. if you business is blocked, please set to SEV A, and briefly describe in the description how your business is blocked.
    1. in the CC add email "azurerendering at microsoft.com" (updating " at " with @). This helps our team become aware and drive the incident.

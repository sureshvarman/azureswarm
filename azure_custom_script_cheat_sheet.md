# VM deployment
Using std image (ubuntu 16.04 LTS) plus CustomScript
The scipt extension has no rollback, i.e. in case a deployment fails we usually have to re-deploy
the VM and script.
It has proven useful to download the custom script to execute from github directly.

## Script extension
```
            "properties": {
                "publisher": "Microsoft.Azure.Extensions",
                "type": "CustomScript",
                "typeHandlerVersion": "2.0",
                "autoUpgradeMinorVersion": true,
```

## Useful commands to troubleshoot target VM
sudo cat /var/log/azure/custom-script/handler.log
sudo dir /var/lib/waagent/custom-script/download/0
sudo cat /var/lib/waagent/custom-script/download/0/stdout

### On VM scale sets
sudo cat /var/log/waagent.log

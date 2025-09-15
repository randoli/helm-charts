# Randoli Helm Chart Public Registry

## How to install the LocalControl Plane & Agent

### Prerequisits.
You need to setup an Account using the [Signup page](https://signup.randoli.io/?product=observability%2Bcost) 
For more information please check the [Getting Start Guide](https://docs.insights.randoli.io/getting-started/step-0)

[!Tip]
If it's your first time, we recommend you read the `Getting Started Guide` and follow **guided onboarding flow** when you sign up for the account

### Helm Chart Installation
Create the namespace & apply the secrets downloaded from the Console
```
kubectl create ns randoli-agents
kubectl create -f xxxx-credentials.yaml
```

Add the repository
```
helm repo add randoli https://randoli.github.io/helm-charts
```

Install the Helm Chart
```
helm install randoli randoli/randoli-agent -n randoli-agents --set tags.costManagement=true --set tags.observability=true
```

For more details see [Randoli Product Documentation](https://docs.randoli.io/getting-started/step-0).

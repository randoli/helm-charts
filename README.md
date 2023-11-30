## Randoli Helm Chart Public Registry

### How to use it

Add the repository
```
helm repo add randoli https://randoli.github.io/helm-charts
```

Install the Operator chart
```
helm install randoli/app-director-agent-operator --generate-name
```

Example, to install the operator in a specific namespace
```
helm install randoli/app-director-agent-operator --generate-name -n <namespace_name> --create-namespace
```

Install the App Insights Agent Standalone chart
```
helm install randoli/app-insights-agent --generate-name
```

For more details see [App Director Documentation](https://docs.appdir.randolicloud.ca).

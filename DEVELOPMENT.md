# Development

## Publish charts

To publish a new chart, use the `helm package` command.
To update existing charts, make sure to change the chart version beforehand.

As an example, to publish the agent, run this:
```
helm package charts/randoli-agent 
```
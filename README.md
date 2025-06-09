<p align="center"><img src="https://raw.githubusercontent.com/Labs64/.github/refs/heads/master/assets/labs64-io-ecosystem.png"></p>

# Labs64.IO - Helm Charts

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

```
helm repo add <alias> https://labs64.github.io/labs64.io-helm-charts
```

If you had already added this repo earlier, run `helm repo update` to retrieve the latest versions of the packages.
You can then run `helm search repo <alias>` to see the charts.

To view all available versions:
```
helm repo update
helm search repo <alias>/<chart-name>
```

To view charts values:
```
helm show values <alias>/<chart-name>
```

To install the <chart-name> chart:
```
helm upgrade --install my-<chart-name> <alias>/<chart-name>
```

To uninstall the chart:
```
helm uninstall my-<chart-name>
```

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Labs64/labs64.io-helm-charts&type=Date)](https://www.star-history.com/#Labs64/labs64.io-helm-charts&Date)

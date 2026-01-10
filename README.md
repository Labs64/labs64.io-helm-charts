<p align="center"><img src="https://raw.githubusercontent.com/Labs64/.github/refs/heads/master/assets/labs64-io-ecosystem.png"></p>

# Labs64.IO :: Helm Charts

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/labs64io-helm-charts)](https://artifacthub.io/packages/search?repo=labs64io-helm-charts)
[![📖 Documentation](https://img.shields.io/badge/📖-Documentation-AB6543.svg)](https://github.com/Labs64/labs64.io-docs)

## Usage

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm is properly set up, add the repository as follows:
```
helm repo add <alias> https://labs64.github.io/labs64.io-helm-charts
```

If you have already added this repository, run the following command to retrieve the latest versions of the packages:
```
helm repo update
```

To list the available chart versions:
```
helm search repo <alias>
```

To view default chart values:
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

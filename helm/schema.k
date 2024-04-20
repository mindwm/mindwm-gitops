schema HelmChart:
    name: str
    repoURL: str

schema HelmRelease:
    namespace: str
    name: str
    chart: HelmChart
    version: str
    values?: any

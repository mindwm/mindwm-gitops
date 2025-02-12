module.exports = {
  kubernetes: {
    fileMatch: ['./main.yaml$'],
  },
  "argocd": {
    "fileMatch": ["./main.yaml$"]
  },
  "crossplane": {
    "fileMatch": ["./main.yaml$"]
  },
  regexManagers: [
    {
      description: "patches crossplane provider package version  https://regex101.com/r/3ug5iv/3",
      fileMatch: ["./main.yaml$"],
      matchStrings: [
        "apiVersion: pkg.crossplane.io\\/.*\\nkind: Provider\\n(.*\\n)+(.* package:[ ]*\"?)(?<depName>[a-z0-9\\.\\/\\-]*?):(?<currentValue>[a-z0-9\\.\\/\\-\\+]*?)\"?\\n"
      ],
      datasourceTemplate: "docker",
      versioningTemplate: "docker"
    },
]
}

module.exports = {
  kubernetes: {
    fileMatch: ['main.yaml$'],
  },
  "helm-requirements": {
    fileMatch: ['helm_requirements.yaml$'],
  },
  "argocd": {
    "fileMatch": ["main.yaml$"]
  }
}

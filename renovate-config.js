module.exports = {
  kubernetes: {
    fileMatch: ['main.yaml$', 'manifests/*.*', 'observability/.*'],
  },
  "helm-requirements": {
    fileMatch: ['helm_requirements.yaml$'],
  } 
}

(import 'github.com/thanos-io/thanos/mixin/alerts/sidecar.libsonnet') +
{
  values+:: {
    thanos+:: {
      version: '0.14.0',
      image: 'quay.io/thanos/thanos:v0.14.0',
      objectStorageConfig: {
        key: 'thanos.yaml',  // How the file inside the secret is called
        name: 'thanos-objectstorage',  // This is the name of your Kubernetes secret with the config
      },
    },
  },
  prometheus+: {
    local p = self,

    // Add the grpc port to the Prometheus service to be able to query it with the Thanos Querier
    service+: {
      spec+: {
        ports+: [
          { name: 'grpc', port: 10901, targetPort: 10901 },
        ],
      },
    },
    // Create a new service that exposes both sidecar's HTTP metrics port and gRPC StoreAPI
    serviceThanosSidecar: {
      apiVersion: 'v1',
      kind: 'Service',
      metadata: {
        name: 'prometheus-' + p.config.name + '-thanos-sidecar',
        namespace: p.config.namespace,
        labels: { prometheus: p.config.name, app: 'thanos-sidecar' },
      },
      spec: {
        ports: [
          { name: 'grpc', port: 10901, targetPort: 10901 },
          { name: 'http', port: 10902, targetPort: 10902 },
        ],
        selector: { app: 'prometheus', prometheus: p.name },
        clusterIP: 'None',
      },
    },
    prometheus+: {
      spec+: {
        thanos+: {
          version: $.values.thanos.version,
          image: $.values.thanos.image,
          objectStorageConfig: $.values.thanos.objectStorageConfig,
        },
      },
    },
    serviceMonitorThanosSidecar:
      {
        apiVersion: 'monitoring.coreos.com/v1',
        kind: 'ServiceMonitor',
        metadata: {
          name: 'thanos-sidecar',
          namespace: p.config.namespace,
          labels: {
            'app.kubernetes.io/name': 'prometheus',
          },
        },
        spec: {
          // Use the service's app label (thanos-sidecar) as the value for the job label.
          jobLabel: 'app',
          selector: {
            matchLabels: {
              prometheus: p.config.name,
              app: 'thanos-sidecar',
            },
          },
          endpoints: [
            {
              port: 'http',
              interval: '30s',
            },
          ],
        },
      },
  },
}

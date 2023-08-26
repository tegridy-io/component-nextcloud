// main template for nextcloud
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.nextcloud;
local appName = 'nextcloud';
local hasPrometheus = std.member(inv.applications, 'prometheus');

local namespace = kube.Namespace(params.namespace.name) {
  //   metadata+: {
  //     labels+: {
  //       'pod-security.kubernetes.io/enforce': 'restricted',
  //     },
  //   },
};


// PersistentVolumeClaims

local pvc = [
  kube.PersistentVolumeClaim(appName + '-config') {
    storage: '10Gi',
    storageClass: 'ceph-block',
  },
  kube.PersistentVolumeClaim(appName + '-data') {
    storage: '10Gi',
    storageClass: 'ceph-block',
  },
];


// Secrets
local secrets = kube.Secret(appName) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/instance': appName,
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/name': 'nextcloud',
    },
  },
  stringData: {
    [if params.database.enabled then 'postgres-username']: params.helmValues.postgresql.auth.username,
    [if params.database.enabled then 'postgres-password']: params.secrets.postgresql,
    [if params.redis.enabled then 'redis-password']: params.secrets.redis,
    'nextcloud-username': 'admin',
    'nextcloud-password': params.secrets.nextcloud,
    'nextcloud-token': params.secrets.token,
  },
};

// Deployment

local deployment = kube.Deployment(appName) {
  spec+: {
    replicas: params.replicaCount,
    template+: {
      spec+: {
        serviceAccountName: 'default',
        // securityContext: {
        //   seccompProfile: { type: 'RuntimeDefault' },
        // },
        containers_:: {
          default: kube.Container(appName) {
            image: '%(registry)s/%(repository)s:%(tag)s' % params.images.nextcloud,
            env_:: {
              PUID: 1000,
              PGID: 1000,
              TZ: 'Etc/UTC',
            },
            ports_:: {
              http: { containerPort: 80 },
            },
            resources: params.resources,
            // securityContext: {
            //   allowPrivilegeEscalation: false,
            //   capabilities: { drop: [ 'ALL' ] },
            // },
            volumeMounts_:: {
              config: { mountPath: '/config' },
              data: { mountPath: '/data' },
            } + {
              ['secret-' + s.metadata.name]: { mountPath: '/secrets/' + s.metadata.name }
              for s in secrets
            },
            // livenessProbe: {
            //   httpGet: {
            //     scheme: 'HTTP',
            //     port: 'http',
            //     path: '/-/healthy',
            //   },
            // },
          },
        },
        volumes_:: {
          config: kube.PersistentVolumeClaimVolume(pvc[0]),
          data: kube.PersistentVolumeClaimVolume(pvc[1]),
        } + {
          ['secret-' + s.metadata.name]: kube.SecretVolume(s)
          for s in secrets
        },
      },
    },
  },
};


// Define outputs below
{
  '00_namespace': if hasPrometheus then prom.RegisterNamespace(namespace) else namespace,
  //   '10_pvc': pvc,
  //   '10_deployment': deployment,
  '20_secrets': secrets,
}

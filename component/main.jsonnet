// main template for nextcloud
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.nextcloud;
local instanceName = inv.parameters._instance;
local appName = 'nextcloud';
local hasPrometheus = std.member(inv.applications, 'prometheus');

local namespace = kube.Namespace(params.namespace.name) {
  //   metadata+: {
  //     labels+: {
  //       'pod-security.kubernetes.io/enforce': 'restricted',
  //     },
  //   },
};


// Secrets
local secret = kube.Secret(appName) {
  metadata+: {
    labels+: {
      'app.kubernetes.io/instance': instanceName,
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/name': 'nextcloud',
    },
    namespace: params.namespace.name,
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

// Backup Schedule

local k8up = inv.parameters.backup_k8up.global_backup_config;

local schedule = [
  assert std.member(inv.applications, 'backup-k8up') : 'Component backup-k8up is not available';
  kube.Secret(appName + '-backup') {
    metadata+: {
      labels+: {
        'app.kubernetes.io/instance': instanceName,
        'app.kubernetes.io/managed-by': 'commodore',
        'app.kubernetes.io/name': appName + '-backup',
      },
      namespace: params.namespace.name,
    },
    stringData: {
      password: params.backup.password,
      accesskey: if params.backup.backend.accessKey == null then k8up.s3_credentials.accesskey else params.backup.backend.accessKey,
      secretkey: if params.backup.backend.secretKey == null then k8up.s3_credentials.secretkey else params.backup.backend.secretKey,
    },
  },
  kube._Object('k8up.io/v1', 'Schedule', appName) {
    metadata+: {
      labels+: {
        'app.kubernetes.io/instance': instanceName,
        'app.kubernetes.io/managed-by': 'commodore',
        'app.kubernetes.io/name': appName,
      },
      namespace: params.namespace.name,
    },
    spec+: {
      podSecurityContext: {
        runAsUser: 0,
      },
      backend: {
        repoPasswordSecretRef: {
          name: appName + '-backup',
          key: 'password',
        },
        s3: {
          endpoint: if params.backup.backend.endpoint == null then k8up.s3_endpoint else params.backup.backend.endpoint,
          bucket: params.backup.bucket,
          accessKeyIDSecretRef: {
            name: appName + '-backup',
            key: 'accesskey',
          },
          secretAccessKeySecretRef: {
            name: appName + '-backup',
            key: 'secretkey',
          },
        },
      },
      backup: {
        schedule: params.backup.schedule,
        failedJobsHistoryLimit: params.backup.keepFailed,
        successfulJobsHistoryLimit: params.backup.keepSuccess,
      },
      [if params.backup.check.enabled then 'check']: {
        schedule: params.backup.check.schedule,
        failedJobsHistoryLimit: params.backup.keepFailed,
        successfulJobsHistoryLimit: params.backup.keepSuccess,
      },
      [if params.backup.prune.enabled then 'prune']: {
        schedule: params.backup.prune.schedule,
        failedJobsHistoryLimit: params.backup.keepFailed,
        successfulJobsHistoryLimit: params.backup.keepSuccess,
        retention: params.backup.retention,
      },
    } + com.makeMergeable(params.backup.spec),
  },
];
//   archive:
//     schedule: '0 * * * *'
//     restoreMethod:
//       s3:
//         endpoint: http://10.144.1.224:9000
//         bucket: restoremini
//         accessKeyIDSecretRef:
//           name: backup-credentials
//           key: username
//         secretAccessKeySecretRef:
//           name: backup-credentials
//           key: password


// Define outputs below
{
  '00_namespace': if hasPrometheus then prom.RegisterNamespace(namespace) else namespace,
  '20_secrets': secret,
  [if params.backup.enabled then '30_backup']: schedule,
}

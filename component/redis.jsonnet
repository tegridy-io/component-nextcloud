// main template for nextcloud
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local redis = import 'lib/redis-operator.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.nextcloud;

local hasPrometheus = std.member(inv.applications, 'prometheus');
local hasOperator = std.member(inv.applications, 'redis-operator');


// CockroachDB

local replication = redis.replication('redis', params.namespace.name, params.redis.spec);


// Define outputs below
{
  '10_redis': replication,
}

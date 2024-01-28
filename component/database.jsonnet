// main template for nextcloud
local crdb = import 'lib/cockroach-operator.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prom = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.nextcloud;

local hasPrometheus = std.member(inv.applications, 'prometheus');
local hasOperator = std.member(inv.applications, 'cockroach-operator');


// CockroachDB

local cockroachdb = crdb.database('database', params.namespace.name, params.database.spec);


// Define outputs below
{
  '10_database': cockroachdb,
}

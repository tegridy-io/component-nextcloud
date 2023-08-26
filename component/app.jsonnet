local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.nextcloud;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('nextcloud', params.namespace);

{
  nextcloud: app,
}

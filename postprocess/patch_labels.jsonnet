local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();
// The hiera parameters for the component
local params = inv.parameters.nextcloud;

local metadataPatch = {
  metadata+: {
    labels+: {
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
};

local listTemplates = [
  {
    name: std.strReplace(name, '.yaml', ''),
    manifest: com.yaml_load_all(std.extVar('output_path') + '/' + name),
  }
  for name in com.list_dir(std.extVar('output_path'), basename=true)
];

local patchTemplate(manifest) = [
  content + metadataPatch
  for content in manifest
];

{
  [template.name]: patchTemplate(template.manifest)
  for template in listTemplates
}

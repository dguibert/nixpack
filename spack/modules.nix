packs:
{ name ? "modules"
, modtype ? "lmod" /* lmod or tcl */
, config ? {}
, pkgs /* packages to include, list of:
   pkg (spack derivation)
   { pkg = pkg; default = true; } (for default module)
   { pkg = pkg; environment = { ... }; projection = "{name}/{version}"; } (overrides config)
   { name = "name"; static = "content"; }
   { name = "name"; static = { template variables }; }
   */
, coreCompilers ? [packs.pkgs.compiler]
}:
let
jsons = {
  inherit config pkgs coreCompilers;
};
in
packs.spackBuilder ({
  args = ["-xc" "${packs.spackPython} ${./modules.py}"];
  inherit name modtype;
  withRepos = true;
} // builtins.mapAttrs (name: builtins.toJSON) jsons // {
  passAsFile = builtins.attrNames jsons;
}) // jsons

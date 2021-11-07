packs: spackPath: config: derivation ({
  inherit (packs.prefs) system;
  name = "spackConfig";
  builder = ./config.sh;
  sections = builtins.attrNames config;
  PATH = spackPath;
} // builtins.mapAttrs (n: v: builtins.toJSON { "${n}" = v; }) config)

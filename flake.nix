{
  description = "Flake for NixPACK";

  #inputs.spack = { url="github:spack/spack"; flake=false; };
  inputs.spack = { url="github:flatironinstitute/spack/fi-nixpack"; flake=false; };
  inputs.nixpkgs.url = "github:dguibert/nixpkgs/pu-nixpack";

  outputs = inputs: let
    nixpkgsFor = system: import inputs.nixpkgs {
      inherit system;
    };

    nixosPacks = system: let
      pkgs = nixpkgsFor system;
      gccWithFortran = pkgs.wrapCC (pkgs.gcc.cc.override {
        langFortran = true;
      });
    in inputs.self.lib.packs {
      inherit system;
      os = "nixos21";
      global.verbose = "true";
      spackConfig.config.source_cache="/tmp/spack_cache";
      spackPython = "${pkgs.python3}/bin/python3";
      spackEnv   = {
        # pure environment PATH
	#PATH="${pkgs.coreutils}/bin:${pkgs.gnumake}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.gnused}/bin:${pkgs.glib}/bin"; # glib: locale
        PATH="/run/current-system/sw/bin:${pkgs.gnumake}/bin:${pkgs.binutils.bintools}/bin";
        LOCALE_ARCHIVE="/run/current-system/sw/lib/locale/locale-archive";
      };

      package = {
        compiler = { name="gcc"; extern=gccWithFortran; version=gccWithFortran.version; };
      };
    };
  in {
    lib.packs = {
      ...
    }@args: import ./packs ({
      inherit (inputs) spack nixpkgs;
    } // args);

    packages.x86_64-linux = nixosPacks "x86_64-linux";

    defaultPackage.x86_64-linux = inputs.self.packages.x86_64-linux.hello;

  };
}

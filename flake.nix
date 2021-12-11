{
  description = "Flake for NixPACK";

  inputs.spack = { url="github:spack/spack"; flake=false; };
  #inputs.spack = { url="github:flatironinstitute/spack/fi-nixpack"; flake=false; };
  #inputs.spack = { url = "git+https://castle.frec.bull.fr:24443/bguibertd/spack.git"; flake=false; };
  #inputs.spack = { url = "git+https://gitlab:24443/bguibertd/spack.git"; flake=false; };
  inputs.nixpkgs.url = "github:dguibert/nixpkgs/pu-nixpack";

  outputs = inputs: let
    nixpkgsFor = system: import inputs.nixpkgs {
      inherit system;
      config = {
        replaceStdenv = import ./nixpkgs/stdenv.nix;
        allowUnfree = true;
        cudaSupport = true;
      };
      overlays = [(import ./nixpkgs/overlay.nix)];
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
        PATH=/*"/run/current-system/sw/bin:"
            +*/inputs.nixpkgs.lib.concatStringsSep ":"
            (builtins.map (x: "${x}/bin")
            [
              pkgs.bash
              pkgs.coreutils
              pkgs.gnumake
              pkgs.gnutar
              pkgs.gzip
              pkgs.bzip2
              pkgs.xz
              pkgs.gawk
              pkgs.gnused
              pkgs.gnugrep
              pkgs.glib
              pkgs.binutils.bintools # glib: locale
              pkgs.patch
              pkgs.texinfo
              pkgs.diffutils
              pkgs.pkgconfig
              pkgs.gitMinimal
              pkgs.findutils
            ]);
        #PATH="/run/current-system/sw/bin:${pkgs.gnumake}/bin:${pkgs.binutils.bintools}/bin";
        LOCALE_ARCHIVE="/run/current-system/sw/lib/locale/locale-archive";
        LIBRARY_PATH=/*"/run/current-system/sw/bin:"
            +*/inputs.nixpkgs.lib.concatStringsSep ":"
            (builtins.map (x: "${x}/lib")
            [
              (inputs.nixpkgs.lib.getLib pkgs.binutils.bintools) # ucx (configure fails) libbfd not found
	    ]);
      };

      package = {
        compiler = { name="gcc"; extern=gccWithFortran; version=gccWithFortran.version; };
        perl = { extern=pkgs.perl; version=pkgs.perl.version; };
        openssh = { extern=pkgs.openssh; version=pkgs.openssh.version; };
        openssl = { extern=pkgs.symlinkJoin { name="openssl"; paths = [ pkgs.openssl.all ]; }; version=pkgs.openssl.version; };
        openmpi = {
          version = "4.1";
          variants = {
            fabrics = {
              none = false;
              ucx = true;
            };
            schedulers = {
              none = false;
              slurm = false;
            };
            pmi = false;
            pmix = false;
            static = false;
            thread_multiple = true;
            legacylaunchers = true;
          };
        };
      };
      repoPatch = {
        dyninst = spec: old: {
          patches = [ ./patch/dyninst-nixos.patch ];
        };
        openmpi = spec: old: {
          build = {
            setup = ''
              configure_args = pkg.configure_args()
              if spec.satisfies("~pmix"):
                if '--without-mpix' in configure_args: configure_args.remove('--without-pmix')
              pkg.configure_args = lambda: configure_args
            '';
          };
        };
      };
    };

    a64fxPacks = system: let
      pkgs = nixpkgsFor system;
      gccWithFortran = pkgs.wrapCC (pkgs.gcc.cc.override {
        langFortran = true;
      });
      rpmVersion = pkg: inputs.self.lib.capture ["/bin/rpm" "-q" "--queryformat=%{VERSION}" pkg];
      rpmExtern = pkg: { extern = "/usr"; version = rpmVersion pkg; };
    in inputs.self.lib.packs {
      inherit system;
      os = "rhel8";
      global.verbose = "true";
      spackConfig.config.source_cache="/software/spack/mirror";
      spackPython = "${pkgs.python3}/bin/python3";
      spackEnv   = {
        # pure environment PATH
	#PATH="${pkgs.coreutils}/bin:${pkgs.gnumake}/bin:${pkgs.gnutar}/bin:${pkgs.gzip}/bin:${pkgs.gnused}/bin:${pkgs.glib}/bin"; # glib: locale
        PATH="/home_nfs/bguibertd/.home-aarch64/.nix-profile/bin:/bin:/usr/bin:/usr/sbin";
        LOCALE_ARCHIVE="/run/current-system/sw/lib/locale/locale-archive";
      };
      repoPatch = {
        openmpi = spec: old: {
          build = {
            setup = ''
              configure_args = pkg.configure_args()
              if spec.satisfies("~pmix"):
                if '--without-mpix' in configure_args: configure_args.remove('--without-pmix')
              pkg.configure_args = lambda: configure_args
            '';
          };
        };
      };

      package = {
        #compiler = { name="gcc"; extern=gccWithFortran; version=gccWithFortran.version; };
        compiler = {
          name = "gcc";
        } // rpmExtern "gcc";

        openmpi = {
          version = "4.1";
          variants = {
            fabrics = {
              none = false;
              #ofi = true;
              ucx = true;
              #psm = true;
              #psm2 = true;
              #verbs = true;
              knem = true;
            };
            schedulers = {
              none = false;
              slurm = true;
            };
            pmi = true;
            pmix = false;
            static = false;
            thread_multiple = true;
            legacylaunchers = true;
          };
        };
        autoconf = rpmExtern "autoconf";
        automake = rpmExtern "automake";
        bzip2 = rpmExtern "bzip2";
        diffutils = rpmExtern "diffutils";
        libtool = rpmExtern "libtool";
        m4 = rpmExtern "m4";
        openssh = rpmExtern "openssh";
        #openssl = rpmExtern "openssl" // {
        #  variants = {
        #    fips = false;
        #  };
        #};
        pkgconfig = rpmExtern "pkgconf";
        #perl = rpmExtern "perl";
        slurm = rpmExtern "slurm" // {
          variants = {
            #pmix = true;
            hwloc = true;
          };
        };
        ucx = {
          variants = {
            thread_multiple = true;
            cma = true;
            rc = true;
            dc = true;
            ud = true;
            mlx5-dv = true;
            ib-hw-tm = true;
            knem = true;
            rocm = true;
          };
        };

      };
    };

    modulesConfig = {
      config = {
        hierarchy = ["mpi"];
        hash_length = 0;
        #projections = {
        #  # warning: order is lost
        #  "package+variant" = "{name}/{version}-variant";
        #};
        prefix_inspections = {
          "lib" = ["LIBRARY_PATH"];
          "lib64" = ["LIBRARY_PATH"];
          "lib/intel64" = ["LIBRARY_PATH"]; # for intel
          "include" = ["C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"];
          "" = ["{name}_ROOT"];
        };
        all = {
          autoload = "none";
          prerequisites = "direct";
          suffixes = {
            "^mpi" = "mpi";
            "^cuda" = "cuda";
          };
          filter = {
            environment_blacklist = ["CC" "FC" "CXX" "F77"];
          };
        };
        openmpi = {
          environment = {
            set = {
              OPENMPI_VERSION = "{version}";
            };
          };
        };
      };
    };
  in {
    lib = (import packs/lib.nix) // {
      packs = {
        ...
      }@args: import ./packs ({
        inherit (inputs) spack nixpkgs;
      } // args);
    };


    packages.x86_64-linux = let packs = nixosPacks "x86_64-linux"; in packs // {
      mods = packs.modules (inputs.self.lib.recursiveUpdate modulesConfig ({
        pkgs = [
          packs.pkgs.openmpi
        ];
      }));
      #modSite
      #intelPacks
    };
    packages.aarch64-linux = let packs = a64fxPacks "aarch64-linux"; in packs // {
      mods = packs.modules (inputs.self.lib.recursiveUpdate modulesConfig ({
        pkgs = [
          packs.pkgs.openmpi
        ];
      }));
      #modSite
      #intelPacks
    };

    defaultPackage.x86_64-linux = inputs.self.packages.x86_64-linux.hello;

  };
}

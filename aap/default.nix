{ target ? "x86_64"
, cudaarch ? "60,70,80"
}:
let
  lib = corePacks.lib;

  nixpkgsSrc = {
    url = "https://github.com/dguibert/nixpkgs";
    ref = "pu-nixpack";
    rev = "ecd445b9d09c4740409bc204d2f98d88b9c884cd";
    #url = "https://github.com/NixOS/nixpkgs";
    #ref = "master";
    #rev = "72bab23841f015aeaf5149a4e980dc696c59d7ca";

    #url = "https://github.com/NixOS/nixpkgs";
    #ref = "release-21.05";
    #rev = "2fd5c69fa6057870687a6589a8c95da955188f91";
  };

  isLDep = builtins.elem "link";
  isRDep = builtins.elem "run";
  isRLDep = d: isLDep d || isRDep d;

  rpmVersion = pkg: lib.capture ["/bin/rpm" "-q" "--queryformat=%{VERSION}" pkg];
  rpmExtern = pkg: { extern = "/usr"; version = rpmVersion pkg; };

  corePacks = import ../packs {
    label = "core";
    /* packs prefs */
    system = builtins.currentSystem;
    os = "rhel8";

    /* where to get the spack respository. Note that since everything depends on
       spack, changing the spack revision will trigger rebuilds of all packages.
       Can also be set a path (string) to an existing spack install, which will
       eliminate the dependency and also break purity, so can cause your repo
       metadata to get out of sync, and is not recommended for production.
       See also repos and repoPatch below for other ways of updating packages
       without modifying the spack repo.  */
    #spackSrc = {
    #  /* default:
    #  url = "git://github.com/spack/spack"; */
    #  url = "http://github.com/spack/spack";
    #  ref = "develop";
    #  #rev = "b4c6c11e689b2292a1411e4fc60dcd49c929246d";
    #};
    #spackSrc = {
    #  url = "/home_nfs/bguibertd/software-cepp-spack/spack";
    #  ref = "develop";
    #};
    #spackSrc = {
    #  url = "https://github.com/flatironinstitute/spack";
    #  ref = "fi-nixpack";
    ##  rev = "9526a13086fbc1790814edb84cdd9b65dbfc8f90";
    ##  #ref = "develop";
    #};
    spackSrc = {
      url = "https://github.com/flatironinstitute/spack";
      ref = "fi-nixpack";
      rev = "2311242d266d90726222002a262b50a165adb6bf";
    };


    /* extra config settings for spack itself.  Can contain any standard spack
       configuration, but don't put compilers (automatically generated), packages
       (based on package preferences below), or modules (passed to modules
       function) here. */
    spackConfig = {
      config = {
        /* must be set to somewhere your nix builder(s) can write to */
        source_cache = "/software/spack/mirror";
      };
    };
    /* environment for running spack. spack needs things like python, cp, tar,
       etc.  These can be string paths to the system or to packages/environments
       from nixpkgs or similar, but regardless need to be external to nixpacks. */
    spackPython = "/usr/bin/python3";
    spackPath = "/bin:/usr/bin";

    /* packs can optionally include nixpkgs for additional packages or bootstrapping.
       omit to disable. */
    inherit nixpkgsSrc;

    /* additional spack repos to include by path, managed by nixpack.
       These should be normal spack repos, including repo.yaml, and are prepended
       to any configured spack repos.
       Repos specified here have the advantage of correctly managing nix
       dependencies, so changing a package will only trigger rebuilds of
       it and dependent packages.
       Theoretically you could copy the entire spack builtins repo here and
       manage package updates that way, leaving spackSrc at a fixed revision.
       However, if you update the repo, you'll need to ensure compatibility with
       the spack core libraries, too. */
    repos = [
      ../spack/repo
    ];
    /* updates to the spack repo (see patch/default.nix for examples) */
    repoPatch = {
      openmpi = spec: old: {
        build = {
          setup = ''
            configure_args = pkg.configure_args()
            configure_args.append('CPPFLAGS=-I/usr/include/infiniband')
            if spec.satisfies("~pmix"):
              configure_args.remove('--without-pmix')
            pkg.configure_args = lambda: configure_args
          '';
        };
      };

    };

    /* global defaults for all packages (merged with per-package prefs) */
    global = {
      /* spack architecture target */
      inherit target;
      /* set spack verbose to print build logs during spack bulids (and thus
         captured by nix).  regardless, spack also keeps logs in pkg/.spack.  */
      verbose = true;
      /* enable build tests (and test deps) */
      tests = false;
      /* how to resolve dependencies, similar to concretize together or separately.
         fixedDeps = false:  Dependencies are resolved dynamically based on
           preferences and constraints imposed by each depender.  This can result
           in many different versions of each package existing in packs.
         fixedDeps = true:  Dependencies are resolved only by user prefs, and an
           error is produced if dependencies don't conform to their dependers'
           constraints.  This ensures only one version of each dependent package
           exists within packs.  Different packs with different prefs may have
           different versions.  Top-level packages explicitly resolved with
           different prefs or dependency prefs may also be different.  Virtuals
           are always resolved (to a package name) dynamically.
         this can be overridden per-package for only that package's dependencies.  */
      fixedDeps = true;
      /* How to find dependencies.  Normally dependencies are pulled from other
         packages in this same packs.  In some cases you may want some or all
         dependencies for a package to come from a different packs, perhaps
         because you don't care if build-only dependencies use the same compiler
         or python version.  This lets you override where dependencies come from.
         It takes two optional arguments:
           * list of dependency types (["build" "link" "run" "test"])
           * the name of the dependent package
         And should return either:
           * null, meaning use the current packs default
           * an existing packs object, to use instead
           * a function taking package preferences to a resolved package (like
             packs.getResolver).  In this case, prefs will be {} if fixedDeps =
             true, or the dependency prefs from the parent if fixedDeps = false.
      resolver = [deptype: [name: <packs | prefs: pkg>]]; */
      /* any runtime dependencies use the current packs, others fall back to core */
      resolver = deptype:
        if isRLDep deptype
          then null else corePacks;
    };
    /* package-specific preferences */
    package = {
      /* compiler is an implicit virtual dependency for every package */
      compiler = bootstrapPacks.pkgs.compiler;
      /* preferences for individual packages or virtuals */
      /* get cpio from system:
      cpio = {
        extern = "/usr";
        version = "2.11";
      }; */
      cpio = rpmExtern "cpio"; # some intel installers need this -- avoid compiler dependency
      /* specify virtual providers: can be (lists of) package or { name; ...prefs } */
      /* java = { name = "openjdk"; version = "10"; }; */
      /* use gcc 7.x:
      gcc = {
        version = "7";
      }; */
      /* enable cairo+pdf:
      cairo = {
        variants = {
          pdf = true;
        };
      }; */
      #curl = { version="7.61.1"; extern = "/usr"; };
      gdbm = {
        # for perl
        version = "1.19";
        # failing
        tests = false;
      };
      hdf5 = {
        version = "1.10";
        variants = {
          hl = true;
          fortran = true;
          cxx = true;
          threadsafe = true; # for cdo
        };
      };
      knem    = { version="1.1.4.90"; extern = "/opt/knem-1.1.4.90mlnx1"; };
      # lua: canot find -ltinfow
      #ncurses  = { version="6.1.20180224"; variants.termlib=true; variants.abi="6"; extern = "/usr"; };
      libevent = {
        # for pmix
        version = "2.1.8";
      };
      mesa18 = {
        variants = {
          llvm = false; #hip-rocclr dependency mesa18: package mesa18@18.3.6+glx+llvm~opengles+osmesa swr=~avx,~avx2,~knl,+none,~skx does not match dependency constraints {"variants":{"llvm":false,"swr":"none"},"version":"18.3:"}
        };
      };
      #mpi = [ corePacks.pkgs.openmpi corePacks.pkgs.intel-mpi ];
      nix = {
        variants = {
          storedir = let v = builtins.getEnv "NIX_STORE_DIR"; in if v == "" then "none" else v;
          statedir = let v = builtins.getEnv "NIX_STATE_DIR"; in if v == "" then "none" else v;
          sandboxing = false;
        };
      };
      shadow = rpmExtern "shadow-utils";
      /* use an external slurm: */
      slurm = {
        extern = "/usr";
        version = "19.05.8";
        variants = {
          #pmix = true;
          hwloc = true;
        };
      };
      openjpeg = {
        version = "2.3"; # eccodes dependency openjpeg: package openjpeg@2.4.0~ipo build_type=RelWithDebInfo does not match dependency constraints {"version":"1.5.0:1.5,2.1.0:2.3"}
      };
      openblas = {
        version = "0.3.15";
        variants = {
          threads = "pthreads";
        };
      };
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
      openssl = { version="1.1.1g"; extern = "/usr"; };
      # freetype: has conflicts: %intel freetype-2.8 and above cannot be built with icc (does not support __builtin_shuffle)

      freetype.depends.compiler = bootstrapPacks.pkgs.compiler;
      rdma-core.depends.compiler = bootstrapPacks.pkgs.compiler;
      openssh.depends.compiler = bootstrapPacks.pkgs.compiler;
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
        };
      };

      #berkeley-db = {
      #  extern = nixpkgs.db;
      #  version = (builtins.parseDrvName nixpkgs.db.name).version;
      #};
    };

  };

  /* A set of packages with different preferences, based on packs above.
     This set is used to bootstrap gcc, but other packs could also be used to set
     different virtuals, versions, variants, compilers, etc.  */
  bootstrapPacks = corePacks.withPrefs {
    label = "bootstrap";
    global = {
      target = "x86_64";
      resolver = null;
      tests = false;
    };
    package = {
      /* must be set to an external compiler capable of building compiler (above) */
      compiler = {
        name = "gcc";
      } // rpmExtern "gcc";

      autoconf = rpmExtern "autoconf";
      automake = rpmExtern "automake";
      bzip2 = rpmExtern "bzip2";
      diffutils = rpmExtern "diffutils";
      libtool = rpmExtern "libtool";
      m4 = rpmExtern "m4";
      ncurses = rpmExtern "ncurses" // {
        variants = {
          termlib = true;
          abi = "6";
        };
      };
      openssh = rpmExtern "openssh";
      openssl = rpmExtern "openssl" // {
        variants = {
          fips = false;
        };
      };
      perl = rpmExtern "perl";
      pkgconfig = rpmExtern "pkgconfig";
      psm = {};
      zlib = rpmExtern "zlib";
    };
  };

  intelPacks = corePacks.withPrefs {
    label = "intel";
    package = {
      compiler = { name = "intel"; };
      intel = { version="20.0.4"; };
    };
  };

  intelOneApiPacks = corePacks.withPrefs {
    label = "intel-oneapi";
    package = {
      compiler = { name = "oneapi"; };
      #oneapi = [ { name = "intel-oneapi-compilers"; } ];
      # /dev/shm/nix-build-ucx-1.11.2.drv-0/bguibertd/spack-stage-ucx-1.11.2-p4f833gchjkggkd1jhjn4rh93wwk2xn5/spack-src/src/ucs/datastruct/linear_func.h:147:21: error: comparison with infinity always evaluates to false in fast floating point mode> if (isnan(x) || isinf(x)) {
      ucx = corePacks.pkgs.ucx // {
        depends.compiler = bootstrapPacks.pkgs.compiler;
      };
    };
  };

  mkCompilers = base: gen:
    builtins.map (compiler: gen (rec {
      inherit compiler;
      isCore = compiler == corePacks.pkgs.compiler;
      packs = if isCore then base else
        base.withCompiler compiler;
      defaulting = pkg: { default = isCore; inherit pkg; };
    }))
    [
      corePacks.pkgs.compiler
      (corePacks.pkgs.gcc.withPrefs { version = "10.2"; })
      #(corePacks.pkgs.gcc.withPrefs { version = "11"; })
      intelPacks.pkgs.compiler
    ];

  mkMpis = base: gen:
    builtins.map (mpi: gen {
      inherit mpi;
      packs = base.withPrefs {
        package = {
          inherit mpi;
        };
        global = {
          variants = {
            mpi = true;
          };
        };
        package = {
          fftw = {
            variants = {
              precision = {
                quad = false;
              };
            };
          };
        };
      };
      isOpenmpi = mpi.name == "openmpi";
      isCore = mpi == { name = "openmpi"; };
    })
    [
      { name = "openmpi"; }
      { name = "openmpi";
        variants.cuda=true;
        depends = {
          hwloc.variants.cuda=true;
        };
      }
      { name = "intel-mpi"; }
    ];

  withPython = packs: py: let
    /* we can't have multiple python versions in a dep tree because of spack's
       environment polution, but anything that doesn't need python at runtime
       can fall back on default */
    ifHasPy = p: o: name: prefs:
      let q = p.getResolver name prefs; in
      if builtins.any (p: p.spec.name == "python") (lib.findDeps (x: isRLDep x.deptype) q)
        then q
        else o.getResolver name prefs;
    pyPacks = packs.withPrefs {
      label = "${packs.label}.python";
      package = {
        python = py;
      };
      global = {
        resolver = deptype: ifHasPy pyPacks
          (if isRLDep deptype
            then packs
            else corePacks);
      };
    };
    in pyPacks;

  corePython = { version = "3.8"; };

  mkPythons = base: gen:
    builtins.map (python: gen (rec {
      inherit python;
      isCore = python == corePython;
      packs = withPython base python;
    }))
    [
      corePython
      #{ version = "3.9"; }
    ];

  pyView = pl: corePacks.pythonView {
    pkgs = lib.findDeps (x: lib.hasPrefix "py-" x.name) pl;
  };


  /* packages that we build both with and without mpi */
  optMpiPkgs = useMPI: packs: with (packs.withPrefs {
    global = {
      variants = {
        mpi = useMPI;
      };
    };
  }).pkgs; [
    #boost
    cdo
    (fftw.withPrefs { version = "2"; variants = { precision = { long_double = false; quad = false; }; }; })
    fftw
    (hdf5.withPrefs { version = "1.8"; })
    { pkg = hdf5; # default 1.10
      default = true;
    }
    (hdf5.withPrefs { version = "1.12"; })
    netcdf-c
    netcdf-fortran
  ];

  pkgExtensions = f: pkgs:
    let ext = builtins.concatStringsSep ", " (map
      (p: f (p.spec.name + "/" + p.spec.version)) pkgs);
    in ''
      extensions("${ext}")
    '';

  preExtensions = pre: view: pkgExtensions
    (lib.takePrefix pre)
    (builtins.filter (p: lib.hasPrefix pre p.spec.name) view.pkgs);

  # XXX these spack names don't quite match the modules
  pyExtensions = preExtensions "py-";
  rExtensions = preExtensions "r-";

  pkgStruct = {
    pkgs = with corePacks.pkgs; [
      cloc
      cmake
      cuda
      curl
      #valgrind # cannot find -lubsan
      hip
      (hipfft.withPrefs { depends.rocfft.variants.amdgpu_target= { gfx906=true; gfx908=true; }; })
      intel-mpi
    ]
    ++
    map (v: {
      pkg = intel.withPrefs
        { inherit (v) version; extern = "/opt/intel/compilers_and_libraries_${v.path}"; };
      }) [
        # error: intel-parallel-studio: has conflicts: +mpi
        # conflicts('+mpi',       when='@professional.0:professional')
        #{ version = "cluster.2017.7"; path = "2017.7.259"; }
        #{ version = "cluster.2020.4"; path = "2020-4"; }
        #{ version="cluster.2016.4.258"; path="2016.4.258"; }
        #{ version="cluster.2017.7.259"; path="2017.7.259"; }
        #{ version="cluster.2017.8.262"; path="2017.8.262"; }
        #{ version="cluster.2018.0.128"; path="2018.0.128"; }
        #{ version="cluster.2018.1.163"; path="2018.1.163"; }
        #{ version="cluster.2018.2.199"; path="2018.2.199"; }
        #{ version="cluster.2018.3.222"; path="2018.3.222"; }
        #{ version="cluster.2018.5.274"; path="2018.5.274"; }
        #{ version="cluster.2019.1.144"; path="2019.1.144"; }
        #{ version="cluster.2019.2.187"; path="2019.2.187"; }
        #{ version="cluster.2019.3.199"; path="2019.3.199"; }
        #{ version="cluster.2019.4.243"; path="2019.4.243"; }
        #{ version="cluster.2019.5.281"; path="2019.5.281"; }
        #{ version="cluster.2019.6"; path="2019.6.324"; }
        #{ version="cluster.2020.0.166"; path="2020.0.166"; }
        #{ version="cluster.2020.1.217"; path="2020.1.217"; }
        #{ version="cluster.2020.2.254"; path="2020.2.254"; }
        #{ version="cluster.2020.4.304"; path="2020.4.304"; }
        #{ version="cluster.2020.4.317"; path="2020.4.317"; }
        #{ version="cluster.2020.4.319"; path="2020.4.319"; }
        { version="19.1.3"; path="2020.4.304"; }
      ]
    ;

    compilers = mkCompilers corePacks (comp: comp // {
      pkgs = with comp.packs.pkgs; [
        (comp.defaulting compiler)
      ] ++
      optMpiPkgs false comp.packs;

      mpis = mkMpis comp.packs (mpi: mpi // {
        pkgs = with mpi.packs.pkgs;
          lib.optionals mpi.isOpenmpi ([
            mpi.packs.pkgs.mpi # others are above, compiler-independent
          ]
        )
        ++ [
          osu-micro-benchmarks
        ] ++
        optMpiPkgs true mpi.packs
        ++
        lib.optionals comp.isCore (lib.optionals mpi.isOpenmpi [
          ior
        ]);

        pythons = mkPythons mpi.packs (py: py // {
          view = py.packs.pythonView { pkgs = with py.packs.pkgs; [
            py-mpi4py
            py-h5py
          ]; };
          pkgs = lib.optionals (py.isCore && mpi.isCore) (with py.packs.pkgs; [
          ]);
        });
      });

      pythons = mkPythons comp.packs (py: py // {
        view = with py.packs.pkgs; (pyView ([
          python
          py-dask
          py-h5py
          py-matplotlib
          py-pandas
          py-virtualenv
        ])).overrideView {
        };
      });
    });
  };

  nixpkgs = with corePacks.nixpkgs; [
    #nix
    git
    git-annex
    htop
    iotop
    python3Packages.datalad
  ];

  # package already present
  static = [
    #{
    #  name = "gpfs";
    #  prefix = "/usr/lpp/mmfs";
    #  projection = "{name}";
    #}
    { name = "modules-traditional";
      projection = "{name}";
      static = ''
        whatis("Switch to the old tcl modules")
        local lm = loaded_modules()
        for i = 1, #lm do
          conflict(lm[i].fullName)
        end
        setenv("ENABLE_LMOD", "0")
        unsetenv("MODULESPATH")
        unsetenv("MODULES_NEW")
        if mode() == "load" then
          if myShellType() == "csh" then
            execute {cmd="clearLmod ; source /etc/profile.d/modules.csh ;", modeA={"load"}}
          else
            execute {cmd="clearLmod ; . /etc/profile.d/modules.sh ;", modeA={"load"}}
          end
        end
      '';
    }
    { name = "modules-new";
      projection = "{name}";
      static = ''
        LmodMessage("You are already using the new modules.  You can load 'modules-traditional' to switch to the old ones.")
        os.exit(1)
      '';
    }

    { path = ".modulerc";
      static =
        let alias = {
          #"nvidia/nvhpc" = "nvhpc";
          #"openmpi2" = "openmpi/2";
          #"openmpi4" = "openmpi/4";
          #"python3" = "python/3";
          #"qt5" = "qt/5";
        }; in
        # reloading identical aliases triggers a bug in old lmod
        # wrap in hacky conditional (since old lmod runs modulerc without sandbox, somehow)
        ''
          if _VERSION == nil then
        '' +
        builtins.concatStringsSep "" (builtins.map (n: ''
            module_alias("${n}", "${alias.${n}}")
        '') (builtins.attrNames alias))
        + ''
          end
          hide_version("modules-new")
        '';
    }
  ];

  pkgMod = p: if p ? pkg then p else { pkg = p; };

  modPkgs = with pkgStruct;
    pkgs
    ++
    builtins.concatMap (comp: with comp;
      pkgs
      ++
      builtins.concatMap (mpi: with mpi;
        pkgs
        ++
        builtins.concatMap (py: [{
          pkg = py.view;
          default = py.isCore;
          projection = "python-mpi/{^python.version}";
          #autoload = [comp.pythons[py].view]
          postscript = pyExtensions py.view;
        }] ++ py.pkgs) pythons
      ) mpis
      ++
      builtins.concatMap (py: with py; [
        { pkg = view;
          default = isCore;
          postscript = pyExtensions view;
        }
      ]) pythons
    ) compilers
    #++
    #map (pkg: pkgMod pkg // { projection = "{name}/{version}-libcpp"; })
    #  [] #clangcpp.pkgs
    #++
    #map (pkg: pkgMod pkg // { projection = "{name}/{version}-nvhpc"; })
    #  [] #nvhpc.pkgs
    #++
    #[ { pkg = jupyter;
    #    projection = "jupyterhub";
    #  }
    #]
    ++
    map (p: builtins.parseDrvName p.name // {
      prefix = p;
      context = {
        short_description = p.meta.description or null;
        long_description = p.meta.longDescription or null;
      };
      projection = "{name}/{version}-nix";
    })
      nixpkgs
    ++
    static
  ;


  mods = corePacks.modules {
    /* this correspond to module config in spack */
    /* modtype = "lua"; */
    coreCompilers = map (p: p.pkgs.compiler) [
      corePacks
      bootstrapPacks
    ];
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
        "include" = ["C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH"];
        "" = ["{name}_ROOT" "{name}_BASE"];
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
    pkgs = modPkgs;
  };


  modSite = import ./lmod corePacks mods;

in

corePacks // {
  inherit
    mods
    modSite
    intelPacks
    intelOneApiPacks
    /*jupyter*/
    ;

  traceModSpecs = lib.traceSpecTree (builtins.concatMap (p:
    let q = p.pkg or p; in
    q.pkgs or (if q ? spec then [q] else [])) mods.pkgs);
}

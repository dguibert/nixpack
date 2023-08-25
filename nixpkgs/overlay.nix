self: pkgs:
with pkgs;

{
  gnutls = gnutls.overrideAttrs (old: {
    doCheck = false; # failure test-getaddrinfo
  });
  libgpg-error = libgpg-error.overrideAttrs (old: {
    doCheck = false; # failure FAIL: t-argparse 1.42
  });
  p11-kit = p11-kit.overrideAttrs (old: {
    doCheck = false; # failure ERROR: test-path - missing test plan
  });

  nss_sss = callPackage sssd/nss-client.nix { };

  patchelf = patchelf.overrideAttrs (old: {
    postPatch = ''
      sed -i 's/static bool forceRPath = false;/static bool forceRPath = true;/' src/patchelf.cc
    '';
    doCheck = false;
  });

  makeShellWrapper = makeShellWrapper.overrideAttrs (old: {
    # avoid infinite recursion by escaping to system (hopefully it's good enough)
    shell = "/bin/sh";
  });

  libffi = libffi.overrideAttrs (old: {
    doCheck = false; # failure
  });

  coreutils = (coreutils.override {
    autoreconfHook = null; # workaround nixpkgs #144747
    texinfo = null;
  }).overrideAttrs (old: {
    preBuild = "touch Makefile.in"; # avoid automake
    doCheck = false; # df/total-verify broken on ceph
                     # failure test-getaddrinfo
  });
  perl = perl.override {
    zlib = buildPackages.zlib.override { fetchurl = stdenv.fetchurlBoot; };
  };

  nix = (nix.override {
    withAWS = false;
  }).overrideAttrs (old: {
    doInstallCheck = false;
  });

  git = git.overrideAttrs (old: {
    doInstallCheck = false; # failure
  });

  ell = ell.overrideAttrs (old: {
    doCheck = false; # test-dbus-properties failure: /tmp/ell-test-bus: EADDRINUSE
  });

  gtk3 = gtk3.override {
    trackerSupport = false;
  };

  autogen = autogen.overrideAttrs (old: {
    postInstall = old.postInstall + ''
      # remove $TMPDIR/** from RPATHs
      for f in "$bin"/bin/*; do
        local nrp="$(patchelf --print-rpath "$f" | sed -E 's@(:|^)'$TMPDIR'[^:]*:@\1@g')"
        patchelf --set-rpath "$nrp" "$f"
      done
    '';
  });

  openssl_1_0_2 = openssl_1_0_2.overrideAttrs (old: {
    postPatch = old.postPatch + ''
      sed -i 's:define\s\+X509_CERT_FILE\s\+.*$:define X509_CERT_FILE "/etc/pki/tls/certs/ca-bundle.crt":' crypto/cryptlib.h
    '';
  });

  openssl_1_1 = openssl_1_1.overrideAttrs (old: {
    postPatch = old.postPatch + ''
      sed -i 's:define\s\+X509_CERT_FILE\s\+.*$:define X509_CERT_FILE "/etc/pki/tls/certs/ca-bundle.crt":' include/internal/cryptlib.h
    '';
  });

  # we don't need libredirect for anything (just openssh tests), and it's broken
  libredirect = "/var/empty";

  openssh = openssh.overrideAttrs (old: {
    doCheck = false; # strange environment mismatch
  });

  libuv = libuv.overrideAttrs (old: {
    doCheck = false; # failure
  });

  openimageio = openimageio.overrideAttrs (old: {
    # avoid finding system libjpeg.so
    cmakeFlags = old.cmakeFlags ++ ["-DJPEGTURBO_PATH=${libjpeg.out}"];
  });

  openimagedenoise = openimagedenoise.override {
    tbb = tbb_2021_8;
  };

  openvdb = openvdb.override {
    tbb = tbb_2021_8;
  };

  embree = (embree.override {
    tbb = tbb_2021_8;
  }).overrideAttrs (old: {
    # based on spack flags
    cmakeFlags =
      let
        onoff = b: if b then "ON" else "OFF";
        isa = n: f: "-DEMBREE_ISA_${n}=${onoff (!f)}";
      in old.cmakeFlags ++ [
        (isa "SSE2" stdenv.hostPlatform.sse4_2Support)
        (isa "SSE42" stdenv.hostPlatform.avxSupport)
        (isa "AVX" stdenv.hostPlatform.avx2Support)
        (isa "AVX2" stdenv.hostPlatform.avx512Support)
        (isa "AVX512SKX" false)
      ];
  });

  libical = libical.overrideAttrs (old: {
    cmakeFlags = old.cmakeFlags ++ ["-DBerkeleyDB_ROOT_DIR=${db}"];
  });

  llvmPackages_14 = llvmPackages_14 // (let
    tools = llvmPackages_14.tools.extend (self: super: {
      # broken glob test?
      libllvm = super.libllvm.overrideAttrs (old: {
        postPatch = old.postPatch + ''
          rm test/Other/ChangePrinters/DotCfg/print-changed-dot-cfg.ll
        '';
      });
    });
    in { inherit tools; } // tools);

  llvmPackages_15 = llvmPackages_15 // (let
    tools = llvmPackages_15.tools.extend (self: super: {
      # broken glob test?
      libllvm = super.libllvm.overrideAttrs (old: {
        postPatch = old.postPatch + ''
          rm test/Other/ChangePrinters/DotCfg/print-changed-dot-cfg.ll
        '';
      });
    });
    in { inherit tools; } // tools);

  libxcrypt = libxcrypt.overrideAttrs (old: {
    /* sign-conversion warnings: */
    configureFlags = old.configureFlags ++ [ "--disable-werror" ];
  });

  opencolorio = opencolorio.overrideAttrs (old: {
    # various minor numeric failures
    doCheck = false;
  });

  openexr_3 = openexr_3.overrideAttrs (old: {
    # -nan != -nan
    doCheck = false;
  });

  python310 = python310.override {
    packageOverrides = self: super: {
      pycryptodome = super.pycryptodome.overridePythonAttrs (old: {
        # FAIL: test_negate (Cryptodome.SelfTest.PublicKey.test_ECC_25519.TestEccPoint_Ed25519)
        doCheck = false;
      });
      eventlet = super.eventlet.overridePythonAttrs (old: {
        # needs libredirect
        doCheck = false;
      });
    };
  };

  pipewire = (pipewire.override {
    bluezSupport = false;
    rocSupport = false; # temporarily workaround sox broken download (though probably don't need it anyway)
  }).overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [libopus];
  });

  pulseaudio = pulseaudio.override {
    bluetoothSupport = false;
  };

  blender = (blender.override {
    tbb = tbb_2021_8;
  }).overrideAttrs (old: {
    cmakeFlags = old.cmakeFlags ++ ["-DWITH_OPENAL=OFF"];
  });

  SDL = SDL.overrideAttrs (old: {
    # this is already patched into configure.in, but not configure
    postConfigure = ''
      sed -i '/SDL_VIDEO_DRIVER_X11_CONST_PARAM_XDATA32/s/.*/#define SDL_VIDEO_DRIVER_X11_CONST_PARAM_XDATA32 1/' include/SDL_config.h
    '';
  });
}

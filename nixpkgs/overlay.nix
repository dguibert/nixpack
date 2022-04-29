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

  libuv = libuv.overrideAttrs (old: {
    doCheck = false; # failure
  });

  coreutils = (coreutils.override {
    autoreconfHook = null; # workaround nixpkgs #144747
  }).overrideAttrs (old: {
    preBuild = "touch Makefile.in"; # avoid automake
    doCheck = false; # df/total-verify broken on ceph
                     # failure test-getaddrinfo
  });

  nix = (nix.override {
    withAWS = false;
  }).overrideAttrs (old: {
    patches = [../patch/nix-ignore-fsea.patch];
    doInstallCheck = false;
  });

  git = git.overrideAttrs (old: {
    doCheck = false; # failure
    doInstallCheck = false; # failure
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

  openssl = self.openssl_1_1;

  openssh = openssh.overrideAttrs (old: {
    doCheck = false; # strange environment mismatch
  });

  openimageio = openimageio.overrideAttrs (old: {
    # avoid finding system libjpeg.so
    cmakeFlags = old.cmakeFlags ++ ["-DJPEGTURBO_PATH=${libjpeg.out}"];
  });

  embree = embree.overrideAttrs (old: {
    # fix build (should be dynamic based on arch? see spack)
    cmakeFlags = old.cmakeFlags ++ [
      "-DEMBREE_ISA_AVX=OFF"
      "-DEMBREE_ISA_SSE2=OFF"
      "-DEMBREE_ISA_SSE42=OFF"];
  });
}

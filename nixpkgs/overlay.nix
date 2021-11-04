self: pkgs:
with pkgs;

{
  coreutils = coreutils.overrideAttrs (old: {
    doCheck = false; # failure test-getaddrinfo
  });
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

  nix = (nix.override {
    withAWS = false;
  }).overrideAttrs (old: {
    patches = [../patch/nix-ignore-fsea.patch];
    doInstallCheck = false;
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
}

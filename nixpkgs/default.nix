{ system ? builtins.currentSystem
, target ? builtins.head (builtins.split "-" system)
, src ? {}
}:

let
  target_ = builtins.replaceStrings ["_"] ["-"] target;

nixpkgs = fetchGit ({
  url = "git://github.com/NixOS/nixpkgs";
  ref = "master";
} // src);

args = {
  localSystem = {
    inherit system;
    gcc = { arch = target_; };
  };
  config = {
    replaceStdenv = import ./stdenv.nix;
    nix = {
      storeDir = builtins.getEnv "NIX_STORE_DIR";
      stateDir = builtins.getEnv "NIX_STATE_DIR";
    };
    allowUnfree = true;
    cudaSupport = true;
  };
  overlays = [(import ./overlay.nix)];
};

in

import nixpkgs args

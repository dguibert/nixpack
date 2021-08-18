# nixpack = [nix](https://nixos.org/nix)+[spack](https://spack.io/)

A hybrid of the [nix package manager](https://github.com/NixOS/nix) and [spack](https://github.com/spack/spack) where nix (without nixpkgs) is used to solve and manage packages, using the package repository and builds from spack.

If you love nix's expressiveness and efficiency, but don't need the purity of nixpkgs (in the sense of independence from the host system)... if you like the spack packages but are tired of managing roots and concretizations, this may be for you.
Nix on the outside, spack on the inside.

This is a terrible, horrible work in progress, and you probably shouldn't touch it yet unless you understand both systems well.

## Usage

- install and configure nix sufficient to build derivations
- edit `prefs.nix` (`sets.bootstrap.package.compiler` is critical)
- run `nix-build -A pkgs.foo` to build the spack package `foo`
- see `fi.nix` for a complete working example with view and modules: `nix-build -A mods fi.nix`

## Compatibility

nixpack uses an unmodified checkout of spack (as specified in `spackSrc`), and should work with other forks as well.
However, it makes many assumptions about the internals of spack builds, so may not work on different versions.

## Implementation and terminology

In nixpkgs, there's mainly the concept of package, and arguments that can be overridden.
In spack, there are packages and specs, and "spec" is used in many different ways.

### package descriptor

The metadata for a spack package.
These are generated by spack/generate.py from the spack repo `package.py`s and loaded into `packs.repo`.
They look like this:

```nix
example = {
  namespace = "builtin";
  version = ["2.0" "1.2" "1.0"]; # in decreasing order of preference
  variants = {
    flag = true;
    option = ["a" "b" "c"]; # first is default
    multi = {
      a = true;
      b = false;
    };
  };
  depends = {
    /* package preferences for dependencies (see below) */
    compiler = {}; # usually implicit
    deppackage = {
      version = "1.5:2.1";
    };
    notused = null;
  };
  provides = {
    virtual = "2:"
  };
  paths = {}; # paths to tools provided by this package (like cc)
  patches = []; # patchs to extra patches to apply
  conflicts = []; # any conflicts (non-empty means invalid)
};
```

Most things default to empty.
In practice, these are constructed as functions that take a resolved package spec as an argument.
This lets dependencies and such be conditional on a specific version and variants.

### package preferences

Constraints for a package that come from a dependency specifier or the user.
These are used in package descriptor depends and in user global or package preferences.
They look similar to package descriptors and can be used to override or constrain some of their values.

```
example = {
  version = "1.3:1.5";
  variants = {
    flag = true;
    option = "b";
    multi = ["a" "b"];
    multi = {
      a = true;
      b = false;
    };
  };
  depends = {
    compiler = {
      name = "clang";
    };
    deppackage = {
      version = ...
    };
    virtualdep = {
      name = "provider";
      version = ...;
      ...
    };
  };
  patches = []; # patchs to extra patches to apply
  extern = "/opt/local/mypackage"; # a prefix string or derivation (e.g., nixpkgs package) for an external installation (overrides depends)
  fixedDeps = false; # only use user preferences to resolve dependencies (see prefs.nix)
  resolver = "set"; # name of set to use to resolve dependencies
  buildResolver = "set"; # name of set to use to resolve build/test-only dependencies
};
```

### package spec

A resolved (concrete) package specifier created by applying (optional) package preferences to a package descriptor.

### package

An actual derivation.
These contain a `spec` metadata attribute.

### preferences

Global user preferences.
See [`prefs.nix`](prefs.nix).

### compiler

Rather than spack's dedicated `%compiler` concept, we introduce a new virtual "compiler" that all packages depend on and is provided by gcc and llvm (by default).
By setting the package preference for compiler, you determine which compiler to use.

### `packs`

The world, like `nixpkgs`.
It contains `repo` with package descriptor generators and `pkgs`.

### sets

In `prefs.nix` is `sets`, which is set of additional named preferences, each of which is used to create another package set under `packs.sets`.
These preferences override the defaults specified at the top level.
These can be used to have package sets with different providers or package settings (like a different compiler, mpi version, blas provider, etc.).

When nesting sets, sets inherit all from their parent, along with the implicit sets `self`, `parent`, and `root`.
You can also dynamically create new sets using `packs.withPrefs { .. }`.

### Bootstrapping

The default compiler specifies `resolver = "bootstrap"` which means that all dependencies for the compiler package will be resolved using `sets.bootstrap` preferences.
These preferences in turn specify a compiler with `extern` set, i.e., one from the base system.
This compiler is used to build any other bootstrap packages, which are then used to build the main compiler.
You could specify more extern packages in bootstrap to speed up bootstrapping.

You could also add additional bootstrap layers by setting the bootstrap compiler `resolver` to a different set.
It's also possible to specify `resolver` for other packages, or `buildResolver` to resolve only build-time dependencies.
Each of these can be set to the same of a set, or an already-constructed `packs`.

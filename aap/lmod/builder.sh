#!/bin/sh -eu
/bin/mkdir -p $out
#for f in setup.sh setup.csh lmodrc.lua site/SitePackage.lua site_msg.lua ; do
for f in setup.sh lmodrc.lua site_msg.lua modules.lua; do
	/bin/mkdir -p $out/`/bin/dirname $f`
	/bin/sed "s:@LMOD@:$lmod:g;s:@MODS@:$mods:g;s:@CACHE@:$cache:g;s:@SITE@:$out:g;s!@DATE@!`/bin/date`!g" $src/`/bin/basename $f` > $out/$f
done
# just for convenience:
/bin/ln -s $mods $out
/bin/ln -s $lmod/lmod $out

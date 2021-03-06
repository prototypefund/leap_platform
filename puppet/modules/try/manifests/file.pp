#
# Works like the built-in type "file", but gets gracefully ignored if the target/source does not exist or is undefined.
#
# Also, if the source or target doesn't exist, and the destination is a git repo, then the file is restored from git.
#
# All executable paths are hardcoded to their paths in debian.
#
# known limitations:
# * this is far too noisy
# * $restore does not work for directories
# * only file:// $source is supported
# * $content is not supported, only $target or $source.
# * does not auto-require all the parent directories like 'file' does
#
define try::file (
  $ensure = undef,
  $target = undef,
  $source = undef,
  $owner = undef,
  $group = undef,
  $recurse = undef,
  $purge = undef,
  $force = undef,
  $mode = undef,
  $restore = true) {

  # dummy exec to propagate requires:
  # metaparameter 'require' will get triggered by this dummy exec
  # so then we just need to depend on this to capture all requires.
  # exec { $name: command => "/bin/true" }

  exec {
    "chmod_${name}":
      command => "/bin/chmod -R ${mode} '${name}'",
      onlyif => "/usr/bin/test ${mode}",
      refreshonly => true,
      loglevel => debug;
    "chown_${name}":
      command => "/bin/chown -R ${owner} '${name}'",
      onlyif => "/usr/bin/test ${owner}",
      refreshonly => true,
      loglevel => debug;
    "chgrp_${name}":
      command => "/bin/chgrp -R ${group} '${name}'",
      onlyif => "/usr/bin/test ${group}",
      refreshonly => true,
      loglevel => debug;
  }

  if $target {
    exec { "symlink_${name}":
      command => "/bin/ln -s ${target} ${name}",
      onlyif  => "/usr/bin/test -d '${target}'",
    }
  } elsif $source {
    if $ensure == 'directory' {
      if $purge {
        exec { "rsync_${name}":
          command => "/usr/bin/rsync -r --delete '${source}/' '${name}'",
          onlyif  => "/usr/bin/test -d '${source}'",
          unless  => "/usr/bin/diff -rq '${source}' '${name}'",
          notify  => [Exec["chmod_${name}"], Exec["chown_${name}"], Exec["chgrp_${name}"]]
        }
      } else {
        exec { "cp_r_${name}":
          command => "/bin/cp -r '${source}' '${name}'",
          onlyif  => "/usr/bin/test -d '${source}'",
          unless  => "/usr/bin/diff -rq '${source}' '${name}'",
          notify  => [Exec["chmod_${name}"], Exec["chown_${name}"], Exec["chgrp_${name}"]]
        }
      }
    } else {
      exec { "cp_${name}":
        command => "/bin/cp --remove-destination '${source}' '${name}'",
        onlyif  => "/usr/bin/test -e '${source}'",
        unless  => "/usr/bin/test ! -h '${name}' && /usr/bin/diff -q '${source}' '${name}'",
        notify  => [Exec["chmod_${name}"], Exec["chown_${name}"], Exec["chgrp_${name}"]]
      }
    }
  }

  #
  # if the target/source does not exist (or is undef), and the file happens to be in a git repo,
  # then restore the file to its original state.
  #

  if $target {
    $target_or_source = $target
  } else {
    $target_or_source = $source
  }

  if ($target_or_source == undef) or $restore {
    $file_basename = basename($name)
    $file_dirname  = dirname($name)
    $command = "git rev-parse && unlink '${name}'; git checkout -- '${file_basename}' && chown --reference='${file_dirname}' '${name}'; true"
    debug($command)

    if $target_or_source == undef {
      exec { "restore_${name}":
        command => $command,
        cwd => $file_dirname,
        loglevel => info;
      }
    } else {
      exec { "restore_${name}":
        unless => "/usr/bin/test -e '${target_or_source}'",
        command => $command,
        cwd => $file_dirname,
        loglevel => info;
      }
    }
  }
}

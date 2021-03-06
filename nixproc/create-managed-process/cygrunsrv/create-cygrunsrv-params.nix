{ stdenv
, writeTextFile

# Prefix that is in front of all Windows services generated by this function
, prefix ? "nix-process-"
}:

{
# A name that identifies the process instance
name
# A more human readable name that identifies the process
, displayName ? "${prefix}${name}"
# Path to the executable to run
, path
# Command-line arguments propagated to the executable
, args ? []
# An attribute set specifying arbitrary environment variables
, environment ? {}
# Specifies whether this service needs to be automatically started or not.
# 'manual' indicates manual start, 'auto' indicates automatic start
, type ? "auto"
# Specifies as which user the process should run. If null, the user privileges will not be changed.
, user ? null
# The password of the user so that the user privileges can be changed
, password ? null
# File where the stdin should read from. null indicates that no file should be read
, stdin ? null
# File where the stdout should write to. null discards output
, stdout ? null
# File where the stderr should write to. null discards output
, stderr ? null
# The signal that needs to be sent to the process to terminate it
, terminateSignal ? "TERM"
# Indicates whether the process should be terminated on shutdown
, terminateOnShutdown ? false
# Dependencies on other Windows services. The service manager makes sure that dependencies are activated first.
, dependencies ? []
# Specifies which packages need to be in the PATH
, environmentPath ? []
# Arbitrary commands executed after generating the configuration files
, postInstall ? ""
}:

let
  _environment = stdenv.lib.optionalAttrs (environmentPath != []) {
    PATH = builtins.concatStringsSep ":" (map (package: "${package}/bin") environmentPath); # Augment path environment variable, if applicable
  } // environment;

  cygrunsrvConfig = writeTextFile {
    name = "${prefix}${name}-cygrunsrv-params";
    text = ''
      --path
      ${path}
      --disp
      ${displayName}
    ''
    + stdenv.lib.optionalString (type != "auto") ''
      --type
      ${type}
    ''
    + stdenv.lib.optionalString (args != []) ''
      --args
      ${builtins.concatStringsSep " " (map (arg: stdenv.lib.escapeShellArg arg) args)}
    ''
    +
    stdenv.lib.concatMapStrings (variableName:
      let
        value = builtins.getAttr variableName _environment;
      in
      ''
        --env
        '${variableName}=${stdenv.lib.escape [ "'" ] (toString value)}'
      '') (builtins.attrNames _environment)
    + stdenv.lib.optionalString (user != null) ''
      --user
      ${user}
    ''
    + stdenv.lib.optionalString (password != null) ''
      --passwd
      ${password}
    ''
    + stdenv.lib.optionalString (stdin != null) ''
      --stdin
      ${stdin}
    ''
    + stdenv.lib.optionalString (stdout != null) ''
      --stdout
      ${stdout}
    ''
    + stdenv.lib.optionalString (stderr != null) ''
      --stderr
      ${stderr}
    ''
    + stdenv.lib.optionalString (terminateSignal != "TERM") ''
      --termsig
      ${terminateSignal}
    ''
    + stdenv.lib.optionalString terminateOnShutdown ''
      --shutdown
    ''
    + stdenv.lib.concatMapStrings (dependency: ''
      --dep
      ${dependency.name}
    '') dependencies;
  };
in
stdenv.mkDerivation {
  name = "${prefix}${name}";

  buildCommand = ''
    mkdir -p $out
    ln -s ${cygrunsrvConfig} $out/${prefix}${name}-cygrunsrvparams
    ${postInstall}
  '';
}

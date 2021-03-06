{ writeTextFile
, stdenv
, createCredentials

# Path to the rc.subr script
, rcSubr ? "/etc/rc.subr"
# Specifies which command are builtin. This is to determine which extra commands may have been provided.
, builtinCommands ? [ "start" "stop" "reload" "restart" "status" "poll" "rcvar" ]
# Specifies the default signal used for reloading a process
, defaultReloadSignal ? "HUP"
# Specifies the default signal used for stopping a process
, defaultStopSignal ? "TERM"
# Default run time directory where PID files are stored
, runtimeDir ? "/var/run"
# Specifies whether user changing functionality should be disabled or not
, forceDisableUserChange ? false
}:

{
# A name that identifies the process instance
name
# The variable suffix that indicates whether a service has been enabled or not.
, rcvar ? "enabled"
# An attribute set defining default values for configuration environment variables
, rcvarsDefaults ? {}
# The command that executes a daemon
, command ? null
# The command-line parameters passed to the command
, commandArgs ? []
# Specifies whether the command daemonizes or not. If the command is not a daemon, it gets daemonized by the generator
, commandIsDaemon ? true
# Specifies the signal that needs to be sent to reload a process
, reloadSignal ? "HUP"
# Specifies the signal that needs to be sent to stop a process
, stopSignal ? "TERM"
# Specifies which packages need to be in the PATH
, environment ? {}
# An attribute set specifying arbitrary environment variables
, path ? []
# A name that uniquely identifies each process instance. It is used to generate a unique PID file.
, instanceName ? null
# Path to a PID file that the system should use to manage the process. If null, it will use a default path.
, pidFile ? (if instanceName == null then null else "${runtimeDir}/${instanceName}.pid")
# If not null, the nice level be changed before executing any activities
, nice ? null
# If not null, the current working directory will be changed before executing any activities
, directory ? null
# Specifies as which user the process should run. If null, the user privileges will not be changed.
, user ? null
# Defines files that must be readable before running the start method
, requiredFiles ? []
# Defines directories that must exist before running the start method
, requiredDirs ? []
# Defines external environment variables this script depends on
, requiredVars ? []
# Perform checkyesno on each of the list variables before running the start method.
, requiredModules ? []
# Specifies the implementation of arbitrary commands
, commands ? {}
# If set to true the rc script accepts an arbitrary number of parameters. If set to false, it only accepts one.
, flexibleParameters ? false
# Specifies which feature the script requires. This is used by the rc init system to determine the proper activation order
, requires ? []
# Specifies which features the script provides. By default, it simply considers it name a feature.
, provides ? [ "${name}" ]
# Keywords to be display in the comments section
, keywords ? []
# A list of bsd rc scripts that this script depends on
, dependencies ? []
# Specifies which groups and users that need to be created.
, credentials ? {}
# Arbitrary commands executed after generating the configuration files
, postInstall ? ""
}:

# TODO:
# umask
# other properties. see rc.subr manpage

assert command == null -> commands ? start && commands ? stop;

let
  extraCommands = builtins.attrNames (removeAttrs commands builtinCommands);

  _user = if forceDisableUserChange then null else user;

  _command = if commandIsDaemon then command else "daemon";
  _commandArgs = if commandIsDaemon then commandArgs else
   stdenv.lib.optionals (pidFile != null) [ "-p" pidFile ]
   ++ [ command ]
   ++ commandArgs;

  _requires = map (dependency: dependency.name) dependencies ++ requires;

  envFile = if environment == {} then null else writeTextFile {
    name = "${name}-envfile";
    text = stdenv.lib.concatMapStrings (name:
      let
        value = builtins.getAttr name environment;
      in
      ''${name}=${stdenv.lib.escapeShellArg value}
      ''
    ) (builtins.attrNames environment);
  };

  rcScript = writeTextFile {
    inherit name;
    executable = true;
    text = ''
      #!/bin/sh
    ''
    + stdenv.lib.optionalString (provides != []) ''
      # PROVIDE: ${toString provides}
    ''
    + stdenv.lib.optionalString (_requires != []) ''
      # REQUIRE: ${toString _requires}
    ''
    + stdenv.lib.optionalString (keywords != []) ''
      # KEYWORD: ${toString keywords}
    '' +
    ''
      . ${rcSubr}

      name="${name}"
    '' + stdenv.lib.optionalString (rcvar != null) ''
      rcvar=''${name}_${rcvar}
    ''
    + ''

      load_rc_config $name
      ${stdenv.lib.concatMapStrings (rcvarName: ''
        : ''${name}_${rcvarName}:=${toString builtins.getAttr rcvarName rcvarsDefaults}
      '') (builtins.attrNames rcvarsDefaults)}

    ''
    + stdenv.lib.optionalString (_command != null) ''
      command=${_command}
    ''
    + stdenv.lib.optionalString (_commandArgs != []) ''
      command_args="${stdenv.lib.escapeShellArgs _commandArgs}"
    ''
    + stdenv.lib.optionalString (requiredDirs != []) ''
      required_dirs="${toString requiredDirs}"
    ''
    + stdenv.lib.optionalString (requiredFiles != []) ''
      required_files="${toString requiredFiles}"
    ''
    + stdenv.lib.optionalString (requiredVars != []) ''
      required_vars="${toString requiredVars}"
    ''
    + stdenv.lib.optionalString (requiredModules != []) ''
      required_modules="${toString requiredModules}"
    ''
    + stdenv.lib.optionalString (pidFile != null) ''
      pidfile="${pidFile}"
    ''
    + stdenv.lib.optionalString (reloadSignal != defaultReloadSignal) ''
      sig_reload="${reloadSignal}"
    ''
    + stdenv.lib.optionalString (stopSignal != defaultStopSignal) ''
      sig_stop="${stopSignal}"
    ''
    + stdenv.lib.optionalString (nice != null) ''
      ${name}_nice=${toString nice}
    ''
    + stdenv.lib.optionalString (directory != null) ''
      ${name}_chdir=${directory}
    ''
    + stdenv.lib.optionalString (_user != null) ''
      ${name}_user=${_user}
    ''
    + stdenv.lib.optionalString (envFile != null) ''
      ${name}_env_file=${envFile}
    ''
    + stdenv.lib.optionalString (extraCommands != []) ''
      extra_commands="${toString extraCommands}"
    ''
    + stdenv.lib.concatMapStrings (commandName:
      let
        command = builtins.getAttr commandName commands;
      in
      stdenv.lib.optionalString (command ? pre) ''${commandName}_precmd=''${name}_pre${commandName}
      ''
      + stdenv.lib.optionalString (command ? implementation) ''${commandName}_cmd=''${name}_${commandName}
      ''
      + stdenv.lib.optionalString (command ? post) ''${commandName}_postcmd=''${name}_post${commandName}
      ''
    ) (builtins.attrNames commands)
    + stdenv.lib.optionalString (path != []) ''

      PATH="${builtins.concatStringsSep ":" (map(package: "${package}/bin") path)}:$PATH"
      export PATH
    ''
    + "\n"
    + stdenv.lib.concatMapStrings (commandName:
      let
        command = builtins.getAttr commandName commands;
      in
      ''
        ${stdenv.lib.optionalString (command ? pre) ''
          ${name}_pre${commandName}()
          {
              ${command.pre}
          }
        ''}
        ${stdenv.lib.optionalString (command ? implementation) ''
          ${name}_${commandName}()
          {
              ${command.implementation}
          }
        ''}
        ${stdenv.lib.optionalString (command ? post) ''
          ${name}_post${commandName}()
          {
              ${command.post}
            }
        ''}
      ''
    ) (builtins.attrNames commands)
    + ''
      run_rc_command "${if flexibleParameters then "$@" else "$1"}"
    '';
  };

  credentialsSpec = if credentials == {} || forceDisableUserChange then null else createCredentials credentials;
in
stdenv.mkDerivation {
  inherit name;

  buildCommand = ''
    mkdir -p $out/etc/rc.d
    cd $out/etc/rc.d
    ln -s ${rcScript} ${name}

    ${stdenv.lib.optionalString (credentialsSpec != null) ''
      ln -s ${credentialsSpec}/dysnomia-support $out/dysnomia-support
    ''}

    cd $TMPDIR
    ${postInstall}
  '';
}

{createManagedProcess, runtimeDir}:
{port, instanceSuffix ? ""}:

let
  webapp = import ../../webapp;
  instanceName = "webapp${instanceSuffix}";
in
createManagedProcess {
  name = instanceName;
  description = "Simple web application";
  inherit instanceName;

  # This expression can both run in foreground or daemon mode.
  # The process manager can pick which mode it prefers.
  process = "${webapp}/bin/webapp";
  daemonArgs = [ "-D" ];

  environment = {
    PORT = port;
    PID_FILE = "${runtimeDir}/${instanceName}.pid";
  };
  user = instanceName;
  credentials = {
    groups = {
      "${instanceName}" = {};
    };
    users = {
      "${instanceName}" = {
        group = instanceName;
        description = "Webapp";
      };
    };
  };

  overrides = {
    sysvinit = {
      runlevels = [ 3 4 5 ];
    };
  };
}

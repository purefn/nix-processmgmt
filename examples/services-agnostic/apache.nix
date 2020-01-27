{createManagedProcess, apacheHttpd}:
{instanceSuffix ? "", configFile, initialize ? ""}:

let
  instanceName = "httpd${instanceSuffix}";
  user = instanceName;
  group = instanceName;
in
createManagedProcess {
  name = instanceName;
  inherit instanceName initialize;

  process = "${apacheHttpd}/bin/httpd";
  args = [ "-f" configFile ];
  foregroundProcessExtraArgs = [ "-DFOREGROUND" ];

  credentials = {
    groups = {
      "${group}" = {};
    };
    users = {
      "${user}" = {
        inherit group;
        description = "Apache HTTP daemon user";
      };
    };
  };

  overrides = {
    sysvinit = {
      runlevels = [ 3 4 5 ];
    };
  };
}
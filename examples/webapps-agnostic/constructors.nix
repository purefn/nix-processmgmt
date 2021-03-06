{ pkgs
, stateDir
, logDir
, runtimeDir
, tmpDir
, forceDisableUserChange
, processManager
, webappMode # set to 'foreground' to make them all foreground process, 'daemon' to make them all daemons. null is to pick best option for the selected processManager
}:

let
  createManagedProcess = import ../../nixproc/create-managed-process/agnostic/create-managed-process-universal.nix {
    inherit pkgs runtimeDir tmpDir forceDisableUserChange processManager;
  };

  webappExpr = if webappMode == "foreground" then ./webapp-fg.nix
    else if webappMode == "daemon" then ./webapp-daemon.nix
    else ./webapp.nix;
in
{
  webapp = import webappExpr {
    inherit createManagedProcess runtimeDir;
  };
}

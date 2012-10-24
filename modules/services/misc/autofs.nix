{ config, pkgs, ... }:

with pkgs.lib;
with pkgs;

let

  cfg = config.services.autofs;

  pidFile = "/run/automount.pid";

  autoMaster = writeText "auto.master" cfg.autoMaster;

in

{

  ###### interface

  options = {

    services.autofs = {

      enable = mkOption {
        default = false;
        description = "
          Mount filesystems on demand. Unmount them automatically.
          You may also be interested in afuese.
        ";
      };

      autoMaster = mkOption {
        example = literalExample ''
          autoMaster = let
            mapConf = writeText "auto" '''
             kernel    -ro,soft,intr       ftp.kernel.org:/pub/linux
             boot      -fstype=ext2        :/dev/hda1
             windoze   -fstype=smbfs       ://windoze/c
             removable -fstype=ext2        :/dev/hdd
             cd        -fstype=iso9660,ro  :/dev/hdc
             floppy    -fstype=auto        :/dev/fd0
             server    -rw,hard,intr       / -ro myserver.me.org:/ \
                                           /usr myserver.me.org:/usr \
                                           /home myserver.me.org:/home
            ''';
          in '''
            /auto file:''${mapConf}
          '''
        '';
        description = "
          file contents of /etc/auto.master. See man auto.master
          See man 5 auto.master and man 5 autofs.
        ";
      };

      timeout = mkOption {
        default = 600;
        description = "Set the global minimum timeout, in seconds, until directories are unmounted";
      };

      debug = mkOption {
        default = false;
        description = ''
          Pass -d, -l7 and -v to automount daemon. Debug logs will be written
          to /var/log/upstart/autofs.
        '';
      };

      packages = mkOption {
        default = [];
        example = [ nfsUtils cifs_utils sshfsFuse ];
        description = ''
          A list of packages needed to support the filesystems you want to
          automount. Note that you also might need to load kernel modules for
          some filesystems (in some cases autofs does it automatically, though).
        '';
      };

    };

  };


  ###### implementation

  config = mkIf cfg.enable {

    boot.kernelModules = [ "autofs4" ];

    jobs.autofs = {
      description = "Filesystem automounter";

      startOn = "started network-interfaces";
      stopOn = "stopping network-interfaces";

      path = [ autofs5 coreutils ] ++ cfg.packages;

      # Trigger a clean unmount before killing automount
      preStop = ''
        PID=""
        test -f ${pidFile} && PID=$(cat ${pidFile})
        test -z $PID || kill -USR1 $PID || true
      '';

      # For some reason, "-l7" must be placed at the end, else startup fails
      exec = ''
        automount ${optionalString cfg.debug "-v -d"} -f \
          -t ${builtins.toString cfg.timeout} -p ${pidFile} \
          ${autoMaster} ${optionalString cfg.debug "-l7"}
      '';
    };

  };

}

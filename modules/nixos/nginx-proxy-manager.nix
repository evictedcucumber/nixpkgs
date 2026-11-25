{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nginx-proxy-manager;
  inherit (cfg) package;
  defaultUser = "nginx-proxy-manager";
  runDir = "/run/nginx-proxy-manager";

  prepareScript = pkgs.writeShellScript "nginx-proxy-manager-prepare" ''
    set -euo pipefail

    mkdir -p /data/{nginx,custom_ssl,logs,access,letsencrypt-acme-challenge}
    mkdir -p /data/nginx/{default_host,default_www,proxy_host,redirection_host,stream,dead_host,temp}

    cp -rT --no-preserve=mode ${package}/share/nginx-proxy-manager/nginx /etc/nginx

    secret=$(head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n')
    (umask 077; printf '%s' "$secret" > ${runDir}/peer-secret)

    tpl=$(< /etc/nginx/conf.d/production.conf.template)
    tpl=''${tpl//'{{NPM_ADMIN_PORT}}'/${toString cfg.adminPort}}
    tpl=''${tpl//'{{NPM_PEER_SECRET}}'/$secret}
    printf '%s\n' "$tpl" > /etc/nginx/conf.d/production.conf
    rm -f /etc/nginx/conf.d/production.conf.template

    nameservers=()
    if [[ -r /etc/resolv.conf ]]; then
      while read -r key value _; do
        [[ $key == nameserver ]] || continue
        value=''${value%%\%*}
        [[ $value == *:* ]] && value="[$value]"
        nameservers+=("$value")
      done < /etc/resolv.conf
    fi
    if ((''${#nameservers[@]} > 0)); then
      printf 'resolver %s valid=10s;\n' "''${nameservers[*]}" > /etc/nginx/conf.d/include/resolvers.conf
    fi

    rm -f ${runDir}/nginx.pid
  '';

  startScript = pkgs.writeShellScript "nginx-proxy-manager-start" ''
    set -euo pipefail

    IFS= read -r NPM_PEER_SECRET < ${runDir}/peer-secret || true
    export NPM_PEER_SECRET
    ${lib.optionalString (cfg.initialAdmin.passwordFile != null) ''
      IFS= read -r -d "" INITIAL_ADMIN_PASSWORD < "$CREDENTIALS_DIRECTORY/admin-password" || true
      INITIAL_ADMIN_PASSWORD=''${INITIAL_ADMIN_PASSWORD%$'\n'}
      [[ -n $INITIAL_ADMIN_PASSWORD ]] || { echo "initial admin password is empty" >&2; exit 1; }
      export INITIAL_ADMIN_PASSWORD
    ''}
    exec ${package}/bin/nginx-proxy-manager
  '';

  hardening = {
    User = cfg.user;
    Group = cfg.group;
    CacheDirectory = "nginx-proxy-manager";
    CacheDirectoryMode = "0750";
    BindPaths = [
      "${cfg.dataDir}:/data"
      "${cfg.dataDir}/letsencrypt:/etc/letsencrypt"
      "${runDir}/nginx:/etc/nginx"
    ];
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    PrivateDevices = true;
    NoNewPrivileges = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    ProcSubset = "pid";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
      "~@resources"
    ];
    UMask = "0027";
  };
in
{
  options.services.nginx-proxy-manager = {
    enable = lib.mkEnableOption "Nginx Proxy Manager";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../../pkgs/nginx-proxy-manager/package.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/nginx-proxy-manager/package.nix { }";
      description = "The Nginx Proxy Manager package to run.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/nginx-proxy-manager";
      description = "Where to keep the database, keys, and certificates.";
    };

    adminPort = lib.mkOption {
      type = lib.types.port;
      default = 81;
      description = "Port of the admin web interface.";
    };

    initialAdmin = {
      email = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "admin@example.com";
        description = "Email of the admin user created on first start, if no user exists.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.pathWith {
            inStore = false;
            absolute = true;
          }
        );
        default = null;
        example = "/run/secrets/npm-admin-password";
        description = "File holding the initial admin's password.";
      };
    };

    certbotPlugins = lib.mkOption {
      type = lib.types.functionTo (lib.types.listOf lib.types.package);
      default = _: [ ];
      example = lib.literalExpression "ps: [ ps.certbot-dns-cloudflare ]";
      description = "Certbot plugins to install, chosen from the certbot Python packages.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
      description = "User to run the services as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = defaultUser;
      description = "Group to run the services as.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open ports 80, 443, and the admin port.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.user != "root";
        message = "services.nginx-proxy-manager.user must not be root.";
      }
      {
        assertion = (cfg.initialAdmin.email == null) == (cfg.initialAdmin.passwordFile == null);
        message = "services.nginx-proxy-manager.initialAdmin: set both email and passwordFile, or neither.";
      }
    ];

    users.users = lib.mkIf (cfg.user == defaultUser) {
      ${defaultUser} = {
        isSystemUser = true;
        group = cfg.group;
      };
    };
    users.groups = lib.mkIf (cfg.group == defaultUser) {
      ${defaultUser} = { };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [
      80
      443
      cfg.adminPort
    ];

    systemd.tmpfiles.settings."10-nginx-proxy-manager" = {
      ${cfg.dataDir}.d = {
        mode = "0750";
        user = cfg.user;
        group = cfg.group;
      };
      "${cfg.dataDir}/letsencrypt".d = {
        mode = "0750";
        user = cfg.user;
        group = cfg.group;
      };
    };

    systemd.services.nginx-proxy-manager-prepare = {
      description = "Nginx Proxy Manager runtime setup";
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.coreutils ];
      serviceConfig = hardening // {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "nginx-proxy-manager nginx-proxy-manager/nginx";
        RuntimeDirectoryMode = "0700";
        ExecStart = prepareScript;
        CapabilityBoundingSet = "";
      };
    };

    systemd.services.nginx-proxy-manager-nginx = {
      description = "Nginx Proxy Manager web server";
      wantedBy = [ "multi-user.target" ];
      bindsTo = [ "nginx-proxy-manager-prepare.service" ];
      partOf = [ "nginx-proxy-manager-prepare.service" ];
      after = [
        "network.target"
        "nginx-proxy-manager-prepare.service"
      ];
      serviceConfig = hardening // {
        ExecStart = "${package.nginx}/bin/nginx -c /etc/nginx/nginx.conf -e stderr";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        Restart = "on-failure";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      };
    };

    systemd.services.nginx-proxy-manager = {
      description = "Nginx Proxy Manager backend";
      wantedBy = [ "multi-user.target" ];
      bindsTo = [ "nginx-proxy-manager-prepare.service" ];
      partOf = [ "nginx-proxy-manager-prepare.service" ];
      wants = [ "nginx-proxy-manager-nginx.service" ];
      after = [
        "nginx-proxy-manager-prepare.service"
        "nginx-proxy-manager-nginx.service"
      ];
      path = [ (pkgs.certbot.withPlugins cfg.certbotPlugins) ];
      environment = {
        HOME = "/tmp";
      }
      // lib.optionalAttrs (cfg.initialAdmin.email != null) {
        INITIAL_ADMIN_EMAIL = cfg.initialAdmin.email;
      };
      serviceConfig =
        hardening
        // {
          ExecStart = startScript;
          Restart = "on-failure";
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        }
        // lib.optionalAttrs (cfg.initialAdmin.passwordFile != null) {
          LoadCredential = "admin-password:${cfg.initialAdmin.passwordFile}";
        };
    };
  };
}

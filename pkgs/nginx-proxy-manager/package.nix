{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchYarnDeps,
  fixup-yarn-lock,
  yarn,
  nodejs,
  python3,
  makeWrapper,
  coreutils,
  openssl,
  logrotate,
  nginx,
}:

let
  nginxWithoutExtras = nginx.override {
    modules = [ ];
    withPerl = false;
    withKTLS = false;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nginx-proxy-manager";
  version = "2.17.1";

  src = fetchFromGitHub {
    owner = "NginxProxyManager";
    repo = "nginx-proxy-manager";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ci9J0o41hE+eMi4sXCakfB/2DIn9EDmL6Ki0S7Y+W8A=";
  };

  # nix-update looks for exactly these two attribute names
  yarnOfflineCache = fetchYarnDeps {
    name = "${finalAttrs.pname}-frontend-yarn-deps";
    yarnLock = "${finalAttrs.src}/frontend/yarn.lock";
    hash = "sha256-sf/TGn4mmpe17snqGWfYdi4hv7x0sDVVeoWOFdywTh0=";
  };

  offlineCache = fetchYarnDeps {
    name = "${finalAttrs.pname}-backend-yarn-deps";
    yarnLock = "${finalAttrs.src}/backend/yarn.lock";
    hash = "sha256-OZcs/PJNtncRZhNgMigulugflRJm3fh/dqq5QHqNb8A=";
  };

  patches = [ ./certbot-plugins-from-nix.patch ];

  postPatch = ''
    substituteInPlace backend/internal/nginx.js \
      --replace-fail '"/usr/sbin/nginx", ["-t",' '"${nginxWithoutExtras}/bin/nginx", ["-c", "/etc/nginx/nginx.conf", "-e", "stderr", "-t",' \
      --replace-fail '"/usr/sbin/nginx", ["-s",' '"${nginxWithoutExtras}/bin/nginx", ["-c", "/etc/nginx/nginx.conf", "-e", "stderr", "-s",' \
      --replace-fail '"error_log off;"' '"error_log /dev/null;"'

    substituteInPlace backend/index.js \
      --replace-fail 'app.listen(3000,' 'app.listen(3000, "127.0.0.1",'

    substituteInPlace backend/setup.js \
      --replace-fail ' with password: ''${initialAdminPassword}' "" \
      --replace-fail 'process.env.INITIAL_ADMIN_PASSWORD;' 'process.env.INITIAL_ADMIN_PASSWORD; delete process.env.INITIAL_ADMIN_PASSWORD;' \
      --replace-fail '"logrotate /etc/logrotate.d/nginx-proxy-manager"' '"logrotate --state /data/logrotate.status '$out'/share/nginx-proxy-manager/logrotate.conf"'

    substituteInPlace docker/rootfs/etc/logrotate.d/nginx-proxy-manager \
      --replace-fail $'    su npm npm\n' "" \
      --replace-fail /run/nginx/nginx.pid /run/nginx-proxy-manager/nginx.pid

    substituteInPlace backend/internal/certificate.js \
      --replace-fail '"/etc/letsencrypt.ini"' '"'$out'/share/nginx-proxy-manager/letsencrypt.ini"'

    pushd docker/rootfs/etc/nginx
    rm conf.d/dev.conf conf.d/include/.gitignore

    substituteInPlace nginx.conf \
      --replace-fail $'user npm;\n' "" \
      --replace-fail $'# Includes files with directives to load dynamic modules.\ninclude /etc/nginx/modules/*.conf;\n\n' "" \
      --replace-fail /run/nginx/nginx.pid /run/nginx-proxy-manager/nginx.pid \
      --replace-fail /tmp/nginx/body /var/cache/nginx-proxy-manager/body \
      --replace-fail /var/lib/nginx/cache/public /var/cache/nginx-proxy-manager/public \
      --replace-fail /var/lib/nginx/cache/private /var/cache/nginx-proxy-manager/private

    substituteInPlace conf.d/production.conf.template \
      --replace-fail "root /app/frontend;" "root $out/share/nginx-proxy-manager/frontend;"

    substituteInPlace conf.d/default.conf \
      --replace-fail "root /var/www/html;" "root $out/share/nginx-proxy-manager/www;"
    popd
  '';

  nativeBuildInputs = [
    nodejs
    yarn
    fixup-yarn-lock
    python3
    makeWrapper
  ];

  env.npm_config_nodedir = nodejs;

  configurePhase = ''
    runHook preConfigure

    export HOME=$(mktemp -d)

    installDeps() {
      local dir=$1 cache=$2
      shift 2
      pushd "$dir"
      yarn config --offline set yarn-offline-mirror "$cache"
      fixup-yarn-lock yarn.lock
      yarn install --offline --frozen-lockfile --ignore-engines --ignore-scripts \
        --no-progress --non-interactive "$@"
      patchShebangs node_modules
      popd
    }

    installDeps backend ${finalAttrs.offlineCache} --production
    installDeps frontend ${finalAttrs.yarnOfflineCache}

    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    pushd backend
    find node_modules -type d -name prebuilds -prune -exec rm -rf {} +
    for module in better-sqlite3 bcrypt sqlite3; do
      (cd node_modules/$module && ../.bin/node-gyp rebuild --release)
      find node_modules/$module/build \( -type f ! -name '*.node' -o -path '*/Release/*/*' -o -name test_extension.node \) -delete
      find node_modules/$module/build -type d -empty -delete
    done
    rm -rf node_modules/node-gyp
    find node_modules -type d -name .bin -prune -exec rm -rf {} +
    popd

    pushd frontend
    yarn --offline locale-compile
    yarn --offline build
    popd

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    share=$out/share/nginx-proxy-manager
    mkdir -p $out/lib/nginx-proxy-manager $share

    cp -r backend $out/lib/nginx-proxy-manager/backend
    cp -r frontend/dist $share/frontend
    cp -r docker/rootfs/var/www/html $share/www
    cp -r docker/rootfs/etc/nginx $share/nginx
    cp docker/rootfs/etc/letsencrypt.ini $share/letsencrypt.ini
    cp docker/rootfs/etc/logrotate.d/nginx-proxy-manager $share/logrotate.conf

    makeWrapper ${lib.getExe nodejs} $out/bin/nginx-proxy-manager \
      --chdir $out/lib/nginx-proxy-manager/backend \
      --add-flags index.js \
      --set-default NODE_ENV production \
      --prefix PATH : ${
        lib.makeBinPath [
          openssl
          coreutils
          logrotate
        ]
      }

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    cd $out/lib/nginx-proxy-manager/backend
    node --input-type=module -e '
      import Database from "better-sqlite3";
      import bcrypt from "bcrypt";
      import sqlite3 from "sqlite3";
      new Database(":memory:");
      await bcrypt.hash("x", 4);
      new sqlite3.Database(":memory:");
    '

    runHook postInstallCheck
  '';

  passthru.nginx = nginxWithoutExtras;

  meta = {
    description = "Web UI and API for managing Nginx proxy hosts and Let's Encrypt certificates";
    homepage = "https://nginxproxymanager.com";
    changelog = "https://github.com/NginxProxyManager/nginx-proxy-manager/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "nginx-proxy-manager";
  };
})

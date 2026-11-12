{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeShellWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libdrm,
  libGL,
  libgbm,
  libpulseaudio,
  libva,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  pango,
  pipewire,
  systemd,
  vulkan-loader,
  xdg-utils,
  commandLineArgs ? "",
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "helium";
  version = "0.21.2.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${finalAttrs.version}/helium-${finalAttrs.version}-x86_64_linux.tar.xz";
    hash = "sha256-5VwlPggvePta4JTKRlpZ4GiC/XyH6/ODFlvrNWDgtRk=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeShellWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    glib
    gsettings-desktop-schemas
    gtk3
    libdrm
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    systemd
  ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/helium $out/bin
    cp -r . $out/opt/helium
    rm $out/opt/helium/{helium-wrapper,libqt5_shim.so,libqt6_shim.so}

    install -Dm644 helium.desktop -t $out/share/applications
    install -Dm644 product_logo_256.png $out/share/icons/hicolor/256x256/apps/helium.png

    runHook postInstall
  '';

  postFixup = ''
    makeShellWrapper $out/opt/helium/helium $out/bin/helium \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libGL
          libpulseaudio
          libva
          pipewire
          vulkan-loader
        ]
      } \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --add-flags ${lib.escapeShellArg commandLineArgs}
  '';

  meta = {
    description = "Private, fast, and honest web browser based on Chromium";
    homepage = "https://helium.computer";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "helium";
  };
})

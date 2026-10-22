# Non-flake entrypoint, using the same content-addressed public nixpkgs revision.
let
  pkgs = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/9b245a61778999b12b2d1ec48721095176f11c1f.tar.gz";
    sha256 = "sha256-53Ff10ySNXyesHjafJJw91ytVvwqZKROMrZcQCzwS44=";
  }) {};
in pkgs.mkShell {
  packages = with pkgs; [ quickshell python3 nodejs qt6.qtdeclarative qt6.qtshadertools inter glib libnotify sway-unwrapped hyprland grim wtype wlrctl wf-recorder ffmpeg wayland pkg-config ];
  shellHook = ''
    export PATH="$PWD/bin:$PATH"
    export ISLAND_FONT=${pkgs.inter}/share/fonts/truetype/InterVariable.ttf
    export ISLAND_QUICKSHELL=${pkgs.quickshell}/bin/quickshell
    export QML_IMPORT_PATH=${pkgs.quickshell}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
  '';
}

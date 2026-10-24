{
  description = "Island — a morphing Quickshell island for Hyprland";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/9b245a61778999b12b2d1ec48721095176f11c1f";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = nixpkgs.lib.genAttrs systems;
      # A disconnected ShellScreen can briefly outlive its QScreen on resume.
      # Quickshell 0.3.2 otherwise dereferences null while initializing a capture.
      quickshellFor = pkgs: pkgs.quickshell.overrideAttrs (old: {
        patches = (old.patches or []) ++ [ ./nix/patches/quickshell-null-screen.patch ];
      });
      source = nixpkgs.lib.cleanSourceWith {
        src = ./.;
        filter = path: type:
          let name = baseNameOf path;
          in !(builtins.elem name [ ".git" ".agents" ".aws" ".codex" ".direnv" ".cache" "artifacts" "__pycache__" "result" ])
             && !(nixpkgs.lib.hasSuffix ".pyc" name);
      };
    in {
      packages = eachSystem (system:
        let pkgs = import nixpkgs { inherit system; };
            quickshell = quickshellFor pkgs;
        in {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "island";
            version = "0.1.0";
            src = source;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            installPhase = ''
              runHook preInstall
              mkdir -p $out/share/island $out/bin
              cp -r src lib bin $out/share/island/
              cp ${pkgs.inter}/share/fonts/truetype/InterVariable.ttf $out/share/island/src/assets/InterVariable.ttf
              makeWrapper ${pkgs.python3.withPackages (ps: [ ps.dbus-next ])}/bin/python3 $out/bin/island \
                --add-flags $out/share/island/bin/island \
                --set ISLAND_ROOT $out/share/island \
                --set ISLAND_EXECUTABLE $out/bin/island \
                --set ISLAND_QUICKSHELL ${quickshell}/bin/quickshell \
                --set-default SSL_CERT_FILE ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
                --set-default PYTHONTZPATH ${pkgs.tzdata}/share/zoneinfo \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.glib pkgs.systemd pkgs.hyprland pkgs.alacritty pkgs.networkmanager ]}
              makeWrapper ${pkgs.python3}/bin/python3 $out/bin/island-askpass \
                --add-flags $out/share/island/bin/island-askpass
              runHook postInstall
            '';
            meta = {
              description = "An animated dynamic island desktop shell";
              mainProgram = "island";
              platforms = systems;
            };
          };
        });
      apps = eachSystem (system: {
        default = { type = "app"; meta.description = "Island morphing desktop shell"; program = "${self.packages.${system}.default}/bin/island"; };
      });
      devShells = eachSystem (system:
        let pkgs = import nixpkgs { inherit system; };
            quickshell = quickshellFor pkgs;
        in {
          default = pkgs.mkShell {
            packages = with pkgs; [
              (quickshellFor pkgs) (python3.withPackages (ps: [ ps.dbus-next ])) nodejs qt6.qtdeclarative qt6.qtshadertools
              inter glib libnotify brightnessctl wireplumber pipewire networkmanager
              sway-unwrapped hyprland grim wtype wlrctl wf-recorder ffmpeg wayland pkg-config
            ];
            shellHook = ''
              export PATH="$PWD/bin:$PATH"
              export ISLAND_FONT=${pkgs.inter}/share/fonts/truetype/InterVariable.ttf
              export ISLAND_QUICKSHELL=${quickshell}/bin/quickshell
              export QML_IMPORT_PATH=${quickshell}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml
            '';
          };
        });
      checks = eachSystem (system:
        let pkgs = import nixpkgs { inherit system; };
            quickshell = quickshellFor pkgs;
        in {
          policy = pkgs.runCommand "island-policy-tests" { nativeBuildInputs = [ pkgs.nodejs (pkgs.python3.withPackages (ps: [ ps.dbus-next ])) ]; } ''
            cp -r ${source} source
            chmod -R u+w source
            cd source
            node --test tests/*.test.js
            python3 -m unittest discover -s tests -p 'test_*.py'
            touch $out
          '';
          qml = pkgs.runCommand "island-qml-checks" {
            nativeBuildInputs = [ pkgs.qt6.qtdeclarative ];
            QML_IMPORT_PATH = "${quickshell}/lib/qt-6/qml:${pkgs.qt6.qtdeclarative}/lib/qt-6/qml";
          } ''
            cp -r ${source} source
            cd source
            bash tests/check-qml.sh
            touch $out
          '';
        });
      homeManagerModules.default = import ./nix/home-manager.nix self;
    };
}

{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchpatch,
  clipper,
  cmake,
  cups,
  doxygen,
  gdal,
  ninja,
  proj,
  qt5,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "OpenOrienteering-Mapper";
  version = "0.9.5";

  src = fetchFromGitHub {
    owner = "OpenOrienteering";
    repo = "mapper";
    rev = "v${version}";
    hash = "sha256-BQbryRV5diBkOtva9sYuLD8yo3IwFqrkz3qC+C6eEfE=";
  };

  patches = [
    # https://github.com/OpenOrienteering/mapper/pull/1907
    (fetchpatch {
      url = "https://github.com/OpenOrienteering/mapper/commit/bc52aa567e90a58d6963b44d5ae1909f3f841508.patch";
      hash = "sha256-pQzw2EfVay+0GOtIbh1KJOkILcj5LRMzmMYy9q+abK4=";
    })
    # https://github.com/OpenOrienteering/mapper/pull/2337
    (fetchpatch {
      url = "https://github.com/OpenOrienteering/mapper/commit/d1f214ee2abf140ae3615a2995f08c19ad81418a.patch";
      hash = "sha256-eJZpHdFPW7A69aazI+WRSK9N87d4A6x973hMYTHdw5I=";
    })
  ];

  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace "find_package(ClangTidy" "#find_package(ClangTidy"
    substituteInPlace packaging/custom_install.cmake.in \
      --replace "fixup_bundle_portable(" "#fixup_bundle_portable("
  '';

  nativeBuildInputs = [
    cmake
    doxygen
    ninja
    qt5.qttools
    qt5.wrapQtAppsHook
  ];

  buildInputs = [
    clipper
    cups
    gdal
    proj
    qt5.qtimageformats
    qt5.qtlocation
    qt5.qtsensors
    zlib
  ];

  cmakeFlags = [
    # Building the manual and bundling licenses fails
    # See https://github.com/NixOS/nixpkgs/issues/85306
    (lib.cmakeBool "LICENSING_PROVIDER" false)
    (lib.cmakeBool "Mapper_MANUAL_QTHELP" false)
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # FindGDAL is broken and always finds /Library/Framework unless this is
    # specified
    (lib.cmakeFeature "GDAL_INCLUDE_DIR" "${gdal}/include")
    (lib.cmakeFeature "GDAL_CONFIG" "${gdal}/bin/gdal-config")
    (lib.cmakeFeature "GDAL_LIBRARY" "${gdal}/lib/libgdal.dylib")
    # Don't bundle libraries
    (lib.cmakeBool "Mapper_PACKAGE_PROJ" false)
    (lib.cmakeBool "Mapper_PACKAGE_QT" false)
    (lib.cmakeBool "Mapper_PACKAGE_ASSISTANT" false)
    (lib.cmakeBool "Mapper_PACKAGE_GDAL" false)
  ];

  postInstall =
    with stdenv;
    lib.optionalString isDarwin ''
      mkdir -p $out/{Applications,bin}
      mv $out/Mapper.app $out/Applications
      ln -s $out/Applications/Mapper.app/Contents/MacOS/Mapper $out/bin/Mapper
    '';

  meta = {
    homepage = "https://www.openorienteering.org/apps/mapper/";
    description = "Orienteering mapmaking program";
    changelog = "https://github.com/OpenOrienteering/mapper/releases/tag/v${version}";
    license = lib.licenses.gpl3Plus;
    maintainers = with lib.maintainers; [
      mpickering
      sikmir
    ];
    platforms = with lib.platforms; unix;
    mainProgram = "Mapper";
  };
}

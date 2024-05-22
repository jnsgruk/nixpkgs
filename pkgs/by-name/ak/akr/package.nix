{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  libsodium,
  openssl,
  stdenv,
  darwin,
}:

rustPlatform.buildRustPackage rec {
  pname = "akr";
  version = "1.1.2";

  src = fetchFromGitHub {
    owner = "akamai";
    repo = "akr";
    rev = version;
    hash = "sha256-u82hIXFZsr8DvMPmr1qwSXlgodATdO3g4jHsWeYl3Po=";
  };

  cargoHash = "sha256-GQM8ZDhXYAmBuFfVP/pi/DvsVZTBVRsXTzxiQJ2NeNM=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs =
    [
      libsodium
      openssl
    ]
    ++ lib.optionals stdenv.isDarwin [
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.Security
      darwin.apple_sdk.frameworks.SystemConfiguration
    ];

  meta = with lib; {
    description = "Akamai Krypton CLI and SSH Agent";
    changelog = "https://github.com/akamai/akr/releases/tag/${version}";
    homepage = "https://github.com/akamai/akr";
    license = licenses.unfree;
    maintainers = with maintainers; [ jnsgruk ];
    mainProgram = "akr";
  };
}

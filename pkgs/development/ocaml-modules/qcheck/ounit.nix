{
  buildDunePackage,
  qcheck-core,
  ounit,
}:

buildDunePackage {
  pname = "qcheck-ounit";

  inherit (qcheck-core) version src patches;

  duneVersion = "3";

  propagatedBuildInputs = [
    qcheck-core
    ounit
  ];

  meta = qcheck-core.meta // {
    description = "OUnit backend for qcheck";
  };

}

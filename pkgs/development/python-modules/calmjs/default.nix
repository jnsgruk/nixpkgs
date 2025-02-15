{
  lib,
  fetchPypi,
  buildPythonPackage,
  calmjs-types,
  calmjs-parse,
  pytestCheckHook,
  setuptools,
}:

buildPythonPackage rec {
  pname = "calmjs";
  version = "3.4.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-73NQiY1RMdBrMIlm/VTvHY4dCHL1pQoj6a48CWRos3o=";
    extension = "zip";
  };

  build-system = [
    setuptools
  ];

  propagatedBuildInputs = [
    calmjs-parse
    calmjs-types
  ];

  checkInputs = [ pytestCheckHook ];

  disabledTests = [
    # spacing changes in argparse output
    "test_integration_choices_in_list"
    # formatting changes in argparse output
    "test_sorted_case_insensitivity"
    "test_sorted_simple_first"
    "test_sorted_standard"
  ];

  # ModuleNotFoundError: No module named 'calmjs.types'
  # Not yet clear how to run these tests correctly
  # https://github.com/calmjs/calmjs/issues/63
  # https://github.com/NixOS/nixpkgs/pull/186298
  disabledTestPaths = [
    "src/calmjs/tests/test_dist.py"
    "src/calmjs/tests/test_testing.py"
    "src/calmjs/tests/test_artifact.py"
    "src/calmjs/tests/test_interrogate.py"
    "src/calmjs/tests/test_loaderplugin.py"
    "src/calmjs/tests/test_npm.py"
    "src/calmjs/tests/test_runtime.py"
    "src/calmjs/tests/test_toolchain.py"
    "src/calmjs/tests/test_vlqsm.py"
    "src/calmjs/tests/test_yarn.py"
    "src/calmjs/tests/test_command.py"
  ];

  pythonImportsCheck = [ "calmjs" ];

  meta = with lib; {
    description = "Framework for building toolchains and utilities for working with the Node.js ecosystem";
    mainProgram = "calmjs";
    homepage = "https://github.com/calmjs/calmjs";
    license = licenses.gpl2;
    maintainers = with maintainers; [ onny ];
  };
}

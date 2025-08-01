/**
  Nix evaluation tests for various lib functions.

  Since these tests are implemented with Nix evaluation,
  error checking is limited to what `builtins.tryEval` can detect,
  which is `throw`'s and `abort`'s, without error messages.

  If you need to test error messages or more complex evaluations, see
  `lib/tests/modules.sh`, `lib/tests/sources.sh` or `lib/tests/filesystem.sh` as examples.

  To run these tests:

    [nixpkgs]$ nix-instantiate --eval --strict lib/tests/misc.nix

  If the resulting list is empty, all tests passed.
  Alternatively, to run all `lib` tests:

    [nixpkgs]$ nix-build lib/tests/release.nix
*/

let
  lib = import ../default.nix;

  inherit (lib)
    allUnique
    and
    attrNames
    attrsets
    attrsToList
    bitAnd
    bitOr
    bitXor
    boolToString
    callPackagesWith
    callPackageWith
    cartesianProduct
    cli
    composeExtensions
    composeManyExtensions
    concatLines
    concatMapAttrs
    concatMapAttrsStringSep
    concatMapStrings
    concatStrings
    concatStringsSep
    const
    escapeXML
    evalModules
    extends
    filter
    filterAttrs
    fix
    fold
    foldAttrs
    foldl
    foldl'
    foldlAttrs
    foldr
    functionArgs
    generators
    genList
    getExe
    getExe'
    getLicenseFromSpdxIdOr
    groupBy
    groupBy'
    hasAttrByPath
    hasInfix
    id
    ifilter0
    isStorePath
    lazyDerivation
    length
    lists
    listToAttrs
    makeExtensible
    makeIncludePath
    makeOverridable
    mapAttrs
    mapCartesianProduct
    matchAttrs
    mergeAttrs
    meta
    mod
    nameValuePair
    optionalDrvAttr
    optionAttrSetToDocList
    overrideExisting
    packagesFromDirectoryRecursive
    pipe
    range
    recursiveUpdateUntil
    removePrefix
    replaceString
    replicate
    runTests
    setFunctionArgs
    showAttrPath
    sort
    sortOn
    stringLength
    strings
    stringToCharacters
    systems
    tail
    take
    testAllTrue
    toBaseDigits
    toExtension
    toHexString
    fromHexString
    toInt
    toIntBase10
    toShellVars
    types
    updateManyAttrsByPath
    versions
    xor
    ;

  testingThrow = expr: {
    expr = (builtins.tryEval (builtins.seq expr "didn't throw"));
    expected = {
      success = false;
      value = false;
    };
  };
  testingEval = expr: {
    expr = (builtins.tryEval expr).success;
    expected = true;
  };

  testSanitizeDerivationName =
    { name, expected }:
    let
      drv = derivation {
        name = strings.sanitizeDerivationName name;
        builder = "x";
        system = "x";
      };
    in
    {
      # Evaluate the derivation so an invalid name would be caught
      expr = builtins.seq drv.drvPath drv.name;
      inherit expected;
    };

in

runTests {

  # CUSTOMIZATION

  testFunctionArgsMakeOverridable = {
    expr = functionArgs (
      makeOverridable (
        {
          a,
          b,
          c ? null,
        }:
        { }
      )
    );
    expected = {
      a = false;
      b = false;
      c = true;
    };
  };

  testFunctionArgsMakeOverridableOverride = {
    expr =
      functionArgs
        (makeOverridable
          (
            {
              a,
              b,
              c ? null,
            }:
            { }
          )
          {
            a = 1;
            b = 2;
          }
        ).override;
    expected = {
      a = false;
      b = false;
      c = true;
    };
  };

  testCallPackageWithOverridePreservesArguments =
    let
      f =
        {
          a ? 0,
          b,
        }:
        { };
      f' = callPackageWith {
        a = 1;
        b = 2;
      } f { };
    in
    {
      expr = functionArgs f'.override;
      expected = functionArgs f;
    };

  testCallPackagesWithOverridePreservesArguments =
    let
      f =
        {
          a ? 0,
          b,
        }:
        {
          nested = { };
        };
      f' = callPackagesWith {
        a = 1;
        b = 2;
      } f { };
    in
    {
      expr = functionArgs f'.nested.override;
      expected = functionArgs f;
    };

  # TRIVIAL

  testId = {
    expr = id 1;
    expected = 1;
  };

  testConst = {
    expr = const 2 3;
    expected = 2;
  };

  testPipe = {
    expr = pipe 2 [
      (x: x + 2) # 2 + 2 = 4
      (x: x * 2) # 4 * 2 = 8
    ];
    expected = 8;
  };

  testPipeEmpty = {
    expr = pipe 2 [ ];
    expected = 2;
  };

  testPipeStrings = {
    expr =
      pipe
        [ 3 4 ]
        [
          (map toString)
          (map (s: s + "\n"))
          concatStrings
        ];
    expected = ''
      3
      4
    '';
  };

  /*
    testOr = {
      expr = or true false;
      expected = true;
    };
  */

  testAnd = {
    expr = and true false;
    expected = false;
  };

  testXor = {
    expr = [
      (xor true false)
      (xor true true)
      (xor false false)
      (xor false true)
    ];
    expected = [
      true
      false
      false
      true
    ];
  };

  testComposeExtensions = {
    expr =
      let
        obj = makeExtensible (self: {
          foo = self.bar;
        });
        f = self: super: {
          bar = false;
          baz = true;
        };
        g = self: super: { bar = super.baz or false; };
        f_o_g = composeExtensions f g;
        composed = obj.extend f_o_g;
      in
      composed.foo;
    expected = true;
  };

  testComposeManyExtensions0 = {
    expr =
      let
        obj = makeExtensible (self: {
          foo = true;
        });
        emptyComposition = composeManyExtensions [ ];
        composed = obj.extend emptyComposition;
      in
      composed.foo;
    expected = true;
  };

  testComposeManyExtensions =
    let
      f = self: super: {
        bar = false;
        baz = true;
      };
      g = self: super: { bar = super.baz or false; };
      h = self: super: { qux = super.bar or false; };
      obj = makeExtensible (self: {
        foo = self.qux;
      });
    in
    {
      expr =
        let
          composition = composeManyExtensions [
            f
            g
            h
          ];
          composed = obj.extend composition;
        in
        composed.foo;
      expected = (obj.extend (composeExtensions f (composeExtensions g h))).foo;
    };

  testBitAnd = {
    expr = (bitAnd 3 10);
    expected = 2;
  };

  testBitOr = {
    expr = (bitOr 3 10);
    expected = 11;
  };

  testBitXor = {
    expr = (bitXor 3 10);
    expected = 9;
  };

  testToHexString = {
    expr = toHexString 250;
    expected = "FA";
  };

  testFromHexStringFirstExample = {
    expr = fromHexString "FF";
    expected = 255;
  };

  testFromHexStringSecondExample = {
    expr = fromHexString (builtins.hashString "sha256" "test");
    expected = 9223372036854775807;
  };

  testFromHexStringWithPrefix = {
    expr = fromHexString "0Xf";
    expected = 15;
  };

  testToBaseDigits = {
    expr = toBaseDigits 2 6;
    expected = [
      1
      1
      0
    ];
  };

  testFunctionArgsFunctor = {
    expr = functionArgs { __functor = self: { a, b }: null; };
    expected = {
      a = false;
      b = false;
    };
  };

  testFunctionArgsSetFunctionArgs = {
    expr = functionArgs (setFunctionArgs (args: args.x) { x = false; });
    expected = {
      x = false;
    };
  };

  # STRINGS

  testConcatMapStrings = {
    expr = concatMapStrings (x: x + ";") [
      "a"
      "b"
      "c"
    ];
    expected = "a;b;c;";
  };

  testConcatStringsSep = {
    expr = concatStringsSep "," [
      "a"
      "b"
      "c"
    ];
    expected = "a,b,c";
  };

  testConcatMapAttrsStringSepExamples = {
    expr = concatMapAttrsStringSep "\n" (name: value: "${name}: foo-${value}") {
      a = "0.1.0";
      b = "0.2.0";
    };
    expected = "a: foo-0.1.0\nb: foo-0.2.0";
  };

  testConcatLines = {
    expr = concatLines [
      "a"
      "b"
      "c"
    ];
    expected = "a\nb\nc\n";
  };

  testMakeIncludePathWithPkgs = {
    expr = (
      makeIncludePath [
        # makeIncludePath preferably selects the "dev" output
        {
          dev.outPath = "/dev";
          out.outPath = "/out";
          outPath = "/default";
        }
        # "out" is used if "dev" is not found
        {
          out.outPath = "/out";
          outPath = "/default";
        }
        # And it returns the derivation directly if there's no "out" either
        { outPath = "/default"; }
        # Same if the output is specified explicitly, even if there's a "dev"
        {
          dev.outPath = "/dev";
          outPath = "/default";
          outputSpecified = true;
        }
      ]
    );
    expected = "/dev/include:/out/include:/default/include:/default/include";
  };

  testMakeIncludePathWithEmptyList = {
    expr = (makeIncludePath [ ]);
    expected = "";
  };

  testMakeIncludePathWithOneString = {
    expr = (makeIncludePath [ "/usr" ]);
    expected = "/usr/include";
  };

  testMakeIncludePathWithManyString = {
    expr = (
      makeIncludePath [
        "/usr"
        "/usr/local"
      ]
    );
    expected = "/usr/include:/usr/local/include";
  };

  testReplaceStringString = {
    expr = strings.replaceString "." "_" "v1.2.3";
    expected = "v1_2_3";
  };

  testReplicateString = {
    expr = strings.replicate 5 "hello";
    expected = "hellohellohellohellohello";
  };

  # Test various strings are trimmed correctly
  testTrimString = {
    expr =
      let
        testValues =
          f:
          mapAttrs (_: f) {
            empty = "";
            cr = "\r";
            lf = "\n";
            tab = "\t";
            spaces = "   ";
            leading = "  Hello, world";
            trailing = "Hello, world   ";
            mixed = " Hello, world ";
            mixed-tabs = " \t\tHello, world \t \t ";
            multiline = "  Hello,\n  world!  ";
            multiline-crlf = "  Hello,\r\n  world!  ";
          };
      in
      {
        leading = testValues (strings.trimWith { start = true; });
        trailing = testValues (strings.trimWith { end = true; });
        both = testValues strings.trim;
      };
    expected = {
      leading = {
        empty = "";
        cr = "";
        lf = "";
        tab = "";
        spaces = "";
        leading = "Hello, world";
        trailing = "Hello, world   ";
        mixed = "Hello, world ";
        mixed-tabs = "Hello, world \t \t ";
        multiline = "Hello,\n  world!  ";
        multiline-crlf = "Hello,\r\n  world!  ";
      };
      trailing = {
        empty = "";
        cr = "";
        lf = "";
        tab = "";
        spaces = "";
        leading = "  Hello, world";
        trailing = "Hello, world";
        mixed = " Hello, world";
        mixed-tabs = " \t\tHello, world";
        multiline = "  Hello,\n  world!";
        multiline-crlf = "  Hello,\r\n  world!";
      };
      both = {
        empty = "";
        cr = "";
        lf = "";
        tab = "";
        spaces = "";
        leading = "Hello, world";
        trailing = "Hello, world";
        mixed = "Hello, world";
        mixed-tabs = "Hello, world";
        multiline = "Hello,\n  world!";
        multiline-crlf = "Hello,\r\n  world!";
      };
    };
  };

  testSplitStringsSimple = {
    expr = strings.splitString "." "a.b.c.d";
    expected = [
      "a"
      "b"
      "c"
      "d"
    ];
  };

  testSplitStringsEmpty = {
    expr = strings.splitString "." "a..b";
    expected = [
      "a"
      ""
      "b"
    ];
  };

  testSplitStringsOne = {
    expr = strings.splitString ":" "a.b";
    expected = [ "a.b" ];
  };

  testSplitStringsNone = {
    expr = strings.splitString "." "";
    expected = [ "" ];
  };

  testSplitStringsFirstEmpty = {
    expr = strings.splitString "/" "/a/b/c";
    expected = [
      ""
      "a"
      "b"
      "c"
    ];
  };

  testSplitStringsLastEmpty = {
    expr = strings.splitString ":" "2001:db8:0:0042::8a2e:370:";
    expected = [
      "2001"
      "db8"
      "0"
      "0042"
      ""
      "8a2e"
      "370"
      ""
    ];
  };

  testSplitStringsRegex = {
    expr = strings.splitString "\\[{}]()^$?*+|." "A\\[{}]()^$?*+|.B";
    expected = [
      "A"
      "B"
    ];
  };

  testSplitStringBySimpleDelimiter = {
    expr = strings.splitStringBy (
      prev: curr:
      builtins.elem curr [
        "."
        "-"
      ]
    ) false "foo.bar-baz";
    expected = [
      "foo"
      "bar"
      "baz"
    ];
  };

  testSplitStringByLeadingDelimiter = {
    expr = strings.splitStringBy (prev: curr: builtins.elem curr [ "." ]) false ".foo.bar.baz";
    expected = [
      ""
      "foo"
      "bar"
      "baz"
    ];
  };

  testSplitStringByTrailingDelimiter = {
    expr = strings.splitStringBy (prev: curr: builtins.elem curr [ "." ]) false "foo.bar.baz.";
    expected = [
      "foo"
      "bar"
      "baz"
      ""
    ];
  };

  testSplitStringByMultipleConsecutiveDelimiters = {
    expr = strings.splitStringBy (prev: curr: builtins.elem curr [ "." ]) false "foo...bar";
    expected = [
      "foo"
      ""
      ""
      "bar"
    ];
  };

  testSplitStringByKeepingSplitChar = {
    expr = strings.splitStringBy (prev: curr: builtins.elem curr [ "." ]) true "foo.bar.baz";
    expected = [
      "foo"
      ".bar"
      ".baz"
    ];
  };

  testSplitStringByCaseTransition = {
    expr = strings.splitStringBy (
      prev: curr: builtins.match "[a-z]" prev != null && builtins.match "[A-Z]" curr != null
    ) true "fooBarBaz";
    expected = [
      "foo"
      "Bar"
      "Baz"
    ];
  };

  testSplitStringByEmptyString = {
    expr = strings.splitStringBy (prev: curr: builtins.elem curr [ "." ]) false "";
    expected = [ "" ];
  };

  testSplitStringByComplexPredicate = {
    expr = strings.splitStringBy (
      prev: curr:
      prev != ""
      && curr != ""
      && builtins.match "[0-9]" prev != null
      && builtins.match "[a-z]" curr != null
    ) true "123abc456def";
    expected = [
      "123"
      "abc456"
      "def"
    ];
  };

  testSplitStringByUpperCaseStart = {
    expr = strings.splitStringBy (prev: curr: builtins.match "[A-Z]" curr != null) true "FooBarBaz";
    expected = [
      ""
      "Foo"
      "Bar"
      "Baz"
    ];
  };

  testEscapeShellArg = {
    expr = strings.escapeShellArg "esc'ape\nme";
    expected = "'esc'\\''ape\nme'";
  };

  testEscapeShellArgEmpty = {
    expr = strings.escapeShellArg "";
    expected = "''";
  };

  testEscapeShellArgs = {
    expr = strings.escapeShellArgs [
      "one"
      "two three"
      "four'five"
    ];
    expected = "one 'two three' 'four'\\''five'";
  };

  testEscapeShellArgsUnicode = {
    expr = strings.escapeShellArg "á";
    expected = "'á'";
  };

  testSplitStringsDerivation = {
    expr = take 3 (
      strings.splitString "/" (derivation {
        name = "name";
        builder = "builder";
        system = "system";
      })
    );
    expected = [
      ""
      "nix"
      "store"
    ];
  };

  testSplitVersionSingle = {
    expr = versions.splitVersion "1";
    expected = [ "1" ];
  };

  testSplitVersionDouble = {
    expr = versions.splitVersion "1.2";
    expected = [
      "1"
      "2"
    ];
  };

  testSplitVersionTriple = {
    expr = versions.splitVersion "1.2.3";
    expected = [
      "1"
      "2"
      "3"
    ];
  };

  testPadVersionLess = {
    expr = versions.pad 3 "1.2";
    expected = "1.2.0";
  };

  testPadVersionLessExtra = {
    expr = versions.pad 3 "1.3-rc1";
    expected = "1.3.0-rc1";
  };

  testPadVersionMore = {
    expr = versions.pad 3 "1.2.3.4";
    expected = "1.2.3";
  };

  testIsStorePath = {
    expr =
      let
        goodPath = "${builtins.storeDir}/d945ibfx9x185xf04b890y4f9g3cbb63-python-2.7.11";
        goodCAPath = "/1121rp0gvr1qya7hvy925g5kjwg66acz6sn1ra1hca09f1z5dsab";
      in
      {
        storePath = isStorePath goodPath;
        storePathDerivation = isStorePath (import ../.. { system = "x86_64-linux"; }).hello;
        storePathAppendix = isStorePath "${goodPath}/bin/python";
        nonAbsolute = isStorePath (concatStrings (tail (stringToCharacters goodPath)));
        asPath = isStorePath (/. + goodPath);
        otherPath = isStorePath "/something/else";

        caPath = isStorePath goodCAPath;
        caPathAppendix = isStorePath "${goodCAPath}/bin/python";
        caAsPath = isStorePath (/. + goodCAPath);

        otherVals = {
          attrset = isStorePath { };
          list = isStorePath [ ];
          int = isStorePath 42;
        };
      };
    expected = {
      storePath = true;
      storePathDerivation = true;
      storePathAppendix = false;
      nonAbsolute = false;
      asPath = true;
      caPath = true;
      caPathAppendix = false;
      caAsPath = true;
      otherPath = false;
      otherVals = {
        attrset = false;
        list = false;
        int = false;
      };
    };
  };

  testEscapeXML = {
    expr = escapeXML ''"test" 'test' < & >'';
    expected = "&quot;test&quot; &apos;test&apos; &lt; &amp; &gt;";
  };

  testToShellVars = {
    expr = ''
      ${toShellVars {
        STRing01 = "just a 'string'";
        _array_ = [
          "with"
          "more strings"
        ];
        assoc."with some" = ''
          strings
          possibly newlines
        '';
        drv = {
          outPath = "/drv";
          foo = "ignored attribute";
        };
        path = /path;
        stringable = {
          __toString = _: "hello toString";
          bar = "ignored attribute";
        };
      }}
    '';
    expected = ''
      STRing01='just a '\'''string'\''''
      declare -a _array_=(with 'more strings')
      declare -A assoc=(['with some']='strings
      possibly newlines
      ')
      drv=/drv
      path=/path
      stringable='hello toString'
    '';
  };

  testHasInfixFalse = {
    expr = hasInfix "c" "abde";
    expected = false;
  };

  testHasInfixTrue = {
    expr = hasInfix "c" "abcde";
    expected = true;
  };

  testHasInfixDerivation = {
    expr = hasInfix "hello" (import ../.. { system = "x86_64-linux"; }).hello;
    expected = true;
  };

  testHasInfixPath = {
    expr = hasInfix "tests" ./.;
    expected = true;
  };

  testHasInfixPathStoreDir = {
    expr = hasInfix builtins.storeDir ./.;
    expected = true;
  };

  testHasInfixToString = {
    expr = hasInfix "a" { __toString = _: "a"; };
    expected = true;
  };

  testRemovePrefixExample1 = {
    expr = removePrefix "foo." "foo.bar.baz";
    expected = "bar.baz";
  };
  testRemovePrefixExample2 = {
    expr = removePrefix "xxx" "foo.bar.baz";
    expected = "foo.bar.baz";
  };
  testRemovePrefixEmptyPrefix = {
    expr = removePrefix "" "foo";
    expected = "foo";
  };
  testRemovePrefixEmptyString = {
    expr = removePrefix "foo" "";
    expected = "";
  };
  testRemovePrefixEmptyBoth = {
    expr = removePrefix "" "";
    expected = "";
  };

  testNormalizePath = {
    expr = strings.normalizePath "//a/b//c////d/";
    expected = "/a/b/c/d/";
  };

  testCharToInt = {
    expr = strings.charToInt "A";
    expected = 65;
  };

  testEscapeC = {
    expr = strings.escapeC [ "\n" " " ] "Hello World\n";
    expected = "Hello\\x20World\\x0a";
  };

  testEscapeURL = testAllTrue [
    ("" == strings.escapeURL "")
    ("Hello" == strings.escapeURL "Hello")
    ("Hello%20World" == strings.escapeURL "Hello World")
    ("Hello%2FWorld" == strings.escapeURL "Hello/World")
    ("42%25" == strings.escapeURL "42%")
    (
      "%20%3F%26%3D%23%2B%25%21%3C%3E%23%22%7B%7D%7C%5C%5E%5B%5D%60%09%3A%2F%40%24%27%28%29%2A%2C%3B"
      == strings.escapeURL " ?&=#+%!<>#\"{}|\\^[]`\t:/@$'()*,;"
    )
  ];

  testToSentenceCase = {
    expr = strings.toSentenceCase "hello world";
    expected = "Hello world";
  };

  testToSentenceCasePath = testingThrow (strings.toSentenceCase ./.);

  testToCamelCase = {
    expr = strings.toCamelCase "hello world";
    expected = "helloWorld";
  };

  testToCamelCaseFromKebab = {
    expr = strings.toCamelCase "hello-world";
    expected = "helloWorld";
  };

  testToCamelCaseFromSnake = {
    expr = strings.toCamelCase "hello_world";
    expected = "helloWorld";
  };

  testToCamelCaseFromPascal = {
    expr = strings.toCamelCase "HelloWorld";
    expected = "helloWorld";
  };

  testToCamelCasePath = testingThrow (strings.toCamelCase ./.);

  testToInt = testAllTrue [
    # Naive
    (123 == toInt "123")
    (0 == toInt "0")
    # Whitespace Padding
    (123 == toInt " 123")
    (123 == toInt "123 ")
    (123 == toInt " 123 ")
    (123 == toInt "   123   ")
    (0 == toInt " 0")
    (0 == toInt "0 ")
    (0 == toInt " 0 ")
    (-1 == toInt "-1")
    (-1 == toInt " -1 ")
  ];

  testToIntFails = testAllTrue [
    (
      builtins.tryEval (toInt "") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt "123 123") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt "0 123") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " 0d ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " 1d ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " d0 ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt "00") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt "01") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt "002") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " 002 ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " foo ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " foo 123 ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toInt " foo123 ") == {
        success = false;
        value = false;
      }
    )
  ];

  testToIntBase10 = testAllTrue [
    # Naive
    (123 == toIntBase10 "123")
    (0 == toIntBase10 "0")
    # Whitespace Padding
    (123 == toIntBase10 " 123")
    (123 == toIntBase10 "123 ")
    (123 == toIntBase10 " 123 ")
    (123 == toIntBase10 "   123   ")
    (0 == toIntBase10 " 0")
    (0 == toIntBase10 "0 ")
    (0 == toIntBase10 " 0 ")
    # Zero Padding
    (123 == toIntBase10 "0123")
    (123 == toIntBase10 "0000123")
    (0 == toIntBase10 "000000")
    # Whitespace and Zero Padding
    (123 == toIntBase10 " 0123")
    (123 == toIntBase10 "0123 ")
    (123 == toIntBase10 " 0123 ")
    (123 == toIntBase10 " 0000123")
    (123 == toIntBase10 "0000123 ")
    (123 == toIntBase10 " 0000123 ")
    (0 == toIntBase10 " 000000")
    (0 == toIntBase10 "000000 ")
    (0 == toIntBase10 " 000000 ")
    (-1 == toIntBase10 "-1")
    (-1 == toIntBase10 " -1 ")
  ];

  testToIntBase10Fails = testAllTrue [
    (
      builtins.tryEval (toIntBase10 "") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 "123 123") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 "0 123") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " 0d ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " 1d ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " d0 ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " foo ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " foo 123 ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " foo 00123 ") == {
        success = false;
        value = false;
      }
    )
    (
      builtins.tryEval (toIntBase10 " foo00123 ") == {
        success = false;
        value = false;
      }
    )
  ];

  # LISTS

  testFilter = {
    expr = filter (x: x != "a") [
      "a"
      "b"
      "c"
      "a"
    ];
    expected = [
      "b"
      "c"
    ];
  };

  testIfilter0Example = {
    expr = ifilter0 (i: v: i == 0 || v > 2) [
      1
      2
      3
    ];
    expected = [
      1
      3
    ];
  };
  testIfilter0Empty = {
    expr = ifilter0 (i: v: abort "shouldn't be evaluated!") [ ];
    expected = [ ];
  };
  testIfilter0IndexOnly = {
    expr = length (
      ifilter0 (i: v: mod i 2 == 0) [
        (throw "0")
        (throw "1")
        (throw "2")
        (throw "3")
      ]
    );
    expected = 2;
  };
  testIfilter0All = {
    expr = ifilter0 (i: v: true) [
      10
      11
      12
      13
      14
      15
    ];
    expected = [
      10
      11
      12
      13
      14
      15
    ];
  };
  testIfilter0First = {
    expr = ifilter0 (i: v: i == 0) [
      10
      11
      12
      13
      14
      15
    ];
    expected = [ 10 ];
  };
  testIfilter0Last = {
    expr = ifilter0 (i: v: i == 5) [
      10
      11
      12
      13
      14
      15
    ];
    expected = [ 15 ];
  };

  testFold =
    let
      f = op: fold: fold op 0 (range 0 100);
      # fold with associative operator
      assoc = f builtins.add;
      # fold with non-associative operator
      nonAssoc = f builtins.sub;
    in
    {
      expr = {
        assocRight = assoc foldr;
        # right fold with assoc operator is same as left fold
        assocRightIsLeft = assoc foldr == assoc foldl;
        nonAssocRight = nonAssoc foldr;
        nonAssocLeft = nonAssoc foldl;
        # with non-assoc operator the fold results are not the same
        nonAssocRightIsNotLeft = nonAssoc foldl != nonAssoc foldr;
        # fold is an alias for foldr
        foldIsRight = nonAssoc fold == nonAssoc foldr;
      };
      expected = {
        assocRight = 5050;
        assocRightIsLeft = true;
        nonAssocRight = 50;
        nonAssocLeft = (-5050);
        nonAssocRightIsNotLeft = true;
        foldIsRight = true;
      };
    };

  testFoldl'Empty = {
    expr = foldl' (acc: el: abort "operation not called") 0 [ ];
    expected = 0;
  };

  testFoldl'IntegerAdding = {
    expr = foldl' (acc: el: acc + el) 0 [
      1
      2
      3
    ];
    expected = 6;
  };

  # The accumulator isn't forced deeply
  testFoldl'NonDeep = {
    expr = take 3 (foldl' (acc: el: [ el ] ++ acc) [ (abort "unevaluated list entry") ] [ 1 2 3 ]);
    expected = [
      3
      2
      1
    ];
  };

  # Compared to builtins.foldl', lib.foldl' evaluates the first accumulator strictly too
  testFoldl'StrictInitial = {
    expr = (builtins.tryEval (foldl' (acc: el: el) (throw "hello") [ ])).success;
    expected = false;
  };

  # Make sure we don't get a stack overflow for large lists
  # This number of elements would notably cause a stack overflow if it was implemented without the `foldl'` builtin
  testFoldl'Large = {
    expr = foldl' (acc: el: acc + el) 0 (range 0 100000);
    expected = 5000050000;
  };

  testTake = testAllTrue [
    (
      [ ] == (take 0 [
        1
        2
        3
      ])
    )
    (
      [ 1 ] == (take 1 [
        1
        2
        3
      ])
    )
    (
      [
        1
        2
      ] == (take 2 [
        1
        2
        3
      ])
    )
    (
      [
        1
        2
        3
      ] == (take 3 [
        1
        2
        3
      ])
    )
    (
      [
        1
        2
        3
      ] == (take 4 [
        1
        2
        3
      ])
    )
  ];

  testTakeEnd =
    let
      inherit (lib) takeEnd;
    in
    testAllTrue [
      (
        takeEnd 0 [
          1
          2
          3
        ] == [ ]
      )
      (
        takeEnd 1 [
          1
          2
          3
        ] == [ 3 ]
      )
      (
        takeEnd 2 [
          1
          2
          3
        ] == [
          2
          3
        ]
      )
      (
        takeEnd 3 [
          1
          2
          3
        ] == [
          1
          2
          3
        ]
      )
      (
        takeEnd 4 [
          1
          2
          3
        ] == [
          1
          2
          3
        ]
      )
      (takeEnd 0 [ ] == [ ])
      (takeEnd 1 [ ] == [ ])
      (
        takeEnd (-1) [
          1
          2
          3
        ] == [ ]
      )
      (takeEnd (-1) [ ] == [ ])
    ];

  testDrop =
    let
      inherit (lib) drop;
    in
    testAllTrue [
      # list index -1 is out of bounds
      # ([ 1 2 3 ] == (drop (-1) [  1 2 3 ]))
      (
        drop 0 [
          1
          2
          3
        ] == [
          1
          2
          3
        ]
      )
      (
        drop 1 [
          1
          2
          3
        ] == [
          2
          3
        ]
      )
      (
        drop 2 [
          1
          2
          3
        ] == [ 3 ]
      )
      (
        drop 3 [
          1
          2
          3
        ] == [ ]
      )
      (
        drop 4 [
          1
          2
          3
        ] == [ ]
      )
      (drop 0 [ ] == [ ])
      (drop 1 [ ] == [ ])
    ];

  testDropEnd =
    let
      inherit (lib) dropEnd;
    in
    testAllTrue [
      (
        dropEnd 0 [
          1
          2
          3
        ] == [
          1
          2
          3
        ]
      )
      (
        dropEnd 1 [
          1
          2
          3
        ] == [
          1
          2
        ]
      )
      (
        dropEnd 2 [
          1
          2
          3
        ] == [ 1 ]
      )
      (
        dropEnd 3 [
          1
          2
          3
        ] == [ ]
      )
      (
        dropEnd 4 [
          1
          2
          3
        ] == [ ]
      )
      (dropEnd 0 [ ] == [ ])
      (dropEnd 1 [ ] == [ ])
      (
        dropEnd (-1) [
          1
          2
          3
        ] == [
          1
          2
          3
        ]
      )
      (dropEnd (-1) [ ] == [ ])
    ];

  testListHasPrefixExample1 = {
    expr = lists.hasPrefix [ 1 2 ] [ 1 2 3 4 ];
    expected = true;
  };
  testListHasPrefixExample2 = {
    expr = lists.hasPrefix [ 0 1 ] [ 1 2 3 4 ];
    expected = false;
  };
  testListHasPrefixLazy = {
    expr = lists.hasPrefix [ 1 ] [ 1 (abort "lib.lists.hasPrefix is not lazy") ];
    expected = true;
  };
  testListHasPrefixEmptyPrefix = {
    expr = lists.hasPrefix [ ] [ 1 2 ];
    expected = true;
  };
  testListHasPrefixEmptyList = {
    expr = lists.hasPrefix [ 1 2 ] [ ];
    expected = false;
  };

  testListRemovePrefixExample1 = {
    expr = lists.removePrefix [ 1 2 ] [ 1 2 3 4 ];
    expected = [
      3
      4
    ];
  };
  testListRemovePrefixExample2 = {
    expr = (builtins.tryEval (lists.removePrefix [ 0 1 ] [ 1 2 3 4 ])).success;
    expected = false;
  };
  testListRemovePrefixEmptyPrefix = {
    expr = lists.removePrefix [ ] [ 1 2 ];
    expected = [
      1
      2
    ];
  };
  testListRemovePrefixEmptyList = {
    expr = (builtins.tryEval (lists.removePrefix [ 1 2 ] [ ])).success;
    expected = false;
  };

  testFoldAttrs = {
    expr =
      foldAttrs (n: a: [ n ] ++ a)
        [ ]
        [
          {
            a = 2;
            b = 7;
          }
          {
            a = 3;
            c = 8;
          }
        ];
    expected = {
      a = [
        2
        3
      ];
      b = [ 7 ];
      c = [ 8 ];
    };
  };

  testListCommonPrefixExample1 = {
    expr = lists.commonPrefix [ 1 2 3 4 5 6 ] [ 1 2 4 8 ];
    expected = [
      1
      2
    ];
  };
  testListCommonPrefixExample2 = {
    expr = lists.commonPrefix [ 1 2 3 ] [ 1 2 3 4 5 ];
    expected = [
      1
      2
      3
    ];
  };
  testListCommonPrefixExample3 = {
    expr = lists.commonPrefix [ 1 2 3 ] [ 4 5 6 ];
    expected = [ ];
  };
  testListCommonPrefixEmpty = {
    expr = lists.commonPrefix [ ] [ 1 2 3 ];
    expected = [ ];
  };
  testListCommonPrefixSame = {
    expr = lists.commonPrefix [ 1 2 3 ] [ 1 2 3 ];
    expected = [
      1
      2
      3
    ];
  };
  testListCommonPrefixLazy = {
    expr = lists.commonPrefix [ 1 ] [ 1 (abort "lib.lists.commonPrefix shouldn't evaluate this") ];
    expected = [ 1 ];
  };
  # This would stack overflow if `commonPrefix` were implemented using recursion
  testListCommonPrefixLong =
    let
      longList = genList (n: n) 100000;
    in
    {
      expr = lists.commonPrefix longList longList;
      expected = longList;
    };

  testSort = {
    expr = sort builtins.lessThan [
      40
      2
      30
      42
    ];
    expected = [
      2
      30
      40
      42
    ];
  };

  testSortOn = {
    expr = sortOn stringLength [
      "aa"
      "b"
      "cccc"
    ];
    expected = [
      "b"
      "aa"
      "cccc"
    ];
  };

  testSortOnEmpty = {
    expr = sortOn (throw "nope") [ ];
    expected = [ ];
  };

  testSortOnIncomparable = {
    expr = map (x: x.f x.ok) (
      sortOn (x: x.ok) [
        {
          ok = 1;
          f = x: x;
        }
        {
          ok = 3;
          f = x: x + 3;
        }
        {
          ok = 2;
          f = x: x;
        }
      ]
    );
    expected = [
      1
      2
      6
    ];
  };

  testReplaceString = {
    expr = replaceString "world" "Nix" "Hello, world!";
    expected = "Hello, Nix!";
  };

  testReplicate = {
    expr = replicate 3 "a";
    expected = [
      "a"
      "a"
      "a"
    ];
  };

  testToIntShouldConvertStringToInt = {
    expr = toInt "27";
    expected = 27;
  };

  testToIntShouldThrowErrorIfItCouldNotConvertToInt = {
    expr = builtins.tryEval (toInt "\"foo\"");
    expected = {
      success = false;
      value = false;
    };
  };

  testHasAttrByPathTrue = {
    expr = hasAttrByPath [ "a" "b" ] {
      a = {
        b = "yey";
      };
    };
    expected = true;
  };

  testHasAttrByPathFalse = {
    expr = hasAttrByPath [ "a" "b" ] {
      a = {
        c = "yey";
      };
    };
    expected = false;
  };

  testHasAttrByPathNonStrict = {
    expr = hasAttrByPath [ ] (throw "do not use");
    expected = true;
  };

  testLongestValidPathPrefix_empty_empty = {
    expr = attrsets.longestValidPathPrefix [ ] { };
    expected = [ ];
  };

  testLongestValidPathPrefix_empty_nonStrict = {
    expr = attrsets.longestValidPathPrefix [ ] (throw "do not use");
    expected = [ ];
  };

  testLongestValidPathPrefix_zero = {
    expr = attrsets.longestValidPathPrefix [ "a" (throw "do not use") ] { d = null; };
    expected = [ ];
  };

  testLongestValidPathPrefix_zero_b = {
    expr = attrsets.longestValidPathPrefix [ "z" "z" ] "remarkably harmonious";
    expected = [ ];
  };

  testLongestValidPathPrefix_one = {
    expr = attrsets.longestValidPathPrefix [ "a" "b" "c" ] { a = null; };
    expected = [ "a" ];
  };

  testLongestValidPathPrefix_two = {
    expr = attrsets.longestValidPathPrefix [ "a" "b" "c" ] { a.b = null; };
    expected = [
      "a"
      "b"
    ];
  };

  testLongestValidPathPrefix_three = {
    expr = attrsets.longestValidPathPrefix [ "a" "b" "c" ] { a.b.c = null; };
    expected = [
      "a"
      "b"
      "c"
    ];
  };

  testLongestValidPathPrefix_three_extra = {
    expr = attrsets.longestValidPathPrefix [ "a" "b" "c" ] { a.b.c.d = throw "nope"; };
    expected = [
      "a"
      "b"
      "c"
    ];
  };

  testFindFirstIndexExample1 = {
    expr = lists.findFirstIndex (x: x > 3) (abort "index found, so a default must not be evaluated") [
      1
      6
      4
    ];
    expected = 1;
  };

  testFindFirstIndexExample2 = {
    expr = lists.findFirstIndex (x: x > 9) "a very specific default" [
      1
      6
      4
    ];
    expected = "a very specific default";
  };

  testFindFirstIndexEmpty = {
    expr = lists.findFirstIndex (abort "when the list is empty, the predicate is not needed") null [ ];
    expected = null;
  };

  testFindFirstIndexSingleMatch = {
    expr = lists.findFirstIndex (x: x == 5) null [ 5 ];
    expected = 0;
  };

  testFindFirstIndexSingleDefault = {
    expr = lists.findFirstIndex (x: false) null [
      (abort "if the predicate doesn't access the value, it must not be evaluated")
    ];
    expected = null;
  };

  testFindFirstIndexNone = {
    expr = builtins.tryEval (
      lists.findFirstIndex (x: x == 2) null [
        1
        (throw "the last element must be evaluated when there's no match")
      ]
    );
    expected = {
      success = false;
      value = false;
    };
  };

  # Makes sure that the implementation doesn't cause a stack overflow
  testFindFirstIndexBig = {
    expr = lists.findFirstIndex (x: x == 1000000) null (range 0 1000000);
    expected = 1000000;
  };

  testFindFirstIndexLazy = {
    expr = lists.findFirstIndex (x: x == 1) null [
      1
      (abort "list elements after the match must not be evaluated")
    ];
    expected = 0;
  };

  testFindFirstExample1 = {
    expr = lists.findFirst (x: x > 3) 7 [
      1
      6
      4
    ];
    expected = 6;
  };

  testFindFirstExample2 = {
    expr = lists.findFirst (x: x > 9) 7 [
      1
      6
      4
    ];
    expected = 7;
  };

  testAllUnique_true = {
    expr = allUnique [
      3
      2
      4
      1
    ];
    expected = true;
  };
  testAllUnique_false = {
    expr = allUnique [
      3
      2
      3
      4
    ];
    expected = false;
  };

  # ATTRSETS

  testConcatMapAttrs = {
    expr =
      concatMapAttrs
        (name: value: {
          ${name} = value;
          ${name + value} = value;
        })
        {
          foo = "bar";
          foobar = "baz";
        };
    expected = {
      foo = "bar";
      foobar = "baz";
      foobarbaz = "baz";
    };
  };

  testFilterAttrs = {
    expr = filterAttrs (n: v: n != "a" && (v.hello or false) == true) {
      a.hello = true;
      b.hello = true;
      c = {
        hello = true;
        world = false;
      };
      d.hello = false;
    };
    expected = {
      b.hello = true;
      c = {
        hello = true;
        world = false;
      };
    };
  };

  # code from example
  testFoldlAttrs = {
    expr = {
      example =
        foldlAttrs
          (acc: name: value: {
            sum = acc.sum + value;
            names = acc.names ++ [ name ];
          })
          {
            sum = 0;
            names = [ ];
          }
          {
            foo = 1;
            bar = 10;
          };
      # should just return the initial value
      emptySet = foldlAttrs (throw "function not needed") 123 { };
      # should just evaluate to the last value
      valuesNotNeeded =
        foldlAttrs
          (
            acc: _name: _v:
            acc
          )
          3
          {
            z = throw "value z not needed";
            a = throw "value a not needed";
          };
      # the accumulator doesnt have to be an attrset it can be as trivial as being just a number or string
      trivialAcc =
        foldlAttrs
          (
            acc: _name: v:
            acc * 10 + v
          )
          1
          {
            z = 1;
            a = 2;
          };
    };
    expected = {
      example = {
        sum = 11;
        names = [
          "bar"
          "foo"
        ];
      };
      emptySet = 123;
      valuesNotNeeded = 3;
      trivialAcc = 121;
    };
  };

  testMergeAttrsListExample1 = {
    expr = attrsets.mergeAttrsList [
      {
        a = 0;
        b = 1;
      }
      {
        c = 2;
        d = 3;
      }
    ];
    expected = {
      a = 0;
      b = 1;
      c = 2;
      d = 3;
    };
  };
  testMergeAttrsListExample2 = {
    expr = attrsets.mergeAttrsList [
      { a = 0; }
      { a = 1; }
    ];
    expected = {
      a = 1;
    };
  };
  testMergeAttrsListExampleMany =
    let
      list = genList (
        n:
        listToAttrs (
          genList (
            m:
            let
              # Integer divide n by two to create duplicate attributes
              str = "halfn${toString (n / 2)}m${toString m}";
            in
            nameValuePair str str
          ) 100
        )
      ) 100;
    in
    {
      expr = attrsets.mergeAttrsList list;
      expected = foldl' mergeAttrs { } list;
    };

  # code from the example
  testRecursiveUpdateUntil = {
    expr =
      recursiveUpdateUntil
        (
          path: l: r:
          path == [ "foo" ]
        )
        {
          # first attribute set
          foo.bar = 1;
          foo.baz = 2;
          bar = 3;
        }
        {
          #second attribute set
          foo.bar = 1;
          foo.quz = 2;
          baz = 4;
        };
    expected = {
      foo.bar = 1; # 'foo.*' from the second set
      foo.quz = 2;
      bar = 3; # 'bar' from the first set
      baz = 4; # 'baz' from the second set
    };
  };

  testMatchAttrsMatchingExact = {
    expr =
      matchAttrs
        {
          cpu = {
            bits = 64;
          };
        }
        {
          cpu = {
            bits = 64;
          };
        };
    expected = true;
  };

  testMatchAttrsMismatch = {
    expr =
      matchAttrs
        {
          cpu = {
            bits = 128;
          };
        }
        {
          cpu = {
            bits = 64;
          };
        };
    expected = false;
  };

  testMatchAttrsMatchingImplicit = {
    expr = matchAttrs { cpu = { }; } {
      cpu = {
        bits = 64;
      };
    };
    expected = true;
  };

  testMatchAttrsMissingAttrs = {
    expr = matchAttrs { cpu = { }; } { };
    expected = false;
  };

  testOverrideExistingEmpty = {
    expr = overrideExisting { } { a = 1; };
    expected = { };
  };

  testOverrideExistingDisjoint = {
    expr = overrideExisting { b = 2; } { a = 1; };
    expected = {
      b = 2;
    };
  };

  testOverrideExistingOverride = {
    expr = overrideExisting {
      a = 3;
      b = 2;
    } { a = 1; };
    expected = {
      a = 1;
      b = 2;
    };
  };

  testListAttrsReverse =
    let
      exampleAttrs = {
        foo = 1;
        bar = "asdf";
        baz = [
          1
          3
          3
          7
        ];
        fnord = null;
      };
      exampleSingletonList = [
        {
          name = "foo";
          value = 1;
        }
      ];
    in
    {
      expr = {
        isReverseToListToAttrs = builtins.listToAttrs (attrsToList exampleAttrs) == exampleAttrs;
        isReverseToAttrsToList =
          attrsToList (builtins.listToAttrs exampleSingletonList) == exampleSingletonList;
        testDuplicatePruningBehaviour = attrsToList (
          builtins.listToAttrs [
            {
              name = "a";
              value = 2;
            }
            {
              name = "a";
              value = 1;
            }
          ]
        );
      };
      expected = {
        isReverseToAttrsToList = true;
        isReverseToListToAttrs = true;
        testDuplicatePruningBehaviour = [
          {
            name = "a";
            value = 2;
          }
        ];
      };
    };

  testAttrsToListsCanDealWithFunctions = testingEval (attrsToList {
    someFunc = a: a + 1;
  });

  # FIXED-POINTS

  testFix = {
    expr = fix (x: {
      a = if x ? a then "a" else "b";
    });
    expected = {
      a = "a";
    };
  };

  testToExtension = {
    expr = [
      (fix (final: {
        a = 0;
        c = final.a;
      }))
      (fix (
        extends
          (toExtension {
            a = 1;
            b = 2;
          })
          (final: {
            a = 0;
            c = final.a;
          })
      ))
      (fix (
        extends
          (toExtension (prev: {
            a = 1;
            b = prev.a;
          }))
          (final: {
            a = 0;
            c = final.a;
          })
      ))
      (fix (
        extends
          (toExtension (
            final: prev: {
              a = 1;
              b = prev.a;
              c = final.a + 1;
            }
          ))
          (final: {
            a = 0;
            c = final.a;
          })
      ))
    ];
    expected = [
      {
        a = 0;
        c = 0;
      }
      {
        a = 1;
        b = 2;
        c = 1;
      }
      {
        a = 1;
        b = 0;
        c = 1;
      }
      {
        a = 1;
        b = 0;
        c = 2;
      }
    ];
  };

  # GENERATORS
  # these tests assume attributes are converted to lists
  # in alphabetical order

  testMkKeyValueDefault = {
    expr = generators.mkKeyValueDefault { } ":" "f:oo" "bar";
    expected = ''f\:oo:bar'';
  };

  testMkValueString = {
    expr =
      let
        vals = {
          int = 42;
          string = ''fo"o'';
          bool = true;
          bool2 = false;
          null = null;
          # float = 42.23; # floats are strange
        };
      in
      mapAttrs (const (generators.mkValueStringDefault { })) vals;
    expected = {
      int = "42";
      string = ''fo"o'';
      bool = "true";
      bool2 = "false";
      null = "null";
      # float = "42.23" true false [ "bar" ] ]'';
    };
  };

  testToKeyValue = {
    expr = generators.toKeyValue { } {
      key = "value";
      "other=key" = "baz";
    };
    expected = ''
      key=value
      other\=key=baz
    '';
  };

  testToINIEmpty = {
    expr = generators.toINI { } { };
    expected = "";
  };

  testToINIEmptySection = {
    expr = generators.toINI { } {
      foo = { };
      bar = { };
    };
    expected = ''
      [bar]

      [foo]
    '';
  };

  testToINIDuplicateKeys = {
    expr = generators.toINI { listsAsDuplicateKeys = true; } {
      foo.bar = true;
      baz.qux = [
        1
        false
      ];
    };
    expected = ''
      [baz]
      qux=1
      qux=false

      [foo]
      bar=true
    '';
  };

  testToINIDefaultEscapes = {
    expr = generators.toINI { } {
      "no [ and ] allowed unescaped" = {
        "and also no = in keys" = 42;
      };
    };
    expected = ''
      [no \[ and \] allowed unescaped]
      and also no \= in keys=42
    '';
  };

  testToINIDefaultFull = {
    expr = generators.toINI { } {
      "section 1" = {
        attribute1 = 5;
        x = "Me-se JarJar Binx";
        # booleans are converted verbatim by default
        boolean = false;
      };
      "foo[]" = {
        "he\\h=he" = "this is okay";
      };
    };
    expected = ''
      [foo\[\]]
      he\h\=he=this is okay

      [section 1]
      attribute1=5
      boolean=false
      x=Me-se JarJar Binx
    '';
  };

  testToINIWithGlobalSectionEmpty = {
    expr = generators.toINIWithGlobalSection { } {
      globalSection = {
      };
      sections = {
      };
    };
    expected = '''';
  };

  testToINIWithGlobalSectionGlobalEmptyIsTheSameAsToINI =
    let
      sections = {
        "section 1" = {
          attribute1 = 5;
          x = "Me-se JarJar Binx";
        };
        "foo" = {
          "he\\h=he" = "this is okay";
        };
      };
    in
    {
      expr = generators.toINIWithGlobalSection { } {
        globalSection = { };
        sections = sections;
      };
      expected = generators.toINI { } sections;
    };

  testToINIWithGlobalSectionFull = {
    expr = generators.toINIWithGlobalSection { } {
      globalSection = {
        foo = "bar";
        test = false;
      };
      sections = {
        "section 1" = {
          attribute1 = 5;
          x = "Me-se JarJar Binx";
        };
        "foo" = {
          "he\\h=he" = "this is okay";
        };
      };
    };
    expected = ''
      foo=bar
      test=false

      [foo]
      he\h\=he=this is okay

      [section 1]
      attribute1=5
      x=Me-se JarJar Binx
    '';
  };

  testToGitINI = {
    expr = generators.toGitINI {
      user = {
        email = "user@example.org";
        name = "John Doe";
        signingKey = "00112233445566778899AABBCCDDEEFF";
      };
      gpg.program = "path-to-gpg";
      tag.gpgSign = true;
      include.path = "~/path/to/config.inc";
      includeIf."gitdif:~/src/dir".path = "~/path/to/conditional.inc";
      extra = {
        boolean = true;
        integer = 38;
        name = "value";
        subsection.value = "test";
      };
    };
    expected = ''
      [extra]
      ${"\t"}boolean = true
      ${"\t"}integer = 38
      ${"\t"}name = "value"

      [extra "subsection"]
      ${"\t"}value = "test"

      [gpg]
      ${"\t"}program = "path-to-gpg"

      [include]
      ${"\t"}path = "~/path/to/config.inc"

      [includeIf "gitdif:~/src/dir"]
      ${"\t"}path = "~/path/to/conditional.inc"

      [tag]
      ${"\t"}gpgSign = true

      [user]
      ${"\t"}email = "user@example.org"
      ${"\t"}name = "John Doe"
      ${"\t"}signingKey = "00112233445566778899AABBCCDDEEFF"
    '';
  };

  # right now only invocation check
  testToJSONSimple =
    let
      val = {
        foobar = [
          "baz"
          1
          2
          3
        ];
      };
    in
    {
      expr = generators.toJSON { } val;
      # trivial implementation
      expected = builtins.toJSON val;
    };

  # right now only invocation check
  testToYAMLSimple =
    let
      val = {
        list = [
          { one = 1; }
          { two = 2; }
        ];
        all = 42;
      };
    in
    {
      expr = generators.toYAML { } val;
      # trivial implementation
      expected = builtins.toJSON val;
    };

  testToPretty =
    let
      deriv = derivation {
        name = "test";
        builder = "/bin/sh";
        system = "aarch64-linux";
      };
    in
    {
      expr = mapAttrs (const (generators.toPretty { multiline = false; })) rec {
        int = 42;
        float = 0.1337;
        bool = true;
        emptystring = "";
        string = "fn\${o}\"r\\d";
        newlinestring = "\n";
        path = /. + "/foo";
        null_ = null;
        function = x: x;
        functionArgs =
          {
            arg ? 4,
            foo,
          }:
          arg;
        list = [
          3
          4
          function
          [ false ]
        ];
        emptylist = [ ];
        attrs = {
          foo = null;
          "foo b/ar" = "baz";
        };
        emptyattrs = { };
        drv = deriv;
      };
      expected = rec {
        int = "42";
        float = "0.1337";
        bool = "true";
        emptystring = ''""'';
        string = ''"fn\''${o}\"r\\d"'';
        newlinestring = "\"\\n\"";
        path = "/foo";
        null_ = "null";
        function = "<function>";
        functionArgs = "<function, args: {arg?, foo}>";
        list = "[ 3 4 ${function} [ false ] ]";
        emptylist = "[ ]";
        attrs = "{ foo = null; \"foo b/ar\" = \"baz\"; }";
        emptyattrs = "{ }";
        drv = "<derivation ${deriv.name}>";
      };
    };

  testToPrettyLimit =
    let
      a.b = 1;
      a.c = a;
    in
    {
      expr = generators.toPretty { } (
        generators.withRecursion {
          throwOnDepthLimit = false;
          depthLimit = 2;
        } a
      );
      expected = "{\n  b = 1;\n  c = {\n    b = \"<unevaluated>\";\n    c = {\n      b = \"<unevaluated>\";\n      c = \"<unevaluated>\";\n    };\n  };\n}";
    };

  testToPrettyLimitThrow =
    let
      a.b = 1;
      a.c = a;
    in
    {
      expr =
        (builtins.tryEval (generators.toPretty { } (generators.withRecursion { depthLimit = 2; } a)))
        .success;
      expected = false;
    };

  testWithRecursionDealsWithFunctors =
    let
      functor = {
        __functor = self: { a, b }: null;
      };
      a = {
        value = "1234";
        b = functor;
        c.d = functor;
      };
    in
    {
      expr = generators.toPretty { } (
        generators.withRecursion {
          depthLimit = 1;
          throwOnDepthLimit = false;
        } a
      );
      expected = "{\n  b = <function, args: {a, b}>;\n  c = {\n    d = \"<unevaluated>\";\n  };\n  value = \"<unevaluated>\";\n}";
    };

  testToPrettyMultiline = {
    expr = mapAttrs (const (generators.toPretty { })) {
      list = [
        3
        4
        [ false ]
      ];
      attrs = {
        foo = null;
        bar.foo = "baz";
      };
      newlinestring = "\n";
      multilinestring = ''
        hello
        ''${there}
        te'''st
      '';
      multilinestring' = ''
        hello
        there
        test'';
    };
    expected = {
      list = ''
        [
          3
          4
          [
            false
          ]
        ]'';
      attrs = ''
        {
          bar = {
            foo = "baz";
          };
          foo = null;
        }'';
      newlinestring = "''\n  \n''";
      multilinestring = ''
        '''
          hello
          '''''${there}
          te''''st
        ''''';
      multilinestring' = ''
        '''
          hello
          there
          test''''';

    };
  };

  testToPrettyAllowPrettyValues = {
    expr = generators.toPretty { allowPrettyValues = true; } {
      __pretty = v: "«" + v + "»";
      val = "foo";
    };
    expected = "«foo»";
  };

  testToPlistUnescaped = {
    expr = mapAttrs (const (generators.toPlist { })) {
      value = {
        nested.values = {
          int = 42;
          float = 0.1337;
          bool = true;
          emptystring = "";
          string = "fn\${o}\"r\\d";
          newlinestring = "\n";
          path = /. + "/foo";
          null_ = null;
          list = [
            3
            4
            "test"
          ];
          emptylist = [ ];
          attrs = {
            foo = null;
            "foo b/ar" = "baz";
          };
          emptyattrs = { };
          "keys are not <escaped>" = "and < neither are string values";
        };
      };
    };
    expected = {
      value = builtins.readFile ./test-to-plist-unescaped-expected.plist;
    };
  };

  testToPlistEscaped = {
    expr = mapAttrs (const (generators.toPlist { escape = true; })) {
      value = {
        nested.values = {
          int = 42;
          float = 0.1337;
          bool = true;
          emptystring = "";
          string = "fn\${o}\"r\\d";
          newlinestring = "\n";
          path = /. + "/foo";
          null_ = null;
          list = [
            3
            4
            "test"
          ];
          emptylist = [ ];
          attrs = {
            foo = null;
            "foo b/ar" = "baz";
          };
          emptyattrs = { };
          "keys are <escaped>" = "and < so are string values";
        };
      };
    };
    expected = {
      value = builtins.readFile ./test-to-plist-escaped-expected.plist;
    };
  };

  testToLuaEmptyAttrSet = {
    expr = generators.toLua { } { };
    expected = ''{}'';
  };

  testToLuaEmptyList = {
    expr = generators.toLua { } [ ];
    expected = ''{}'';
  };

  testToLuaListOfVariousTypes = {
    expr = generators.toLua { } [
      null
      43
      3.14159
      true
    ];
    expected = ''
      {
        nil,
        43,
        3.14159,
        true
      }'';
  };

  testToLuaString = {
    expr = generators.toLua { } ''double-quote (") and single quotes (')'';
    expected = ''"double-quote (\") and single quotes (')"'';
  };

  testToLuaAttrsetWithLuaInline = {
    expr = generators.toLua { } { x = generators.mkLuaInline ''"abc" .. "def"''; };
    expected = ''
      {
        ["x"] = ("abc" .. "def")
      }'';
  };

  testToLuaAttrsetWithSpaceInKey = {
    expr = generators.toLua { } { "some space and double-quote (\")" = 42; };
    expected = ''
      {
        ["some space and double-quote (\")"] = 42
      }'';
  };

  testToLuaWithoutMultiline = {
    expr = generators.toLua { multiline = false; } [
      41
      43
    ];
    expected = ''{ 41, 43 }'';
  };

  testToLuaEmptyBindings = {
    expr = generators.toLua { asBindings = true; } { };
    expected = "";
  };

  testToLuaBindings = {
    expr = generators.toLua { asBindings = true; } {
      x1 = 41;
      _y = {
        a = 43;
      };
    };
    expected = ''
      _y = {
        ["a"] = 43
      }
      x1 = 41
    '';
  };

  testToLuaPartialTableBindings = {
    expr = generators.toLua { asBindings = true; } { "x.y" = 42; };
    expected = ''
      x.y = 42
    '';
  };

  testToLuaIndentedBindings = {
    expr =
      generators.toLua
        {
          asBindings = true;
          indent = "  ";
        }
        {
          x = {
            y = 42;
          };
        };
    expected = "  x = {\n    [\"y\"] = 42\n  }\n";
  };

  testToLuaBindingsWithSpace = testingThrow (
    generators.toLua { asBindings = true; } { "with space" = 42; }
  );

  testToLuaBindingsWithLeadingDigit = testingThrow (
    generators.toLua { asBindings = true; } { "11eleven" = 42; }
  );

  testToLuaBasicExample = {
    expr = generators.toLua { } {
      cmd = [
        "typescript-language-server"
        "--stdio"
      ];
      settings.workspace.library = generators.mkLuaInline ''vim.api.nvim_get_runtime_file("", true)'';
    };
    expected = ''
      {
        ["cmd"] = {
          "typescript-language-server",
          "--stdio"
        },
        ["settings"] = {
          ["workspace"] = {
            ["library"] = (vim.api.nvim_get_runtime_file("", true))
          }
        }
      }'';
  };

  # CLI

  testToGNUCommandLine = {
    expr = cli.toGNUCommandLine { } {
      data = builtins.toJSON { id = 0; };
      X = "PUT";
      retry = 3;
      retry-delay = null;
      url = [
        "https://example.com/foo"
        "https://example.com/bar"
      ];
      silent = false;
      verbose = true;
    };

    expected = [
      "-X"
      "PUT"
      "--data"
      "{\"id\":0}"
      "--retry"
      "3"
      "--url"
      "https://example.com/foo"
      "--url"
      "https://example.com/bar"
      "--verbose"
    ];
  };

  testToGNUCommandLineSeparator = {
    expr = cli.toGNUCommandLine { optionValueSeparator = "="; } {
      data = builtins.toJSON { id = 0; };
      X = "PUT";
      retry = 3;
      retry-delay = null;
      url = [
        "https://example.com/foo"
        "https://example.com/bar"
      ];
      silent = false;
      verbose = true;
    };

    expected = [
      "-X=PUT"
      "--data={\"id\":0}"
      "--retry=3"
      "--url=https://example.com/foo"
      "--url=https://example.com/bar"
      "--verbose"
    ];
  };

  testToGNUCommandLineShell = {
    expr = cli.toGNUCommandLineShell { } {
      data = builtins.toJSON { id = 0; };
      X = "PUT";
      retry = 3;
      retry-delay = null;
      url = [
        "https://example.com/foo"
        "https://example.com/bar"
      ];
      silent = false;
      verbose = true;
    };

    expected = "-X PUT --data '{\"id\":0}' --retry 3 --url https://example.com/foo --url https://example.com/bar --verbose";
  };

  testSanitizeDerivationNameLeadingDots = testSanitizeDerivationName {
    name = "..foo";
    expected = "foo";
  };

  testSanitizeDerivationNameUnicode = testSanitizeDerivationName {
    name = "fö";
    expected = "f-";
  };

  testSanitizeDerivationNameAscii = testSanitizeDerivationName {
    name = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
    expected = "-+--.-0123456789-=-?-ABCDEFGHIJKLMNOPQRSTUVWXYZ-_-abcdefghijklmnopqrstuvwxyz-";
  };

  testSanitizeDerivationNameTooLong = testSanitizeDerivationName {
    name = "This string is loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong";
    expected = "loooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooong";
  };

  testSanitizeDerivationNameTooLongWithInvalid = testSanitizeDerivationName {
    name = "Hello there aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa &&&&&&&&";
    expected = "there-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-";
  };

  testSanitizeDerivationNameEmpty = testSanitizeDerivationName {
    name = "";
    expected = "unknown";
  };

  # https://github.com/NixOS/nixpkgs/issues/396849
  "test: submodule definitions aren't unchecked when evaluating submodule documentation" = {
    expr =
      let
        module =
          { lib, ... }:
          {
            options.foo = lib.mkOption { type = lib.types.submodule submodule; };
          };

        submodule = {
          options.bar = lib.mkOption { type = lib.types.int; };
          config.submoduleWrong = throw "yikes";
        };

        options = (evalModules { modules = [ module ]; }).options;

        renderableOpts = filter (o: !o.internal) (optionAttrSetToDocList options);
        # Evaluate the whole docs
      in
      builtins.deepSeq renderableOpts
        # Return the locations
        (map (o: o.loc) renderableOpts);
    expected = [
      [
        "_module"
        "args"
      ]
      [ "foo" ]
      [
        "foo"
        "bar"
      ]
    ];
  };

  testFreeformOptions = {
    expr =
      let
        submodule =
          { lib, ... }:
          {
            freeformType = lib.types.attrsOf (
              lib.types.submodule {
                options.bar = lib.mkOption { };
              }
            );
            options.bar = lib.mkOption { };
          };

        module =
          { lib, ... }:
          {
            options.foo = lib.mkOption {
              type = lib.types.submodule submodule;
            };
          };

        options =
          (evalModules {
            modules = [ module ];
          }).options;

        locs = filter (o: !o.internal) (optionAttrSetToDocList options);
      in
      map (o: o.loc) locs;
    expected = [
      [
        "_module"
        "args"
      ]
      [ "foo" ]
      [
        "foo"
        "<name>"
        "bar"
      ]
      [
        "foo"
        "bar"
      ]
    ];
  };

  testAttrsWithName = {
    expr =
      let
        eval = evalModules {
          modules = [
            {
              options = {
                foo = lib.mkOption {
                  type = lib.types.attrsWith {
                    placeholder = "MyCustomPlaceholder";
                    elemType = lib.types.submodule {
                      options.bar = lib.mkOption {
                        type = lib.types.int;
                        default = 42;
                      };
                    };
                  };
                };
              };
            }
          ];
        };
        opt = eval.options.foo;
      in
      (opt.type.getSubOptions opt.loc).bar.loc;
    expected = [
      "foo"
      "<MyCustomPlaceholder>"
      "bar"
    ];
  };

  testShowOptionWithPlaceholder = {
    # <name>, *, should not be escaped. It is used as a placeholder by convention.
    # Other symbols should be escaped. `{}`
    expr = lib.showOption [
      "<name>"
      "<myName>"
      "*"
      "{foo}"
    ];
    expected = "<name>.<myName>.*.\"{foo}\"";
  };

  testCartesianProductOfEmptySet = {
    expr = cartesianProduct { };
    expected = [ { } ];
  };

  testCartesianProductOfOneSet = {
    expr = cartesianProduct {
      a = [
        1
        2
        3
      ];
    };
    expected = [
      { a = 1; }
      { a = 2; }
      { a = 3; }
    ];
  };

  testCartesianProductOfTwoSets = {
    expr = cartesianProduct {
      a = [ 1 ];
      b = [
        10
        20
      ];
    };
    expected = [
      {
        a = 1;
        b = 10;
      }
      {
        a = 1;
        b = 20;
      }
    ];
  };

  testCartesianProductOfTwoSetsWithOneEmpty = {
    expr = cartesianProduct {
      a = [ ];
      b = [
        10
        20
      ];
    };
    expected = [ ];
  };

  testCartesianProductOfThreeSets = {
    expr = cartesianProduct {
      a = [
        1
        2
        3
      ];
      b = [
        10
        20
        30
      ];
      c = [
        100
        200
        300
      ];
    };
    expected = [
      {
        a = 1;
        b = 10;
        c = 100;
      }
      {
        a = 1;
        b = 10;
        c = 200;
      }
      {
        a = 1;
        b = 10;
        c = 300;
      }

      {
        a = 1;
        b = 20;
        c = 100;
      }
      {
        a = 1;
        b = 20;
        c = 200;
      }
      {
        a = 1;
        b = 20;
        c = 300;
      }

      {
        a = 1;
        b = 30;
        c = 100;
      }
      {
        a = 1;
        b = 30;
        c = 200;
      }
      {
        a = 1;
        b = 30;
        c = 300;
      }

      {
        a = 2;
        b = 10;
        c = 100;
      }
      {
        a = 2;
        b = 10;
        c = 200;
      }
      {
        a = 2;
        b = 10;
        c = 300;
      }

      {
        a = 2;
        b = 20;
        c = 100;
      }
      {
        a = 2;
        b = 20;
        c = 200;
      }
      {
        a = 2;
        b = 20;
        c = 300;
      }

      {
        a = 2;
        b = 30;
        c = 100;
      }
      {
        a = 2;
        b = 30;
        c = 200;
      }
      {
        a = 2;
        b = 30;
        c = 300;
      }

      {
        a = 3;
        b = 10;
        c = 100;
      }
      {
        a = 3;
        b = 10;
        c = 200;
      }
      {
        a = 3;
        b = 10;
        c = 300;
      }

      {
        a = 3;
        b = 20;
        c = 100;
      }
      {
        a = 3;
        b = 20;
        c = 200;
      }
      {
        a = 3;
        b = 20;
        c = 300;
      }

      {
        a = 3;
        b = 30;
        c = 100;
      }
      {
        a = 3;
        b = 30;
        c = 200;
      }
      {
        a = 3;
        b = 30;
        c = 300;
      }
    ];
  };

  testMapCartesianProductOfOneSet = {
    expr = mapCartesianProduct ({ a }: a * 2) {
      a = [
        1
        2
        3
      ];
    };
    expected = [
      2
      4
      6
    ];
  };

  testMapCartesianProductOfTwoSets = {
    expr = mapCartesianProduct ({ a, b }: a + b) {
      a = [ 1 ];
      b = [
        10
        20
      ];
    };
    expected = [
      11
      21
    ];
  };

  testMapCartesianProcutOfTwoSetsWithOneEmpty = {
    expr = mapCartesianProduct (x: x.a + x.b) {
      a = [ ];
      b = [
        10
        20
      ];
    };
    expected = [ ];
  };

  testMapCartesianProductOfThreeSets = {
    expr =
      mapCartesianProduct
        (
          {
            a,
            b,
            c,
          }:
          a + b + c
        )
        {
          a = [
            1
            2
            3
          ];
          b = [
            10
            20
            30
          ];
          c = [
            100
            200
            300
          ];
        };
    expected = [
      111
      211
      311
      121
      221
      321
      131
      231
      331
      112
      212
      312
      122
      222
      322
      132
      232
      332
      113
      213
      313
      123
      223
      323
      133
      233
      333
    ];
  };

  # The example from the showAttrPath documentation
  testShowAttrPathExample = {
    expr = showAttrPath [
      "foo"
      "10"
      "bar"
    ];
    expected = "foo.\"10\".bar";
  };

  testShowAttrPathEmpty = {
    expr = showAttrPath [ ];
    expected = "<root attribute path>";
  };

  testShowAttrPathVarious = {
    expr = showAttrPath [
      "."
      "foo"
      "2"
      "a2-b"
      "_bc'de"
    ];
    expected = ''".".foo."2".a2-b._bc'de'';
  };

  testGroupBy = {
    expr = groupBy (n: toString (mod n 5)) (range 0 16);
    expected = {
      "0" = [
        0
        5
        10
        15
      ];
      "1" = [
        1
        6
        11
        16
      ];
      "2" = [
        2
        7
        12
      ];
      "3" = [
        3
        8
        13
      ];
      "4" = [
        4
        9
        14
      ];
    };
  };

  testGroupBy' = {
    expr = groupBy' builtins.add 0 (x: boolToString (x > 2)) [
      5
      1
      2
      3
      4
    ];
    expected = {
      false = 3;
      true = 12;
    };
  };

  # The example from the updateManyAttrsByPath documentation
  testUpdateManyAttrsByPathExample = {
    expr = updateManyAttrsByPath [
      {
        path = [
          "a"
          "b"
        ];
        update = old: { d = old.c; };
      }
      {
        path = [
          "a"
          "b"
          "c"
        ];
        update = old: old + 1;
      }
      {
        path = [
          "x"
          "y"
        ];
        update = old: "xy";
      }
    ] { a.b.c = 0; };
    expected = {
      a = {
        b = {
          d = 1;
        };
      };
      x = {
        y = "xy";
      };
    };
  };

  # If there are no updates, the value is passed through
  testUpdateManyAttrsByPathNone = {
    expr = updateManyAttrsByPath [ ] "something";
    expected = "something";
  };

  # A single update to the root path is just like applying the function directly
  testUpdateManyAttrsByPathSingleIncrement = {
    expr = updateManyAttrsByPath [
      {
        path = [ ];
        update = old: old + 1;
      }
    ] 0;
    expected = 1;
  };

  # Multiple updates can be applied are done in order
  testUpdateManyAttrsByPathMultipleIncrements = {
    expr = updateManyAttrsByPath [
      {
        path = [ ];
        update = old: old + "a";
      }
      {
        path = [ ];
        update = old: old + "b";
      }
      {
        path = [ ];
        update = old: old + "c";
      }
    ] "";
    expected = "abc";
  };

  # If an update doesn't use the value, all previous updates are not evaluated
  testUpdateManyAttrsByPathLazy = {
    expr = updateManyAttrsByPath [
      {
        path = [ ];
        update = old: old + throw "nope";
      }
      {
        path = [ ];
        update = old: "untainted";
      }
    ] (throw "start");
    expected = "untainted";
  };

  # Deeply nested attributes can be updated without affecting others
  testUpdateManyAttrsByPathDeep = {
    expr =
      updateManyAttrsByPath
        [
          {
            path = [
              "a"
              "b"
              "c"
            ];
            update = old: old + 1;
          }
        ]
        {
          a.b.c = 0;

          a.b.z = 0;
          a.y.z = 0;
          x.y.z = 0;
        };
    expected = {
      a.b.c = 1;

      a.b.z = 0;
      a.y.z = 0;
      x.y.z = 0;
    };
  };

  # Nested attributes are updated first
  testUpdateManyAttrsByPathNestedBeforehand = {
    expr =
      updateManyAttrsByPath
        [
          {
            path = [ "a" ];
            update = old: old // { x = old.b; };
          }
          {
            path = [
              "a"
              "b"
            ];
            update = old: old + 1;
          }
        ]
        {
          a.b = 0;
        };
    expected = {
      a.b = 1;
      a.x = 1;
    };
  };

  ## Levenshtein distance functions and co.
  testCommonPrefixLengthEmpty = {
    expr = strings.commonPrefixLength "" "hello";
    expected = 0;
  };

  testCommonPrefixLengthSame = {
    expr = strings.commonPrefixLength "hello" "hello";
    expected = 5;
  };

  testCommonPrefixLengthDiffering = {
    expr = strings.commonPrefixLength "hello" "hey";
    expected = 2;
  };

  testCommonSuffixLengthEmpty = {
    expr = strings.commonSuffixLength "" "hello";
    expected = 0;
  };

  testCommonSuffixLengthSame = {
    expr = strings.commonSuffixLength "hello" "hello";
    expected = 5;
  };

  testCommonSuffixLengthDiffering = {
    expr = strings.commonSuffixLength "test" "rest";
    expected = 3;
  };

  testLevenshteinEmpty = {
    expr = strings.levenshtein "" "";
    expected = 0;
  };

  testLevenshteinOnlyAdd = {
    expr = strings.levenshtein "" "hello there";
    expected = 11;
  };

  testLevenshteinOnlyRemove = {
    expr = strings.levenshtein "hello there" "";
    expected = 11;
  };

  testLevenshteinOnlyTransform = {
    expr = strings.levenshtein "abcdef" "ghijkl";
    expected = 6;
  };

  testLevenshteinMixed = {
    expr = strings.levenshtein "kitchen" "sitting";
    expected = 5;
  };

  testLevenshteinAtMostZeroFalse = {
    expr = strings.levenshteinAtMost 0 "foo" "boo";
    expected = false;
  };

  testLevenshteinAtMostZeroTrue = {
    expr = strings.levenshteinAtMost 0 "foo" "foo";
    expected = true;
  };

  testLevenshteinAtMostOneFalse = {
    expr = strings.levenshteinAtMost 1 "car" "ct";
    expected = false;
  };

  testLevenshteinAtMostOneTrue = {
    expr = strings.levenshteinAtMost 1 "car" "cr";
    expected = true;
  };

  # We test levenshteinAtMost 2 particularly well because it uses a complicated
  # implementation
  testLevenshteinAtMostTwoIsEmpty = {
    expr = strings.levenshteinAtMost 2 "" "";
    expected = true;
  };

  testLevenshteinAtMostTwoIsZero = {
    expr = strings.levenshteinAtMost 2 "abcdef" "abcdef";
    expected = true;
  };

  testLevenshteinAtMostTwoIsOne = {
    expr = strings.levenshteinAtMost 2 "abcdef" "abddef";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff0False = {
    expr = strings.levenshteinAtMost 2 "abcdef" "aczyef";
    expected = false;
  };

  testLevenshteinAtMostTwoDiff0Outer = {
    expr = strings.levenshteinAtMost 2 "abcdef" "zbcdez";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff0DelLeft = {
    expr = strings.levenshteinAtMost 2 "abcdef" "bcdefz";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff0DelRight = {
    expr = strings.levenshteinAtMost 2 "abcdef" "zabcde";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff1False = {
    expr = strings.levenshteinAtMost 2 "abcdef" "bddez";
    expected = false;
  };

  testLevenshteinAtMostTwoDiff1DelLeft = {
    expr = strings.levenshteinAtMost 2 "abcdef" "bcdez";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff1DelRight = {
    expr = strings.levenshteinAtMost 2 "abcdef" "zbcde";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff2False = {
    expr = strings.levenshteinAtMost 2 "hello" "hxo";
    expected = false;
  };

  testLevenshteinAtMostTwoDiff2True = {
    expr = strings.levenshteinAtMost 2 "hello" "heo";
    expected = true;
  };

  testLevenshteinAtMostTwoDiff3 = {
    expr = strings.levenshteinAtMost 2 "hello" "ho";
    expected = false;
  };

  testLevenshteinAtMostThreeFalse = {
    expr = strings.levenshteinAtMost 3 "hello" "Holla!";
    expected = false;
  };

  testLevenshteinAtMostThreeTrue = {
    expr = strings.levenshteinAtMost 3 "hello" "Holla";
    expected = true;
  };

  # DERIVATIONS

  testLazyDerivationIsLazyInDerivationForAttrNames = {
    expr = attrNames (lazyDerivation {
      derivation = throw "not lazy enough";
    });
    # It's ok to add attribute names here when lazyDerivation is improved
    # in accordance with its inline comments.
    expected = [
      "drvPath"
      "meta"
      "name"
      "out"
      "outPath"
      "outputName"
      "outputs"
      "system"
      "type"
    ];
  };

  testLazyDerivationIsLazyInDerivationForPassthruAttr = {
    expr =
      (lazyDerivation {
        derivation = throw "not lazy enough";
        passthru.tests = "whatever is in tests";
      }).tests;
    expected = "whatever is in tests";
  };

  testLazyDerivationIsLazyInDerivationForPassthruAttr2 = {
    # passthru.tests is not a special case. It works for any attr.
    expr =
      (lazyDerivation {
        derivation = throw "not lazy enough";
        passthru.foo = "whatever is in foo";
      }).foo;
    expected = "whatever is in foo";
  };

  testLazyDerivationIsLazyInDerivationForMeta = {
    expr =
      (lazyDerivation {
        derivation = throw "not lazy enough";
        meta = "whatever is in meta";
      }).meta;
    expected = "whatever is in meta";
  };

  testLazyDerivationReturnsDerivationAttrs =
    let
      derivation = {
        type = "derivation";
        outputs = [ "out" ];
        out = "test out";
        outPath = "test outPath";
        outputName = "out";
        drvPath = "test drvPath";
        name = "test name";
        system = "test system";
        meta = "test meta";
      };
    in
    {
      expr = lazyDerivation { inherit derivation; };
      expected = derivation;
    };

  testOptionalDrvAttr =
    let
      mkDerivation =
        args:
        derivation (
          args
          // {
            builder = "builder";
            system = "system";
            __ignoreNulls = true;
          }
        );
    in
    {
      expr =
        (mkDerivation {
          name = "foo";
          x = optionalDrvAttr true 1;
          y = optionalDrvAttr false 1;
        }).drvPath;
      expected =
        (mkDerivation {
          name = "foo";
          x = 1;
        }).drvPath;
    };

  testLazyDerivationMultiOutputReturnsDerivationAttrs =
    let
      derivation = {
        type = "derivation";
        outputs = [
          "out"
          "dev"
        ];
        dev = "test dev";
        out = "test out";
        outPath = "test outPath";
        outputName = "out";
        drvPath = "test drvPath";
        name = "test name";
        system = "test system";
        meta.position = "/hi:23";
      };
    in
    {
      expr = lazyDerivation {
        inherit derivation;
        outputs = [
          "out"
          "dev"
        ];
        passthru.meta.position = "/hi:23";
      };
      expected = derivation;
    };

  testTypeDescriptionInt = {
    expr = (with types; int).description;
    expected = "signed integer";
  };
  testTypeDescriptionIntsPositive = {
    expr = (with types; ints.positive).description;
    expected = "positive integer, meaning >0";
  };
  testTypeDescriptionIntsPositiveOrEnumAuto = {
    expr = (with types; either ints.positive (enum [ "auto" ])).description;
    expected = ''positive integer, meaning >0, or value "auto" (singular enum)'';
  };
  testTypeDescriptionListOfPositive = {
    expr = (with types; listOf ints.positive).description;
    expected = "list of (positive integer, meaning >0)";
  };
  testTypeDescriptionListOfInt = {
    expr = (with types; listOf int).description;
    expected = "list of signed integer";
  };
  testTypeDescriptionListOfListOfInt = {
    expr = (with types; listOf (listOf int)).description;
    expected = "list of list of signed integer";
  };
  testTypeDescriptionListOfEitherStrOrBool = {
    expr = (with types; listOf (either str bool)).description;
    expected = "list of (string or boolean)";
  };
  testTypeDescriptionEitherListOfStrOrBool = {
    expr = (with types; either (listOf bool) str).description;
    expected = "(list of boolean) or string";
  };
  testTypeDescriptionEitherStrOrListOfBool = {
    expr = (with types; either str (listOf bool)).description;
    expected = "string or list of boolean";
  };
  testTypeDescriptionOneOfListOfStrOrBool = {
    expr =
      (
        with types;
        oneOf [
          (listOf bool)
          str
        ]
      ).description;
    expected = "(list of boolean) or string";
  };
  testTypeDescriptionOneOfListOfStrOrBoolOrNumber = {
    expr =
      (
        with types;
        oneOf [
          (listOf bool)
          str
          number
        ]
      ).description;
    expected = "(list of boolean) or string or signed integer or floating point number";
  };
  testTypeDescriptionEitherListOfBoolOrEitherStringOrNumber = {
    expr = (with types; either (listOf bool) (either str number)).description;
    expected = "(list of boolean) or string or signed integer or floating point number";
  };
  testTypeDescriptionEitherEitherListOfBoolOrStringOrNumber = {
    expr = (with types; either (either (listOf bool) str) number).description;
    expected = "(list of boolean) or string or signed integer or floating point number";
  };
  testTypeDescriptionEitherNullOrBoolOrString = {
    expr = (with types; either (nullOr bool) str).description;
    expected = "null or boolean or string";
  };
  testTypeDescriptionEitherListOfEitherBoolOrStrOrInt = {
    expr = (with types; either (listOf (either bool str)) int).description;
    expected = "(list of (boolean or string)) or signed integer";
  };
  testTypeDescriptionEitherIntOrListOrEitherBoolOrStr = {
    expr = (with types; either int (listOf (either bool str))).description;
    expected = "signed integer or list of (boolean or string)";
  };
  testTypeFunctionToPropagateFunctionArgs = {
    expr = lib.functionArgs (
      (types.functionTo types.null).merge
        [ ]
        [
          {
            value =
              {
                a,
                b ? false,
                ...
              }:
              null;
          }
          {
            value =
              {
                b,
                c ? false,
                ...
              }:
              null;
          }
        ]
    );
    expected = {
      a = false;
      b = false;
      c = true;
    };
  };

  # Meta
  testGetExe'Output = {
    expr = getExe' {
      type = "derivation";
      out = "somelonghash";
      bin = "somelonghash";
    } "executable";
    expected = "somelonghash/bin/executable";
  };

  testGetExeOutput = {
    expr = getExe {
      type = "derivation";
      out = "somelonghash";
      bin = "somelonghash";
      meta.mainProgram = "mainProgram";
    };
    expected = "somelonghash/bin/mainProgram";
  };

  testGetExe'FailureFirstArg = testingThrow (getExe' "not a derivation" "executable");

  testGetExe'FailureSecondArg = testingThrow (getExe' { type = "derivation"; } "dir/executable");

  testGetLicenseFromSpdxIdOrExamples = {
    expr = [
      (getLicenseFromSpdxIdOr "MIT" null)
      (getLicenseFromSpdxIdOr "mIt" null)
      (getLicenseFromSpdxIdOr "MY LICENSE" lib.licenses.free)
      (getLicenseFromSpdxIdOr "MY LICENSE" null)
    ];
    expected = [
      lib.licenses.mit
      lib.licenses.mit
      lib.licenses.free
      null
    ];
  };

  testGetLicenseFromSpdxIdOrThrow = testingThrow (
    getLicenseFromSpdxIdOr "MY LICENSE" (throw "No SPDX ID matches MY LICENSE")
  );

  testPlatformMatch = {
    expr = meta.platformMatch { system = "x86_64-linux"; } "x86_64-linux";
    expected = true;
  };

  testPlatformMatchAttrs = {
    expr = meta.platformMatch (systems.elaborate "x86_64-linux") (systems.elaborate "x86_64-linux")
    .parsed;
    expected = true;
  };

  testPlatformMatchNoMatch = {
    expr = meta.platformMatch { system = "x86_64-darwin"; } "x86_64-linux";
    expected = false;
  };

  testPlatformMatchMissingSystem = {
    expr = meta.platformMatch { } "x86_64-linux";
    expected = false;
  };

  testPackagesFromDirectoryRecursive = {
    expr = packagesFromDirectoryRecursive {
      callPackage = path: overrides: import path overrides;
      directory = ./packages-from-directory/plain;
    };
    expected = {
      a = "a";
      b = "b";
      # Note: Other files/directories in `./test-data/c/` are ignored and can be
      # used by `package.nix`.
      c = "c";
      my-namespace = {
        d = "d";
        e = "e";
        f = "f";
        my-sub-namespace = {
          g = "g";
          h = "h";
        };
      };
    };
  };

  # Make sure that passing a string for the `directory` works.
  #
  # See: https://github.com/NixOS/nixpkgs/pull/361424#discussion_r1934813568
  # See: https://github.com/NixOS/nix/issues/9428
  testPackagesFromDirectoryRecursiveStringDirectory = {
    expr = packagesFromDirectoryRecursive {
      callPackage = path: overrides: import path overrides;
      # Do NOT remove the `builtins.toString` call here!!!
      directory = builtins.toString ./packages-from-directory/plain;
    };
    expected = {
      a = "a";
      b = "b";
      # Note: Other files/directories in `./test-data/c/` are ignored and can be
      # used by `package.nix`.
      c = "c";
      my-namespace = {
        d = "d";
        e = "e";
        f = "f";
        my-sub-namespace = {
          g = "g";
          h = "h";
        };
      };
    };
  };

  # Check that `packagesFromDirectoryRecursive` can process a directory with a
  # top-level `package.nix` file into a single package.
  testPackagesFromDirectoryRecursiveTopLevelPackageNix = {
    expr = packagesFromDirectoryRecursive {
      callPackage = path: overrides: import path overrides;
      directory = ./packages-from-directory/plain/c;
    };
    expected = "c";
  };

  testMergeTypesSimple =
    let
      mergedType = types.mergeTypes types.str types.str;
    in
    {
      expr = mergedType.name;
      expected = "str";
    };

  testMergeTypesFail =
    let
      mergedType = types.mergeTypes types.str types.int;
    in
    {
      expr = types.isType "merge-error" mergedType;
      expected = true;
    };

  testMergeTypesEnum =
    let
      enumAB = lib.types.enum [
        "A"
        "B"
      ];
      enumXY = lib.types.enum [
        "X"
        "Y"
      ];
      merged = lib.types.mergeTypes enumAB enumXY; # -> enum [ "A" "B" "X" "Y" ]
    in
    {
      expr = {
        checkA = merged.check "A";
        checkB = merged.check "B";
        checkX = merged.check "X";
        checkY = merged.check "Y";
        checkC = merged.check "C";
      };
      expected = {
        checkA = true;
        checkB = true;
        checkX = true;
        checkY = true;
        checkC = false;
      };
    };

  # Check that `packagesFromDirectoryRecursive` can be used to create scopes
  # for sub-directories
  testPackagesFromDirectoryNestedScopes =
    let
      inherit (lib) makeScope recurseIntoAttrs;
      emptyScope = makeScope lib.callPackageWith (_: { });
    in
    {
      expr =
        lib.filterAttrsRecursive
          (
            name: value:
            !lib.elem name [
              "callPackage"
              "newScope"
              "overrideScope"
              "packages"
            ]
          )
          (packagesFromDirectoryRecursive {
            inherit (emptyScope) callPackage newScope;
            directory = ./packages-from-directory/scope;
          });
      expected = lib.recurseIntoAttrs {
        a = "a";
        b = "b";
        # Note: Other files/directories in `./test-data/c/` are ignored and can be
        # used by `package.nix`.
        c = "c";
        my-namespace = lib.recurseIntoAttrs {
          d = "d";
          e = "e";
          f = "f";
          my-sub-namespace = lib.recurseIntoAttrs {
            g = "g";
            h = "h";
          };
        };
      };
    };

  testFilesystemResolveDefaultNixFile1 = {
    expr = lib.filesystem.resolveDefaultNix ./foo.nix;
    expected = ./foo.nix;
  };

  testFilesystemResolveDefaultNixFile2 = {
    expr = lib.filesystem.resolveDefaultNix ./default.nix;
    expected = ./default.nix;
  };

  testFilesystemResolveDefaultNixDir1 = {
    expr = lib.filesystem.resolveDefaultNix ./.;
    expected = ./default.nix;
  };

  testFilesystemResolveDefaultNixFile1_toString = {
    expr = lib.filesystem.resolveDefaultNix (toString ./foo.nix);
    expected = toString ./foo.nix;
  };

  testFilesystemResolveDefaultNixFile2_toString = {
    expr = lib.filesystem.resolveDefaultNix (toString ./default.nix);
    expected = toString ./default.nix;
  };

  testFilesystemResolveDefaultNixDir1_toString = {
    expr = lib.filesystem.resolveDefaultNix (toString ./.);
    expected = toString ./default.nix;
  };

  testFilesystemResolveDefaultNixDir1_toString2 = {
    expr = lib.filesystem.resolveDefaultNix (toString ./.);
    expected = toString ./. + "/default.nix";
  };

  testFilesystemResolveDefaultNixNonExistent = {
    expr = lib.filesystem.resolveDefaultNix "/non-existent/this/does/not/exist/for/real/please-dont-mess-with-your-local-fs";
    expected = "/non-existent/this/does/not/exist/for/real/please-dont-mess-with-your-local-fs";
  };

  testFilesystemResolveDefaultNixNonExistentDir = {
    expr = lib.filesystem.resolveDefaultNix "/non-existent/this/does/not/exist/for/real/please-dont-mess-with-your-local-fs/";
    expected = "/non-existent/this/does/not/exist/for/real/please-dont-mess-with-your-local-fs/default.nix";
  };

}

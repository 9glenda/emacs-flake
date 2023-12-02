{lib, ...}: {
  magit = _: prev: {
    files =
      prev.files
      // {
        "lisp/Makefile" = "Makefile";
      };
  };

  rustic = _: prev: {
    files = builtins.removeAttrs prev.files [
      # Unused integrations.
      "rustic-flycheck.el"
    ];
  };
}

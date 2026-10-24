# Credo's defaults, plus its security checks that are off by default. High priority,
# so `mix check`'s `--min-priority high` reports them.
%{
  configs: [
    %{
      name: "default",
      checks: %{
        extra: [
          # Tests make atoms on purpose
          {Credo.Check.Warning.UnsafeToAtom, [priority: :high, files: %{excluded: ["test/"]}]},
          {Credo.Check.Warning.UnsafeExec, [priority: :high]},
          {Credo.Check.Warning.LeakyEnvironment, [priority: :high]}
        ]
      }
    }
  ]
}

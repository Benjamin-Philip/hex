defmodule Hex.Mix do
  def deps_to_requests(deps) do
    Enum.flat_map(deps, fn
      %Mix.Dep{scm: Hex.SCM} = dep -> [{ "#{dep.app}", dep.requirement }]
      %Mix.Dep{} -> []
    end)
  end

  def overriden(main) do
    Enum.flat_map(main, fn dep ->
      { app, _req, opts } = dep(dep)
      if opts[:override], do: ["#{app}"], else: []
    end)
  end

  def dep({ app, opts }) when is_list(opts),
    do: { app, nil, opts }
  def dep({ app, req }) when is_binary(req),
    do: { app, req, [] }
  def dep({ app, req, opts }),
    do: { app, req, opts }

  def from_lock(lock) do
    Enum.flat_map(lock, fn
      { name, { :package, version } } ->
        name = "#{name}"
        [{ name, version }]
       _ ->
        []
    end)
  end

  def annotate_deps(result, deps) do
    scms = Mix.SCM.available
    # TODO: from may be wrong for some deps
    from = Path.absname("mix.exs")

    Enum.map(result, fn { app, version } ->
      atom = :"#{app}"
      dep = Enum.find(deps, &(&1.app == atom))
            || Mix.Dep.Loader.to_dep({ atom, package: true }, scms, from)

      %{ dep | opts: dep.opts ++ [lock: { :package, version }] }
    end)
  end

  def read_config do
    case File.read(config_path) do
      { :ok, binary } ->
        { config, _binding } = Code.eval_string(binary)
        config
      { :error, _ } ->
        []
    end
  end

  def update_config(config) do
    path = config_path
    updated_config =
      case File.read(path) do
        { :ok, binary } ->
          quoted = Code.string_to_quoted!(binary, file: path) |> strip_block
          Keyword.merge(quoted, config)
        { :error, _ } ->
          config
      end

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Macro.to_string(updated_config) <> "\n")
  end

  defp config_path do
    Path.join(Mix.Utils.mix_home, "hex.config")
  end

  defp strip_block({ :__block__, _, [inner] }), do: inner
  defp strip_block(inner), do: inner
end

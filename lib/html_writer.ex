defmodule HtmlWriter do
  @moduledoc """
  Provide helper function and macros to write html programatically into a chardata

  all builder function/macro in this module take 2-tuple {s, acc} as the first argument and
  the return value. put more data in it
  as the return value
  """

  @doc ~S"""
  helper macro to bind a value to a name, in order to maintain flow of the pipe operator.
  For example: 

  ```elixir
  v
  |> do_someting()
  |> do_something_else()
  |> bind_to(v)
  ```

  This feel better than doing the assignment 
  """
  defmacro bind_to(value, name) do
    quote do
      unquote(name) = unquote(value)
    end
  end

  @doc ~S"""
  Like bind_to, but ignore nil or false
  For example:

  ```elixir
  v
  |> do_someting()
  |> do_something_else()
  ~> v
  ```

  This feel better than doing the assignment
  """
  defmacro value ~> name do
    quote do
      unquote(name) = unquote(value) || unquote(name)
    end
  end

  @doc ~S"""
  Like ~>, but reverse the order
  For example:

  ```elixir
  v <~ if(condition?, do: do_something(v))
  ```

  which is shorter than:

  ```elixir
  v = if(condition?, do: do_something(v), else: v)
  ```
  """
  defmacro name <~ value do
    quote do
      unquote(name) = unquote(value) || unquote(name)
    end
  end

  @doc ~S"""
  This is Enum.reduce with first 2 arguments switched order.

  For example:
  ```elixir
  h
  |> roll_in(list, fn item, h ->
    h
    |> do_something_with(item)
  end)
  ```

  Using this one can maintian flow of the pipe chain.
  """
  defmacro roll_in(s, enum, function) do
    quote do
      Enum.reduce(unquote(enum), unquote(s), unquote(function))
    end
  end

  @doc ~S"""
  Invoke the func with s. This is used to keep the pipe flowing
  """
  defmacro invoke(s, func) do
    quote do
      unquote(func).(unquote(s))
    end
  end

  @doc ~S"""
  start with no boilerplate
  """
  def new_fragment(acc \\ nil), do: {[], acc}

  @doc ~S"""
  start with minimum boilerplate
  """
  def new_html(acc \\ nil), do: {["<!DOCTYPE html>\n"], acc}

  @doc ~S"""
  Just add some text. Please note no text is escaped
  """
  def text({s, acc}, text), do: {[text | s], acc}

  @doc ~S"""
  export the data.
  Since the data is a list, so all it does for now is Enum.reverse()
  """
  def export({s, _acc}), do: Enum.reverse(s)

  @doc ~S"""
  build a html fragment with a builder function
  """
  def fragment(f), do: {[], nil} |> f.() |> export()

  @doc ~S"""
  build a html fragment with a predefined header string or io_list
  """
  def fragment(header, f) when is_binary(header), do: {[header], nil} |> f.() |> export()
  def fragment(header, f), do: {Enum.reverse(header), nil} |> f.() |> export()

  @doc ~S"""
  escape the string to be HTML safe
  """
  def escape(str) when is_binary(str) do
    IO.iodata_to_binary(to_iodata(str, 0, str, []))
  end

  # following code lifted from Plug.HTML
  escapes = [
    {?<, "&lt;"},
    {?>, "&gt;"},
    {?&, "&amp;"},
    {?", "&quot;"},
    {?', "&#39;"}
  ]

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc) do
      to_iodata(rest, skip + 1, original, [acc | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc) do
    to_iodata(rest, skip, original, acc, 1)
  end

  defp to_iodata(<<>>, _skip, _original, acc) do
    acc
  end

  for {match, insert} <- escapes do
    defp to_iodata(<<unquote(match), rest::bits>>, skip, original, acc, len) do
      part = binary_part(original, skip, len)
      to_iodata(rest, skip + len + 1, original, [acc, part | unquote(insert)])
    end
  end

  defp to_iodata(<<_char, rest::bits>>, skip, original, acc, len) do
    to_iodata(rest, skip, original, acc, len + 1)
  end

  defp to_iodata(<<>>, 0, original, _acc, _len) do
    original
  end

  defp to_iodata(<<>>, skip, original, acc, len) do
    [acc | binary_part(original, skip, len)]
  end

  @doc ~S"""
  build a void-element, which is an element that should not have inner text. It may have attributes
  though. Don't call this unless you are making a custom element; use the element specific funcions
  instead.

  tag is the tag name.
  attr are a keyword list of attrbutes, each value can be a string, an list of strings, or nil

  The first argument and the return are 2-tuple {s, acc}, where s is the chirlist in bilding.
  acc is a custom accumulator that this library does not inteprete, just faithfully pass along
  """
  def tag({s, acc}, tag, attrs \\ []) do
    {["<#{tag}#{attr_string(attrs)}>\n" | s], acc}
  end

  @doc ~S"""
  build a non-void element, which is an element that may have inner text. It may also have
  attributes. Don't call this unless you are making a custom element; use the element specific
  funcions instead.

  tag is the tag name.
  inner can be nil, a string or a function with arity of 1 that build inner text
  attr are a keyword list of attrbutes, each value can be a string, an list of strings, or nil

  The first argument and the return are 2-tuple {s, acc}, where s is the chirlist in bilding.
  acc is a custom accumulator that this library does not inteprete, just faithfully pass along
  """
  def element(s, tag, content, attrs \\ [])

  def element({s, acc}, tag, nil, attrs) do
    {["<#{tag}#{attr_string(attrs)}></#{tag}>\n" | s], acc}
  end

  def element({s, acc}, tag, "", attrs) do
    {["<#{tag}#{attr_string(attrs)}></#{tag}>\n" | s], acc}
  end

  def element({s, acc}, tag, text, attrs) when is_binary(text) do
    start_tag = "<#{tag}#{attr_string(attrs)}>"
    end_tag = "</#{tag}>\n"
    {[end_tag, text, start_tag | s], acc}
  end

  def element({s, acc}, tag, func, attrs) when is_function(func, 1) do
    case func.({[], acc}) do
      {[], acc} ->
        {["<#{tag}#{attr_string(attrs)}></#{tag}>\n" | s], acc}

      {inner, acc} ->
        {["</#{tag}>\n", Enum.reverse(inner), "<#{tag}#{attr_string(attrs)}>\n"] ++ s, acc}
    end
  end

  def element({s, acc}, tag, attrs, func) when is_function(func, 1) do
    case func.({[], acc}) do
      {[], acc} ->
        {["<#{tag}#{attr_string(attrs)}></#{tag}>\n" | s], acc}

      {inner, acc} ->
        {["</#{tag}>\n", Enum.reverse(inner), "<#{tag}#{attr_string(attrs)}>\n"] ++ s, acc}
    end
  end

  defp attr_string(attrs) do
    attrs |> Enum.map(&one_attr_string/1) |> Enum.join()
  end

  defp one_attr_string({key, value}) do
    case value do
      nil -> " #{key}"
      true -> " #{key}"
      false -> ""
      list when is_list(list) -> " #{key}=\"#{Enum.join(list, " ")}\""
      v -> " #{key}=\"#{v}\""
    end
  end

  defp one_attr_string({key}), do: " #{key}"

  [:meta, :link, :hr, :br, :img, :input]
  |> Enum.each(fn k ->
    @doc ~s"""
    build void element #{to_string(k)}
    """
    defmacro unquote(k)(s, attrs \\ []) do
      k = unquote(k)

      quote do
        tag(unquote(s), unquote(k), unquote(attrs))
      end
    end
  end)

  [
    :html,
    :head,
    :body,
    :section,
    :article,
    :title,
    :style,
    :script,
    :h1,
    :h2,
    :h3,
    :h4,
    :h5,
    :h6,
    :p,
    :a,
    :nav,
    :div,
    :span,
    :em,
    :b,
    :i,
    :u,
    :blockquote,
    :del,
    :code,
    :strong,
    :ul,
    :ol,
    :li,
    :table,
    :tbody,
    :thead,
    :tr,
    :th,
    :td,
    :form,
    :select,
    :option,
    :label,
    :textarea,
    :pre,
    :button,
    :template,
    :slot
  ]
  |> Enum.each(fn k ->
    @doc ~s"""
    build non-void element #{to_string(k)}
    """
    defmacro unquote(k)(s, inner, attrs \\ []) do
      k = unquote(k)

      quote do
        element(unquote(s), unquote(k), unquote(inner), unquote(attrs))
      end
    end
  end)
end

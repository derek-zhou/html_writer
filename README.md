# HtmlWriter

A library to write html text in an elixir way.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `html_writer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:html_writer, "~> 0.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/html_writer](https://hexdocs.pm/html_writer).

## Motivation

There are templates, and elixir's eex template is among the nicer ones. However, I still hate templates. It has bastardized syntax that is neither html nor elixir (or any host programming language), feels awkward, and messes up syntax highlight in editors.

There are cleaner looking template like [mustache template](https://mustache.github.io/), however the functionality is too weak. You would need to put significant view related code into the controller layer. 

HtmlWriter is not a template system. It is just a simple elixir library making heavy use of closures and pipe operators so you can write html in a functional way. Here is a simple example:

```elixir
new_fragment()
|> div(fn h ->
   h
   |> h1("My Title")
   |> a("link text", href: "#")
end, class: "my-class")
|> export()
```

Which will print the text as:

```html
<div class="my-class">
  <h1>My Title</h1>
  <a htef="#">Link Text</a>
</div>
```

Yes, it is more verbose, however:

 * it is pure elixir and can be refactored in any way you want 
 * there is no way to write mal-formed html

If you already have the html, just want to change some small parts into dynamic contents, you prabably should stick to templates. If you are printing complex HTML structure that is highly dynamic, you may want to try this.

You could probably do similiar things with Phoenix.HTML but ity is not intended to be used this way and will be very awkward. 

There is also some helper macros that make your code easier to read:

```elixir
new_fragment()
|> ul(fn h ->
	h
	|> roll_in(["a", "b", "c"], fn each, h ->
		h |> li(each)
	end)
end)
|> export()
	
```
Can you guess what it will do?

Please also keep in mind that nothing is escaped by default. You'll have to esacape the problematic
string your self by calling `escape/1`.

## Usage without Phoenix

The library has no dependancy on Phoenix, you can use it in your standalone app to print html files. Just import the library so all html functions came into your scope:

```elixir
  import Kernel, except: [div: 2]
  import HtmlWriter
```

You would need to un-import the `div/2` from kernel to avoid function name collision. then:

```elixir
    f = File.open!("my.html", [:write, :delayed_write, :utf8])

	new_html()
    |> html(fn h ->
      h
      |> head(fn h ->
		  h
		  |> meta(charset: "utf-8")
		  |> title("My title")
		  end)
      |> body(fn h ->
		  h
		  |> print_my_body()
		  end, lang: "en")
	  end)
    |> export()
	|> bind_to(html)

	IO.write(f, html))
    File.close(f)
```

As you can see, everything fit into the flow. Most functions in this library takes a chardata as the first argument and just add to it. I called them builder functions. You are encouraged to write your own builder functions by combining the primitive builder functions in closures.

## Usage with Phoenix

Of course you can also use it in a Phoenix app. I still use templates, but only for layouts. My inner views are all elixir code, without templates. In your view module:

```elixir
  import Kernel, except: [div: 2]
  import HtmlWriter

  defp html_fragment(f), do: f |> fragment() |> Phoenix.HTML.raw()
  
  def render("index.html", %{key: value}) do
    html_fragment(fn h ->
	  ...
    end)
  end
  
```

Just write your own render function clauses with HtmlWriter then you can do away the templates. I also don't use or import `Phoenix.HTML` into my view modules to avoid function name collisions.  The `html_fragment/1` is not provided in the library because I don't want to pull in dependancy for such a simple thing.

It is also possible to completely get rid of `EEX` and `Phoenix.HTML` by implementing your layout modules in `HtmlWriter`. Your layout module can be implemented as something like:

``` elixir
...
  def wrap(assigns, inner) do
	new_html()
	|> html(fn h ->
	  h
	  |> head(&my_head(&1))
	  |> body(fn h ->
		 h
		 |> my_header(assigns)
		 |> div(inner, class: "content", id: "inner-content")
		 |> my_footer(assigns)
	  end)
	end)
	|> export()
  end
```

And your view can be something like:

``` elixir
  def render("index.htm", %{key: value} = assigns) do
    Layout.wrap(assigns, fn h ->
	  ...
    end)
  end
```

By using the `htm` suffix instead of `html` suffix, you bypassed all the layout and HTML escaping from phoenix while still sending the correct `content_type`.

## To contribute

PRs are welcomed. The code is stable, only ~100 LOC, but poorly documented for now. I encourage users to read the code and understand what is it doing. 

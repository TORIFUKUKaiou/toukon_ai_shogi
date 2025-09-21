# ToukonAiShogi

To start your Phoenix server:

* Run `mix setup` to install dependencies and prepare the database (`mix ecto.create && mix ecto.migrate`)
* Export `PHX_SECRET_KEY_BASE` (see `.envrc.example`) so dev config can boot
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Visit [`localhost:4000/users/register`](http://localhost:4000/users/register) to create an account, then head to [`localhost:4000/lobby`](http://localhost:4000/lobby) to queue for multiplayer matches. A sandbox board remains available at [`localhost:4000/board`](http://localhost:4000/board).

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

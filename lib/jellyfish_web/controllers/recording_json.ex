defmodule JellyfishWeb.RecordingJSON do
  @moduledoc false

  def show(%{recordings: recordings}) do
    %{data: recordings}
  end
end

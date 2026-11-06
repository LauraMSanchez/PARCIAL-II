defmodule ExploradorRegiones do
  @moduledoc """
  Algoritmo de exploración Flood Fill para encontrar regiones y calcular métricas.
  """

  def encontrar_todas(matriz_mapa, num_filas, num_cols) do
    {regiones_rev, _visitados, _id} =
      for r <- 0..(num_filas - 1), c <- 0..(num_cols - 1), reduce: {[], MapSet.new(), 1} do
        {reg_acc, visitados_acc, id_actual} ->
          pos = {r, c}
          simbolo = Map.get(matriz_mapa, pos)

          cond do
            simbolo == "." or MapSet.member?(visitados_acc, pos) ->
              {reg_acc, visitados_acc, id_actual}

            true ->
              {celdas_region, nuevos_visitados} =
                flood_fill([pos], simbolo, matriz_mapa, MapSet.new([pos]), visitados_acc)

              region = construir_region(id_actual, simbolo, celdas_region, matriz_mapa, num_filas, num_cols)
              {[region | reg_acc], nuevos_visitados, id_actual + 1}
          end
      end

    Enum.reverse(regiones_rev)
  end

  defp flood_fill([], _simbolo, _matriz, region_acc, visitados_acc) do
    {MapSet.to_list(region_acc), visitados_acc}
  end

  defp flood_fill([pos | frontera], simbolo, matriz, region_acc, visitados_acc) do
    nuevos_visitados = MapSet.put(visitados_acc, pos)
    vecinos = obtener_vecinos_4(pos)

    {frontera_nueva, region_nueva} =
      Enum.reduce(vecinos, {frontera, region_acc}, fn v_pos, {f_acc, r_acc} ->
        if Map.get(matriz, v_pos) == simbolo and not MapSet.member?(r_acc, v_pos) do
          {[v_pos | f_acc], MapSet.put(r_acc, v_pos)}
        else
          {f_acc, r_acc}
        end
      end)

    flood_fill(frontera_nueva, simbolo, matriz, region_nueva, nuevos_visitados)
  end

  defp obtener_vecinos_4({r, c}) do
    [{r - 1, c}, {r + 1, c}, {r, c - 1}, {r, c + 1}]
  end

  defp construir_region(id, simbolo, celdas, matriz, num_filas, num_cols) do
    area = Enum.count(celdas)

    perimetro =
      celdas
      |> Enum.map(fn pos ->
        obtener_vecinos_4(pos)
        |> Enum.count(fn {vr, vc} ->
          cond do
            vr < 0 or vr >= num_filas or vc < 0 or vc >= num_cols -> true
            Map.get(matriz, {vr, vc}) != simbolo -> true
            true -> false
          end
        end)
      end)
      |> Enum.sum()

    filas = Enum.map(celdas, fn {r, _c} -> r end)
    cols = Enum.map(celdas, fn {_r, c} -> c end)

    desde = "{#{Enum.min(filas)},#{Enum.min(cols)}}"
    hasta = "{#{Enum.max(filas)},#{Enum.max(cols)}}"

    %Region{
      id: id,
      simbolo: simbolo,
      celdas: celdas,
      area: area,
      perimetro: perimetro,
      desde: desde,
      hasta: hasta
    }
  end
end

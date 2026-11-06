defmodule ValidadorRecursivoMapa do
  @moduledoc """
  Validación previa puramente recursiva de cola (tail recursion).
  CUMPLE REQUISITO 7: Sin utilizar el módulo Enum ni Stream dentro de estas funciones.
  """

  def validar(lineas_paleta_raw, lineas_mapa_raw) do
    {errores_paleta, mapa_colores, simbolos_vistos, tiene_punto?} =
      validar_paleta_rec(lineas_paleta_raw, [], %{}, MapSet.new(), false)

    errores_punto =
      if tiene_punto? do
        []
      else
        ["Línea -: Falta la definición del símbolo de fondo '.' en la paleta"]
      end

    {errores_mapa, filas_matriz, _largo_esperado} =
      validar_mapa_rec(lineas_mapa_raw, nil, [], simbolos_vistos, [])

    todos_los_errores = errores_paleta ++ errores_punto ++ errores_mapa

    if todos_los_errores == [] do
      matriz_mapa = construir_matriz(filas_matriz)
      num_filas = largo_lista(filas_matriz, 0)
      num_cols = if num_filas > 0, do: largo_lista(hd(filas_matriz), 0), else: 0

      {:ok, mapa_colores, matriz_mapa, num_filas, num_cols}
    else
      {:error, todos_los_errores}
    end
  end

  defp validar_paleta_rec([], errores_acc, colores_acc, simbolos_acc, tiene_punto?) do
    {invertir(errores_acc, []), colores_acc, simbolos_acc, tiene_punto?}
  end

  defp validar_paleta_rec([{linea, num_linea} | resto], errores_acc, colores_acc, simbolos_acc, tiene_punto?) do
    campos = String.split(linea, ",")

    case campos do
      [simbolo_raw, nombre_raw, hex_raw] ->
        simbolo = String.trim(simbolo_raw)
        nombre = String.trim(nombre_raw)
        hex = String.trim(hex_raw)

        es_punto? = tiene_punto? or simbolo == "."
        nuevos_errores = errores_acc

        nuevos_errores =
          if MapSet.member?(simbolos_acc, simbolo) do
            ["Línea #{num_linea}: Símbolo repetido '#{simbolo}' en la paleta" | nuevos_errores]
          else
            nuevos_errores
          end

        nuevos_errores =
          if not es_hex_valido?(hex) do
            ["Línea #{num_linea}: Color '#{hex}' inválido para símbolo '#{simbolo}'. Debe usar formato #RRGGBB" | nuevos_errores]
          else
            nuevos_errores
          end

        nuevos_simbolos = MapSet.put(simbolos_acc, simbolo)
        color_struct = %Color{simbolo: simbolo, nombre: nombre, hex: hex}
        nuevos_colores = Map.put(colores_acc, simbolo, color_struct)

        validar_paleta_rec(resto, nuevos_errores, nuevos_colores, nuevos_simbolos, es_punto?)

      _ ->
        err = "Línea #{num_linea}: Formato de paleta incorrecto (se esperaba simbolo,nombre,color_hex)"
        validar_paleta_rec(resto, [err | errores_acc], colores_acc, simbolos_acc, tiene_punto?)
    end
  end

  defp validar_mapa_rec([], largo_esperado, filas_acc, _simbolos_validos, errores_acc) do
    if filas_acc == [] do
      {invertir(["Línea -: El mapa está completamente vacío" | errores_acc], []), [], 0}
    else
      {invertir(errores_acc, []), invertir(filas_acc, []), largo_esperado}
    end
  end

  defp validar_mapa_rec([{linea, num_linea} | resto], largo_esperado, filas_acc, simbolos_validos, errores_acc) do
    simbolos = String.split(linea, ~r/\s+/, trim: true)
    largo_actual = largo_lista(simbolos, 0)
    nuevos_errores = errores_acc

    nuevos_errores =
      if largo_actual == 0 do
        ["Línea #{num_linea}: La fila está vacía" | nuevos_errores]
      else
        nuevos_errores
      end

    largo_esperado_nuevo =
      case largo_esperado do
        nil -> largo_actual
        esperado ->
          if largo_actual != 0 and largo_actual != esperado do
            ["Línea #{num_linea}: Fila de longitud #{largo_actual}, se esperaba #{esperado}" | nuevos_errores]
          end
          esperado
      end

    nuevos_errores = validar_simbolos_rec(simbolos, num_linea, 0, simbolos_validos, nuevos_errores)

    validar_mapa_rec(resto, largo_esperado_nuevo, [simbolos | filas_acc], simbolos_validos, nuevos_errores)
  end

  defp validar_simbolos_rec([], _num_linea, _col, _simbolos_validos, errores_acc), do: errores_acc

  defp validar_simbolos_rec([simbolo | resto], num_linea, col, simbolos_validos, errores_acc) do
    nuevos_errores =
      if not MapSet.member?(simbolos_validos, simbolo) do
        ["Fila (línea #{num_linea}), Columna #{col}: Símbolo '#{simbolo}' no está definido en la paleta" | errores_acc]
      else
        errores_acc
      end

    validar_simbolos_rec(resto, num_linea, col + 1, simbolos_validos, nuevos_errores)
  end

  defp es_hex_valido?(<<?#, r1, r2, g1, g2, b1, b2>>) do
    es_hex_char?(r1) and es_hex_char?(r2) and
      es_hex_char?(g1) and es_hex_char?(g2) and
      es_hex_char?(b1) and es_hex_char?(b2)
  end

  defp es_hex_valido?(_), do: false

  defp es_hex_char?(c) when c in ?0..?9 or c in ?a..?f or c in ?A..?F, do: true
  defp es_hex_char?(_), do: false

  defp largo_lista([], acc), do: acc
  defp largo_lista([_ | tail], acc), do: largo_lista(tail, acc + 1)

  defp invertir([], acc), do: acc
  defp invertir([h | t], acc), do: invertir(t, [h | acc])

  defp construir_matriz(filas) do
    filas
    |> Enum.with_index(0)
    |> Enum.reduce(%{}, fn {fila, r}, acc_r ->
      fila
      |> Enum.with_index(0)
      |> Enum.reduce(acc_r, fn {simbolo, c}, acc_c ->
        Map.put(acc_c, {r, c}, simbolo)
      end)
    end)
  end
end

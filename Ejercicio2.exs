# Integrantes: Laura Sanchez, Jeison Lopez
# Universidad del Quindío - Programación III - Parcial 2

defmodule Color do
  @moduledoc """
  Estructura para almacenar los colores definidos en la paleta.
  """
  defstruct [:simbolo, :nombre, :hex]
end

defmodule Region do
  @moduledoc """
  Estructura para almacenar las propiedades de cada región detectada.
  """
  defstruct [:id, :simbolo, :celdas, :area, :perimetro, :desde, :hasta]
end

defmodule ValidadorRecursivoMapa do
  @moduledoc """
  Validación previa puramente recursiva de cola (tail recursion).
  CUMPLE REQUISITO 7: Sin utilizar el módulo Enum ni Stream dentro de estas funciones.
  """

  @doc """
  Valida la paleta de colores y el mapa de símbolos.
  Retorna {:ok, mapa_colores, matriz_mapa, filas, cols} o {:error, lista_errores}.
  """
  def validar(lineas_paleta_raw, lineas_mapa_raw) do
    # 1. Validar paleta recursivamente
    {errores_paleta, mapa_colores, simbolos_vistos, tiene_punto?} =
      validar_paleta_rec(lineas_paleta_raw, [], %{}, MapSet.new(), false)

    errores_punto =
      if tiene_punto? do
        []
      else
        ["Línea -: Falta la definición del símbolo de fondo '.' en la paleta"]
      end

    # 2. Validar mapa recursivamente
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

  # --- Validación de Paleta (Recursión pura) ---
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

        # Validar duplicados
        nuevos_errores =
          if MapSet.member?(simbolos_acc, simbolo) do
            ["Línea #{num_linea}: Símbolo repetido '#{simbolo}' en la paleta" | nuevos_errores]
          else
            nuevos_errores
          end

        # Validar formato hex #RRGGBB
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

  # --- Validación de Mapa (Recursión pura) ---
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

    # Validar fila vacía
    nuevos_errores =
      if largo_actual == 0 do
        ["Línea #{num_linea}: La fila está vacía" | nuevos_errores]
      else
        nuevos_errores
      end

    # Validar longitud uniforme
    largo_esperado_nuevo =
      case largo_esperado do
        nil -> largo_actual
        esperado ->
          if largo_actual != 0 and largo_actual != esperado do
            ["Línea #{num_linea}: Fila de longitud #{largo_actual}, se esperaba #{esperado}" | nuevos_errores]
          end
          esperado
      end

    # Validar que los símbolos existan en la paleta
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

  # Auxiliares puramente recursivos (sin Enum/Stream)
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

defmodule ExploradorRegiones do
  @moduledoc """
  Algoritmo de exploración Flood Fill para encontrar regiones y calcular métricas.
  """

  @doc """
  Recorre el mapa buscando regiones no visitadas para símbolos distintos de '.' (fondo).
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
              # Inundación recursiva (Flood Fill) en 4 direcciones
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

    # Cálculo del perímetro: bordes del mapa o vecinos de diferente símbolo
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

    # Caja envolvente {fila_min, col_min} a {fila_max, col_max}
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

defmodule GeneradorSVG do
  @moduledoc """
  Genera el archivo SVG por fragmentos mediante Streams sin cargar el documento completo en memoria.
  """
  @tam_celda 40

  def guardar(matriz_mapa, regiones, colores_mapa, num_filas, num_cols, ruta_salida) do
    ancho = num_cols * @tam_celda
    alto = num_filas * @tam_celda

    mapa_celda_a_id =
      regiones
      |> Enum.reduce(%{}, fn reg, acc ->
        Enum.reduce(reg.celdas, acc, fn pos, inner_acc ->
          Map.put(inner_acc, pos, reg.id)
        end)
      end)

    # Encabezado como lista de 1 elemento (enumerable)
    header = ["""
    <svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}">
    """]

    # Cuerpo generado como lista de elementos rect/text
    body =
      for r <- 0..(num_filas - 1), c <- 0..(num_cols - 1) do
        pos = {r, c}
        simbolo = Map.get(matriz_mapa, pos)
        color = Map.get(colores_mapa, simbolo)
        hex = if color, do: color.hex, else: "#FFFFFF"
        id_region = Map.get(mapa_celda_a_id, pos)

        x = c * @tam_celda
        y = r * @tam_celda

        rect_tag =
          ~s(  <rect x="#{x}" y="#{y}" width="#{@tam_celda}" height="#{@tam_celda}" fill="#{hex}" stroke="#000000" stroke-width="1"/>)

        text_tag =
          if id_region do
            tx = x + 20
            ty = y + 25
            ~s(\n  <text x="#{tx}" y="#{ty}" font-size="16" text-anchor="middle" fill="#000000" font-weight="bold">#{id_region}</text>)
          else
            ""
          end

        rect_tag <> text_tag <> "\n"
      end

    # Cierre como lista de 1 elemento
    footer = ["</svg>\n"]

    # Transmisión por flujo hacia el archivo SVG
    Stream.concat([header, body, footer])
    |> Enum.into(File.stream!(ruta_salida, [:write]))
  end
end

defmodule ProcesadorMapa do
  @moduledoc """
  Orquestador principal para el Ejercicio 2.
  """

  def ejecutar(ruta_mapa \\ "mapa.txt", ruta_paleta \\ "paleta.csv") do
    # Requisito 1 & 6: Control de existencia de archivos
    cond do
      not File.exists?(ruta_mapa) ->
        IO.puts(:stderr, "Error: El archivo de mapa '#{ruta_mapa}' no existe.")

      not File.exists?(ruta_paleta) ->
        IO.puts(:stderr, "Error: El archivo de paleta '#{ruta_paleta}' no existe.")

      true ->
        procesar(ruta_mapa, ruta_paleta)
    end
  end

  defp procesar(ruta_mapa, ruta_paleta) do
    # Lectura en flujo y preservación del número de línea física original
    lineas_paleta =
      File.stream!(ruta_paleta)
      |> Stream.with_index(1)
      |> Stream.filter(fn {l, _n} ->
        l_clean = String.trim(l)
        l_clean != "" and not String.starts_with?(l_clean, "#")
      end)
      |> Enum.to_list()

    lineas_mapa =
      File.stream!(ruta_mapa)
      |> Stream.with_index(1)
      |> Stream.filter(fn {l, _n} ->
        l_clean = String.trim(l)
        l_clean != "" and not String.starts_with?(l_clean, "#")
      end)
      |> Enum.to_list()

    # Requisito 7: Validación previa recursiva pura
    case ValidadorRecursivoMapa.validar(lineas_paleta, lineas_mapa) do
      {:error, errores} ->
        IO.puts(:stderr, "Se encontraron #{Enum.count(errores)} error(es) en el mapa o paleta.")
        IO.puts(:stderr, "Reportando errores en 'validacion_mapa.txt' y deteniendo el procesamiento.\n")

        # Guardar en flujo en validacion_mapa.txt
        errores
        |> Stream.map(&(&1 <> "\n"))
        |> Stream.into(File.stream!("validacion_mapa.txt", [:write]))
        |> Stream.run()

      {:ok, colores_mapa, matriz_mapa, num_filas, num_cols} ->
        # Limpiar archivo de validación si todo estuvo OK
        File.write!("validacion_mapa.txt", "OK: Sin errores de validación.\n")

        # Exploración de regiones por inundación recursiva
        regiones = ExploradorRegiones.encontrar_todas(matriz_mapa, num_filas, num_cols)
        total_regiones = Enum.count(regiones)

        # Cálculo de máximos conservando empates
        max_area = if total_regiones > 0, do: Enum.max_by(regiones, & &1.area).area, else: 0
        max_perimetro = if total_regiones > 0, do: Enum.max_by(regiones, & &1.perimetro).perimetro, else: 0

        regiones_max_area = Enum.filter(regiones, &(&1.area == max_area))
        regiones_max_perimetro = Enum.filter(regiones, &(&1.perimetro == max_perimetro))

        # Escribir regiones.csv
        lineas_csv =
          ["id;simbolo;area;perimetro;desde;hasta"] ++
            Enum.map(regiones, fn r ->
              "#{r.id};#{r.simbolo};#{r.area};#{r.perimetro};#{r.desde};#{r.hasta}"
            end)

        lineas_csv
        |> Stream.map(&(&1 <> "\n"))
        |> Stream.into(File.stream!("regiones.csv", [:write]))
        |> Stream.run()

        # Escribir SVG por fragmentos
        GeneradorSVG.guardar(matriz_mapa, regiones, colores_mapa, num_filas, num_cols, "mapa_regiones.svg")

        # Escribir resumen_regiones.txt
        texto_resumen = """
        === Resumen de Regiones ===
        Total de regiones encontradas: #{total_regiones}

        --- Región(es) de mayor área (Área = #{max_area}) ---
        #{Enum.map_join(regiones_max_area, "\n", &"ID #{&1.id} (#{&1.simbolo}): desde #{&1.desde} hasta #{&1.hasta}")}

        --- Región(es) de mayor perímetro (Perímetro = #{max_perimetro}) ---
        #{Enum.map_join(regiones_max_perimetro, "\n", &"ID #{&1.id} (#{&1.simbolo}): desde #{&1.desde} hasta #{&1.hasta}")}
        """

        File.write!("resumen_regiones.txt", texto_resumen)

        # Requisito 5: Mostrar en pantalla el resumen
        IO.puts("=== Procesamiento Exitoso de Mapa y SVG ===")
        IO.puts("Total de regiones: #{total_regiones}")
        IO.puts("Mayor área (#{max_area}): IDs -> #{Enum.map_join(regiones_max_area, ", ", & &1.id)}")
        IO.puts("Mayor perímetro (#{max_perimetro}): IDs -> #{Enum.map_join(regiones_max_perimetro, ", ", & &1.id)}")
        IO.puts("\nArchivos generados: regiones.csv, mapa_regiones.svg, resumen_regiones.txt")
    end
  end
end

# Ejecutar el script
ProcesadorMapa.ejecutar("mapa.txt", "paleta.csv")

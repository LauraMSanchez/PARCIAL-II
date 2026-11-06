# Integrantes: Laura Sanchez, Jeison Lopez
# Universidad del Quindío - Programación III - Parcial 2 (Ejercicio 2)


Code.require_file("estructuras_mapa.exs")
Code.require_file("validador_mapa.exs")
Code.require_file("explorador_regiones.exs")
Code.require_file("generador_svg.exs")

defmodule ProcesadorMapa do
  @moduledoc """
  Orquestador principal para el Ejercicio 2.
  """

  def ejecutar(ruta_mapa \\ "mapa.txt", ruta_paleta \\ "paleta.csv") do
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

    case ValidadorRecursivoMapa.validar(lineas_paleta, lineas_mapa) do
      {:error, errores} ->
        IO.puts(:stderr, "Se encontraron #{Enum.count(errores)} error(es) en el mapa o paleta.")
        IO.puts(:stderr, "Reportando errores en 'validacion_mapa.txt' y deteniendo el procesamiento.\n")

        errores
        |> Stream.map(&(&1 <> "\n"))
        |> Stream.into(File.stream!("validacion_mapa.txt", [:write]))
        |> Stream.run()

      {:ok, colores_mapa, matriz_mapa, num_filas, num_cols} ->
        File.write!("validacion_mapa.txt", "OK: Sin errores de validación.\n")

        regiones = ExploradorRegiones.encontrar_todas(matriz_mapa, num_filas, num_cols)
        total_regiones = Enum.count(regiones)

        max_area = if total_regiones > 0, do: Enum.max_by(regiones, & &1.area).area, else: 0
        max_perimetro = if total_regiones > 0, do: Enum.max_by(regiones, & &1.perimetro).perimetro, else: 0

        regiones_max_area = Enum.filter(regiones, &(&1.area == max_area))
        regiones_max_perimetro = Enum.filter(regiones, &(&1.perimetro == max_perimetro))

        lineas_csv =
          ["id;simbolo;area;perimetro;desde;hasta"] ++
            Enum.map(regiones, fn r ->
              "#{r.id};#{r.simbolo};#{r.area};#{r.perimetro};#{r.desde};#{r.hasta}"
            end)

        lineas_csv
        |> Stream.map(&(&1 <> "\n"))
        |> Stream.into(File.stream!("regiones.csv", [:write]))
        |> Stream.run()

        GeneradorSVG.guardar(matriz_mapa, regiones, colores_mapa, num_filas, num_cols, "mapa_regiones.svg")

        texto_resumen = """
        === Resumen de Regiones ===
        Total de regiones encontradas: #{total_regiones}

        --- Región(es) de mayor área (Área = #{max_area}) ---
        #{Enum.map_join(regiones_max_area, "\n", &"ID #{&1.id} (#{&1.simbolo}): desde #{&1.desde} hasta #{&1.hasta}")}

        --- Región(es) de mayor perímetro (Perímetro = #{max_perimetro}) ---
        #{Enum.map_join(regiones_max_perimetro, "\n", &"ID #{&1.id} (#{&1.simbolo}): desde #{&1.desde} hasta #{&1.hasta}")}
        """

        File.write!("resumen_regiones.txt", texto_resumen)

        IO.puts("=== Procesamiento Exitoso de Mapa y SVG ===")
        IO.puts("Total de regiones: #{total_regiones}")
        IO.puts("Mayor área (#{max_area}): IDs -> #{Enum.map_join(regiones_max_area, ", ", & &1.id)}")
        IO.puts("Mayor perímetro (#{max_perimetro}): IDs -> #{Enum.map_join(regiones_max_perimetro, ", ", & &1.id)}")
        IO.puts("\nArchivos generados: regiones.csv, mapa_regiones.svg, resumen_regiones.txt")
    end
  end
end

# Ejecución principal del script
ProcesadorMapa.ejecutar("mapa.txt", "paleta.csv")

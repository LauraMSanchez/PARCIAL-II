# Integrantes: Laura Sanchez, Jeison Lopez
# Universidad del Quindío - Programación III - Parcial 2

defmodule Tramo do
  @moduledoc """
  Estructura que representa un tramo dirigido entre dos centros de distribución.
  """
  defstruct [:origen, :destino, :minutos, :costo]

  @type t :: %__MODULE__{
          origen: String.t(),
          destino: String.t(),
          minutos: pos_integer(),
          costo: pos_integer()
        }

  @doc """
  Parsea una línea CSV a la estructura %Tramo{}.
  Retorna {:ok, %Tramo{}} o {:error, motivo}.
  """
  def parse(linea) when is_binary(linea) do
    linea
    |> String.trim()
    |> String.split(",")
    |> case do
      [origen, destino, minutos_str, costo_str] ->
        origen = String.trim(origen)
        destino = String.trim(destino)

        case {Integer.parse(String.trim(minutos_str)), Integer.parse(String.trim(costo_str))} do
          {{minutos, ""}, {costo, ""}} when minutos > 0 and costo > 0 and origen != "" and destino != "" ->
            {:ok, %Tramo{origen: origen, destino: destino, minutos: minutos, costo: costo}}

          _ ->
            {:error, "Valores de minutos o costo deben ser enteros positivos y los centros no vacíos"}
        end

      _ ->
        {:error, "Formato de línea incorrecto (se esperaban 4 campos separados por coma)"}
    end
  end
end

defmodule Itinerario do
  @moduledoc """
  Estructura que representa un itinerario de transporte entre un centro inicial y final.
  """
  defstruct [:centros, :minutos, :costo, :num_tramos]

  def nuevo(centros, minutos, costo) do
    %__MODULE__{
      centros: centros,
      minutos: minutos,
      costo: costo,
      num_tramos: Enum.count(centros) - 1
    }
  end

  def a_string(%__MODULE__{centros: centros, minutos: min, costo: c, num_tramos: t}, indice) do
    secuencia = Enum.join(centros, " -> ")
    "Itinerario #{indice}: #{secuencia} | tramos: #{t} | #{min} min | costo: #{c}"
  end
end

defmodule ValidadorRecursivo do
  @moduledoc """
  Módulo de validación previa utilizando recursión de cola pura.
  CUMPLE REQUISITO 7: Sin utilizar el módulo Enum ni Stream.
  """

  @doc """
  Depura la lista de tramos válidos.
  Descarta:
  1. Tramos cuyo origen y destino sean iguales (ej: A,A).
  2. Repeticiones de la pareja (origen, destino) en la misma dirección (conserva la primera).
  Retorna {tramos_depurados, lista_descartes}.
  """
  def depurar_tramos(tramos_con_meta) do
    depurar_rec(tramos_con_meta, MapSet.new(), [], [])
  end

  defp depurar_rec([], _parejas_vistas, validos_acc, descartes_acc) do
    {invertir_lista(validos_acc, []), invertir_lista(descartes_acc, [])}
  end

  defp depurar_rec([{tramo, num_linea, linea_raw} | resto], parejas_vistas, validos_acc, descartes_acc) do
    pareja = {tramo.origen, tramo.destino}

    cond do
      # 1. Descarte: Origen y destino iguales
      tramo.origen == tramo.destino ->
        motivo = "Línea #{num_linea}: '#{linea_raw}' -> Descartado: origen y destino son el mismo centro (#{tramo.origen})"
        depurar_rec(resto, parejas_vistas, validos_acc, [motivo | descartes_acc])

      # 2. Descarte: Repetición de la pareja en la misma dirección
      MapSet.member?(parejas_vistas, pareja) ->
        motivo = "Línea #{num_linea}: '#{linea_raw}' -> Descartado: tramo duplicado en la misma dirección (#{tramo.origen} -> #{tramo.destino})"
        depurar_rec(resto, parejas_vistas, validos_acc, [motivo | descartes_acc])

      true ->
        nuevas_parejas = MapSet.put(parejas_vistas, pareja)
        depurar_rec(resto, nuevas_parejas, [{tramo, num_linea, linea_raw} | validos_acc], descartes_acc)
    end
  end

  # Función recursiva de cola auxiliar para invertir listas sin usar Enum.reverse
  defp invertir_lista([], acc), do: acc
  defp invertir_lista([cabeza | cola], acc), do: invertir_lista(cola, [cabeza | acc])
end

defmodule AlcanceCentros do
  @moduledoc """
  Módulo para calcular la secuencia de conjuntos de centros alcanzables mediante un Stream infinito.
  """

  @doc """
  Construye un Stream infinito de conjuntos alcanzables comenzando en `origen`.
  Consume los pasos hasta detectar el primer estado repetido consecutivo.
  """
  def calcular_alcance(origen, destino, grafo) do
    stream_infinito =
      Stream.iterate(MapSet.new([origen]), fn conjunto_actual ->
        nuevos_destinos =
          conjunto_actual
          |> Enum.flat_map(fn centro ->
            tramos_salida = Map.get(grafo, centro, [])
            Enum.map(tramos_salida, & &1.destino)
          end)
          |> MapSet.new()

        MapSet.union(conjunto_actual, nuevos_destinos)
      end)

    {secuencia_pasos, estado_final} = encontrar_estabilizacion(stream_infinito)
    alcanzable = MapSet.member?(estado_final, destino)

    {secuencia_pasos, alcanzable}
  end

  defp encontrar_estabilizacion(stream) do
    stream
    |> Stream.with_index(0)
    |> Enum.reduce_while(nil, fn {estado_actual, paso}, estado_previo ->
      case estado_previo do
        nil ->
          {:cont, {[{:paso, paso, estado_actual}], estado_actual}}

        {pasos_acc, ultimo_estado} ->
          if estado_actual == ultimo_estado do
            # Detiene la evaluación perezosa al detectar convergencia
            {:halt, {pasos_acc ++ [{:estabilizado, paso, estado_actual}], estado_actual}}
          else
            {:cont, {pasos_acc ++ [{:paso, paso, estado_actual}], estado_actual}}
          end
      end
    end)
  end
end

defmodule BuscadorRutas do
  @moduledoc """
  Búsqueda exhaustiva recursiva de itinerarios simples (sin repetir centros en un mismo recorrido).
  """

  def encontrar_itinerarios(origen, destino, grafo) do
    buscar_rec(origen, destino, grafo, [origen], MapSet.new([origen]), 0, 0, [])
    |> Enum.reverse()
  end

  defp buscar_rec(actual, destino, _grafo, camino_acc, _visitados, min_acc, costo_acc, res_acc)
       when actual == destino do
    itinerario = Itinerario.nuevo(Enum.reverse(camino_acc), min_acc, costo_acc)
    [itinerario | res_acc]
  end

  defp buscar_rec(actual, destino, grafo, camino_acc, visitados, min_acc, costo_acc, res_acc) do
    tramos_salida = Map.get(grafo, actual, [])

    Enum.reduce(tramos_salida, res_acc, fn tramo, acc ->
      if MapSet.member?(visitados, tramo.destino) do
        acc
      else
        nuevos_visitados = MapSet.put(visitados, tramo.destino)
        nuevos_camino = [tramo.destino | camino_acc]

        buscar_rec(
          tramo.destino,
          destino,
          grafo,
          nuevos_camino,
          nuevos_visitados,
          min_acc + tramo.minutos,
          costo_acc + tramo.costo,
          acc
        )
      end
    end)
  end

  @doc """
  Calcula las soluciones óptimas conservando todos los empates para:
  (a) menos tramos, (b) menor tiempo y (c) menor costo.
  """
  def calcular_optimos([]) do
    %{menos_tramos: [], menor_tiempo: [], menor_costo: []}
  end

  def calcular_optimos(itinerarios) do
    indexed = Enum.with_index(itinerarios, 1)

    # CORRECCIÓN: Se obtiene el valor mínimo directamente de los structs
    min_tramos = Enum.min_by(itinerarios, & &1.num_tramos).num_tramos
    min_tiempo = Enum.min_by(itinerarios, & &1.minutos).minutos
    min_costo = Enum.min_by(itinerarios, & &1.costo).costo

    optimos_tramos =
      indexed
      |> Enum.filter(fn {it, _idx} -> it.num_tramos == min_tramos end)
      |> Enum.map(fn {_it, idx} -> idx end)

    optimos_tiempo =
      indexed
      |> Enum.filter(fn {it, _idx} -> it.minutos == min_tiempo end)
      |> Enum.map(fn {_it, idx} -> idx end)

    optimos_costo =
      indexed
      |> Enum.filter(fn {it, _idx} -> it.costo == min_costo end)
      |> Enum.map(fn {_it, idx} -> idx end)

    %{
      menos_tramos: optimos_tramos,
      menor_tiempo: optimos_tiempo,
      menor_costo: optimos_costo
    }
  end
end

defmodule ProcesadorRed do
  @moduledoc """
  Orquestador del flujo principal. Cumple con la lectura/escritura por flujos y el manejo de errores.
  """

  def ejecutar(ruta_tramos \\ "tramos.csv", ruta_consultas \\ "consultas.txt") do
    # Requisito 1 & 6: Control de existencia de archivos
    cond do
      not File.exists?(ruta_tramos) ->
        IO.puts(:stderr, "Error: El archivo de tramos '#{ruta_tramos}' no existe.")

      not File.exists?(ruta_consultas) ->
        IO.puts(:stderr, "Error: El archivo de consultas '#{ruta_consultas}' no existe.")

      true ->
        procesar_red(ruta_tramos, ruta_consultas)
    end
  end

  defp procesar_red(ruta_tramos, ruta_consultas) do
    # Requisito 1, 2, 3: Lectura por flujo, transformaciones perezosas y número de línea física
    lineas_stream =
      File.stream!(ruta_tramos)
      |> Stream.with_index(1)
      |> Stream.filter(fn {linea, _num} ->
        l = String.trim(linea)
        l != "" and not String.starts_with?(l, "#")
      end)
      |> Stream.map(fn {linea, num} -> {String.trim(linea), num} end)

    # Requisito 6: Parseo y registro de errores de entrada
    {parseados_ok, errores_formato} =
      Enum.reduce(lineas_stream, {[], []}, fn {linea_raw, num_linea}, {ok_acc, err_acc} ->
        case Tramo.parse(linea_raw) do
          {:ok, tramo} ->
            {[{tramo, num_linea, linea_raw} | ok_acc], err_acc}

          {:error, motivo} ->
            msg = "Línea #{num_linea}: #{motivo} | Contenido: '#{linea_raw}'\n"
            {ok_acc, [msg | err_acc]}
        end
      end)

    # Requisito 4: Escritura en flujo de errores_tramos.txt
    errores_formato
    |> Enum.reverse()
    |> Stream.into(File.stream!("errores_tramos.txt", [:write]))
    |> Stream.run()

    # Requisito 7: Depuración recursiva pura
    tramos_ordenados = Enum.reverse(parseados_ok)
    {tramos_validos_meta, descartes_depuracion} = ValidadorRecursivo.depurar_tramos(tramos_ordenados)

    # Requisito 4: Escritura en flujo de depuracion_tramos.txt
    descartes_depuracion
    |> Stream.map(&(&1 <> "\n"))
    |> Stream.into(File.stream!("depuracion_tramos.txt", [:write]))
    |> Stream.run()

    # Construcción del grafo de distribución
    tramos_validos = Enum.map(tramos_validos_meta, fn {t, _num, _raw} -> t end)

    grafo =
      Enum.reduce(tramos_validos, %{}, fn tramo, acc ->
        Map.update(acc, tramo.origen, [tramo], fn existentes -> [tramo | existentes] end)
      end)

    centros_existentes =
      tramos_validos
      |> Enum.flat_map(fn t -> [t.origen, t.destino] end)
      |> MapSet.new()

    file_alcance = File.stream!("alcance_centros.txt", [:write])
    file_itinerarios = File.stream!("itinerarios.txt", [:write])

    # Requisito 1 & 2: Lectura en flujo del archivo de consultas
    consultas_stream =
      File.stream!(ruta_consultas)
      |> Stream.with_index(1)
      |> Stream.filter(fn {linea, _num} ->
        l = String.trim(linea)
        l != "" and not String.starts_with?(l, "#")
      end)
      |> Stream.map(fn {linea, num} -> {String.trim(linea), num} end)

    # Procesamiento por consulta
    Enum.each(consultas_stream, fn {linea_consulta, num_c} ->
      case String.split(linea_consulta, ",") do
        [origen, destino] ->
          origen = String.trim(origen)
          destino = String.trim(destino)

          procesar_consulta(origen, destino, num_c, grafo, centros_existentes, file_alcance, file_itinerarios)

        _ ->
          IO.puts("Consulta inválida en línea #{num_c}: '#{linea_consulta}'")
      end
    end)
  end

  defp procesar_consulta(origen, destino, _num_c, grafo, centros_existentes, file_alcance, file_itinerarios) do
    header_pantalla = "=== #{origen} -> #{destino} ==="

    # Requisito 6: Comprobación de existencia de centros
    cond do
      not MapSet.member?(centros_existentes, origen) ->
        msg_err = "El centro de origen '#{origen}' no existe en la red. Búsqueda no iniciada.\n"
        IO.puts("#{header_pantalla}\n#{msg_err}")
        escribir_fragmento(file_itinerarios, "#{header_pantalla}\n#{msg_err}\n")

      not MapSet.member?(centros_existentes, destino) ->
        msg_err = "El centro de destino '#{destino}' no existe en la red. Búsqueda no iniciada.\n"
        IO.puts("#{header_pantalla}\n#{msg_err}")
        escribir_fragmento(file_itinerarios, "#{header_pantalla}\n#{msg_err}\n")

      true ->
        # Cálculo del Stream infinito de alcance
        {secuencia_pasos, alcanzable?} = AlcanceCentros.calcular_alcance(origen, destino, grafo)

        # Salida por flujo hacia alcance_centros.txt
        texto_alcance = formato_alcance(origen, destino, secuencia_pasos, alcanzable?)
        escribir_fragmento(file_alcance, texto_alcance)

        if not alcanzable? do
          msg_sin = "sin itinerarios (el centro '#{destino}' no es alcanzable desde '#{origen}').\n"
          IO.puts("#{header_pantalla}\n#{msg_sin}")
          escribir_fragmento(file_itinerarios, "#{header_pantalla}\n#{msg_sin}\n")
        else
          # Búsqueda de itinerarios simples
          itinerarios = BuscadorRutas.encontrar_itinerarios(origen, destino, grafo)
          total = Enum.count(itinerarios)
          optimos = BuscadorRutas.calcular_optimos(itinerarios)

          # Requisito 5: Salida a consola y archivo
          lineas_itinerarios =
            itinerarios
            |> Enum.with_index(1)
            |> Enum.map(fn {it, idx} -> Itinerario.a_string(it, idx) end)

          linea_total = "Total: #{total} itinerarios"
          linea_tramos = "Menos tramos: #{Enum.join(optimos.menos_tramos, ", ")}"
          linea_tiempo = "Menor tiempo: #{Enum.join(optimos.menor_tiempo, ", ")}"
          linea_costo = "Menor costo: #{Enum.join(optimos.menor_costo, ", ")}"

          bloque_salida =
            ([header_pantalla] ++
               lineas_itinerarios ++
               [linea_total, linea_tramos, linea_tiempo, linea_costo, ""])
            |> Enum.join("\n")

          # Imprimir a pantalla
          IO.puts(header_pantalla)
          IO.puts(Enum.join(lineas_itinerarios, "\n"))
          IO.puts(linea_total)
          IO.puts(linea_tramos)
          IO.puts(linea_tiempo)
          IO.puts(linea_costo)
          IO.puts("")

          # Escribir en flujo a itinerarios.txt
          escribir_fragmento(file_itinerarios, bloque_salida <> "\n")
        end
    end
  end

  defp formato_alcance(origen, destino, secuencia_pasos, alcanzable?) do
    encabezado = "=== Consulta: #{origen} -> #{destino} ===\n"

    pasos_str =
      secuencia_pasos
      |> Enum.map(fn
        {:paso, paso, set} ->
          centros = set |> MapSet.to_list() |> Enum.sort() |> Enum.join(", ")
          "Paso #{paso}: {#{centros}}"

        {:estabilizado, paso, set} ->
          centros = set |> MapSet.to_list() |> Enum.sort() |> Enum.join(", ")
          "Secuencia alcanzable estabilizada en el paso #{paso} con #{MapSet.size(set)} centros: {#{centros}}"
      end)
      |> Enum.join("\n")

    resultado_str =
      if alcanzable? do
        "Resultado: El centro destino '#{destino}' es ALCANZABLE."
      else
        "Resultado: El centro destino '#{destino}' NO es alcanzable («sin itinerarios»)."
      end

    encabezado <> pasos_str <> "\n" <> resultado_str <> "\n\n"
  end

  defp escribir_fragmento(file_stream, contenido) do
    [contenido]
    |> Stream.into(file_stream)
    |> Stream.run()
  end
end

# Ejecutar el programa principal
ProcesadorRed.ejecutar("tramos.csv", "consultas.txt")

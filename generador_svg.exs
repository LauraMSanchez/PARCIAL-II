# Integrantes: Laura Sanchez, Jeison Lopez
# Universidad del Quindío - Programación III - Parcial 2 (Ejercicio 2)

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

   header = ["""
    <svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}">
    """]

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

    footer = ["</svg>\n"]

    Stream.concat([header, body, footer])
    |> Enum.into(File.stream!(ruta_salida, [:write]))
  end
end

# Integrantes: Laura Sanchez, Jeison Lopez
# Universidad del Quindío - Programación III - Parcial 2 (Ejercicio 2)

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

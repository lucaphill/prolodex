"""
app.py
Interface web (Flask) para o simulador de batalha Pokemon em Prolog.

Como rodar:
    pip install flask pyswip
    python app.py
Depois abra http://localhost:5000 no navegador.

Requisitos:
    - SWI-Prolog instalado no sistema.
    - Este arquivo (e a pasta templates/) devem ficar na MESMA PASTA que
      pokemon.pl, moves.pl, aprende.pl, tipos.pl e batalha.pl.
    - batalha.pl precisa ter os predicados calcular_batalha_dados/7 e
      lista_pokemon/1 (ja incluidos no batalha.pl que te passei antes),
      e a linha ":- initialization(menu)." precisa estar comentada.
"""

from flask import Flask, request, jsonify, render_template
from pyswip import Prolog

app = Flask(__name__)

prolog = Prolog()
prolog.consult("pokemon.pl")
prolog.consult("moves.pl")
prolog.consult("aprende.pl")
prolog.consult("tipos.pl")
prolog.consult("batalha.pl")


def pokemon_existe(nome):
    if not nome:
        return False
    resultados = list(prolog.query(f"pokemon(_, {nome}, _, _, _, _, _, _, _, _)"))
    return len(resultados) > 0


def listar_pokemon():
    resultados = list(prolog.query("lista_pokemon(Nomes)"))
    if not resultados:
        return []
    return sorted(str(n) for n in resultados[0]["Nomes"])


def listar_movimentos(pokemon):
    if not pokemon:
        return []
    resultados = list(prolog.query(f"movimentos_pokemon({pokemon}, Moves)"))
    if not resultados:
        return []
    return sorted(str(m) for m in resultados[0]["Moves"])


def monta_escolha(moves):
    """moves: lista de ate 4 strings (ja normalizadas, minusculo/underscore).
    Slots vazios ou ausentes viram 'none'."""
    atomos = []
    for i in range(4):
        m = moves[i] if i < len(moves) and moves[i] else ""
        atomos.append(m if m else "none")
    return f"escolhido([{', '.join(atomos)}])"


def simular_batalha(pok_a, nivel_a, escolha_a, pok_b, nivel_b, escolha_b):
    query = (
        f"calcular_batalha_dados({pok_a}, {nivel_a}, {escolha_a}, "
        f"{pok_b}, {nivel_b}, {escolha_b}, "
        f"resultado(ProbA, ProbB, MoveA, DanoA, MoveB, DanoB, VelA, VelB))"
    )
    resultado = list(prolog.query(query))
    if not resultado:
        return None
    r = resultado[0]
    return {
        "probA": float(r["ProbA"]),
        "probB": float(r["ProbB"]),
        "moveA": str(r["MoveA"]),
        "danoA": float(r["DanoA"]),
        "moveB": str(r["MoveB"]),
        "danoB": float(r["DanoB"]),
        "velA": float(r["VelA"]),
        "velB": float(r["VelB"]),
    }


@app.route("/")
def index():
    return render_template("index.html", pokemons=listar_pokemon())


@app.route("/api/movimentos")
def api_movimentos():
    pokemon = str(request.args.get("pokemon", "")).strip().lower().replace(" ", "_")
    return jsonify({"golpes": listar_movimentos(pokemon)})


@app.route("/api/batalha", methods=["POST"])
def api_batalha():
    dados = request.json or {}
    pok_a = str(dados.get("pokA", "")).strip().lower().replace(" ", "_")
    pok_b = str(dados.get("pokB", "")).strip().lower().replace(" ", "_")

    try:
        nivel_a = int(dados.get("nivelA", 50))
        nivel_b = int(dados.get("nivelB", 50))
    except (TypeError, ValueError):
        return jsonify({"erro": "Nivel invalido."}), 400

    if not pok_a or not pok_b:
        return jsonify({"erro": "Escolha os dois pokemon."}), 400

    # Checa cada lado separadamente, pra dizer exatamente qual nome nao bateu
    # com nenhum pokemon do banco (em vez de um erro generico).
    if not pokemon_existe(pok_a):
        return jsonify({"erro": f"Pokemon '{pok_a}' nao encontrado no banco de dados."}), 400
    if not pokemon_existe(pok_b):
        return jsonify({"erro": f"Pokemon '{pok_b}' nao encontrado no banco de dados."}), 400

    def normaliza_lista(golpes):
        return [str(g).strip().lower().replace(" ", "_") for g in (golpes or [])]

    golpes_a = dados.get("golpesA")
    golpes_b = dados.get("golpesB")
    escolha_a = monta_escolha(normaliza_lista(golpes_a)) if golpes_a else "automatico"
    escolha_b = monta_escolha(normaliza_lista(golpes_b)) if golpes_b else "automatico"

    r = simular_batalha(pok_a, nivel_a, escolha_a, pok_b, nivel_b, escolha_b)
    if r is None:
        return jsonify({"erro": "Nao foi possivel calcular a batalha com os golpes escolhidos (confira se pelo menos 1 golpe causa dano)."}), 400

    return jsonify(r)


if __name__ == "__main__":
    app.run(debug=True)

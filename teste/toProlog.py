# Conversor das APIs de pokemon para prolog
import requests
import time

def to_prolog_atom(s):
    return s.lower().replace("-", "_") # converte em algo legivel pelo prolog

fatos_pokemon = []
fatos_aprende = []
moves_vistos = set()  # pra saber quais moves precisamos baixar detalhes depois

## Percorre os Pokémon da geração 5
for id in range(494, 650):
    r = requests.get(f"https://pokeapi.co/api/v2/pokemon/{id}")
    data = r.json()
    
    nome = to_prolog_atom(data["name"])
    
    # tipos
    tipos = [to_prolog_atom(t["type"]["name"]) for t in data["types"]]
    tipo1 = tipos[0]
    tipo2 = tipos[1] if len(tipos) > 1 else "none"
    
    # stats
    stats = {s["stat"]["name"]: s["base_stat"] for s in data["stats"]}
    hp, atk, de = stats["hp"], stats["attack"], stats["defense"]
    spa, spd, spe = stats["special-attack"], stats["special-defense"], stats["speed"]
    
    fatos_pokemon.append(
        f"pokemon({data['id']}, {nome}, {tipo1}, {tipo2}, {hp}, {atk}, {de}, {spa}, {spd}, {spe})."
    )
    
    # moves que esse pokemon aprende (sem duplicata)
    moves_unicos = set()
    for m in data["moves"]:
        move_nome = to_prolog_atom(m["move"]["name"])
        moves_unicos.add(move_nome)
        moves_vistos.add(move_nome)  # guarda pra baixar detalhes depois
    
    for move_nome in sorted(moves_unicos):
        fatos_aprende.append(f"aprende({nome}, {move_nome}).")
    
    time.sleep(0.1)
    print(f"Pokemon processado: {nome}")

## Baixa detalhes só dos moves que realmente apareceram
fatos_moves = []

for move_nome in sorted(moves_vistos):
    move_nome_url = move_nome.replace("_", "-")
    r = requests.get(f"https://pokeapi.co/api/v2/move/{move_nome_url}")
    
    if r.status_code != 200: 
        continue # pula se tiver algum erro
    
    m = r.json()
    tipo = to_prolog_atom(m["type"]["name"])
    categoria = to_prolog_atom(m["damage_class"]["name"]) if m["damage_class"] else "status"
    poder = m["power"] if m["power"] is not None else 0
    precisao = m["accuracy"] if m["accuracy"] is not None else 0
    pp = m["pp"] if m["pp"] is not None else 0
    
    fatos_moves.append(f"movimento({move_nome}, {tipo}, {categoria}, {poder}, {precisao}, {pp}).")
    
    time.sleep(0.1)
    print(f"Move processado: {move_nome}")

## Salva os 3 arquivos
with open("pokemon_gen5.pl", "w") as f:
    f.write("% pokemon(ID, Nome, Tipo1, Tipo2, HP, Attack, Defense, SpAtk, SpDef, Speed).\n\n")
    for fato in fatos_pokemon:
        f.write(fato + "\n")

with open("moves.pl", "w") as f:
    f.write("% movimento(Nome, Tipo, Categoria, Poder, Precisao, PP).\n\n")
    for fato in fatos_moves:
        f.write(fato + "\n")

with open("aprende.pl", "w") as f:
    f.write("% aprende(Pokemon, Movimento).\n\n")
    for fato in fatos_aprende:
        f.write(fato + "\n")

print("Concluído! 3 arquivos gerados: pokemon_gen5.pl, moves.pl, aprende.pl")
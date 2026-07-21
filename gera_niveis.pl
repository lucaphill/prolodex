% gera_niveis.pl
%
% Script auxiliar (roda 1 vez, PRECISA DE INTERNET) que busca na PokeAPI o
% NIVEL e o METODO (level-up, machine/TM, egg, tutor...) em que cada pokemon
% de Gen 5 aprende cada movimento, filtrando pela version-group
% "black-white" (Pokemon Black/White).
%
% Gera o arquivo aprende_niveis.pl com fatos:
%   aprende_nv(Pokemon, Movimento, Metodo, NivelAprendido).
% NivelAprendido = 0 quando o metodo nao for level_up (TM, ovo, tutor, etc).
%
% Reaproveita a mesma logica de conexao do toProlog.pl do repositorio.
% Depois de rodar, copie/deixe o aprende_niveis.pl na mesma pasta dos
% outros arquivos .pl (main.pl, batalha.pl, etc).

:- use_module(library(http/http_client)).
:- use_module(library(http/json)).
:- use_module(library(http/http_json)).

to_prolog_atom(Str, Atom) :-
    downcase_atom(Str, Lower),
    atomic_list_concat(Partes, '-', Lower),
    atomic_list_concat(Partes, '_', Atom).

% pega, dentre os detalhes de um movimento, o(s) metodo(s)/nivel(is) em
% que ele eh aprendido especificamente na version-group black-white
extrai_detalhes_bw(MDict, Metodo, Nivel) :-
    Detalhes = MDict.version_group_details,
    member(D, Detalhes),
    D.version_group.name == "black-white",
    MetodoNome = D.move_learn_method.name,
    to_prolog_atom(MetodoNome, Metodo),
    ( Metodo == level_up -> Nivel = D.level_learned_at ; Nivel = 0 ).

gera_fatos_niveis_pokemon(Id, NomeAtom, Fatos) :-
    format(atom(Url), 'https://pokeapi.co/api/v2/pokemon/~w', [Id]),
    http_get(Url, Data, [json_object(dict)]),
    Nome = Data.name,
    to_prolog_atom(Nome, NomeAtom),
    Moves = Data.moves,
    findall(Fato,
        ( member(MDict, Moves),
          MoveNome = MDict.move.name,
          to_prolog_atom(MoveNome, MoveAtom),
          extrai_detalhes_bw(MDict, Metodo, Nivel),
          format(atom(Fato), 'aprende_nv(~w, ~w, ~w, ~w).', [NomeAtom, MoveAtom, Metodo, Nivel])
        ),
        Fatos).

gera_niveis :-
    open('aprende_niveis.pl', write, Stream),
    format(Stream,
        '% aprende_nv(Pokemon, Movimento, Metodo, NivelAprendido).~n', []),
    format(Stream,
        '% Metodo: level_up, machine, egg, tutor... (baseado na version-group black-white).~n', []),
    format(Stream,
        '% NivelAprendido = 0 quando o metodo NAO for level_up.~n~n', []),
    forall(
        between(494, 649, Id),
        ( catch(
              ( gera_fatos_niveis_pokemon(Id, NomeAtom, Fatos),
                forall(member(F, Fatos), format(Stream, '~w~n', [F])),
                format('Processado: ~w~n', [NomeAtom])
              ),
              Erro,
              format('Falhou id ~w: ~w~n', [Id, Erro])
          ),
          sleep(0.1)
        )
    ),
    close(Stream).

:- initialization(gera_niveis).

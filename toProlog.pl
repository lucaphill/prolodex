:- use_module(library(http/http_client)).
:- use_module(library(http/json)).
:- use_module(library(http/http_json)).

% guarda os moves ja vistos, sem duplicar (equivalente ao "set" do Python)
:- dynamic visto_move/1.

registra_move(M) :-
    ( visto_move(M) -> true ; assertz(visto_move(M)) ).

% converte string pra minusculo e troca hifen por underline
to_prolog_atom(Str, Atom) :-
    downcase_atom(Str, Lower),
    atomic_list_concat(Partes, '-', Lower),
    atomic_list_concat(Partes, '_', Atom).

% converte de volta (underline pra hifen), pra montar a URL do move
to_url_atom(Atom, UrlAtom) :-
    atomic_list_concat(Partes, '_', Atom),
    atomic_list_concat(Partes, '-', UrlAtom).

% pega o valor de um stat especifico na lista de stats
pega_stat(Stats, NomeStat, Valor) :-
    member(S, Stats),
    S.stat.name == NomeStat,
    Valor = S.base_stat, !.

% busca um pokemon pelo ID, gera o fato e retorna os moves unicos dele
gera_fato_pokemon(Id, Fato, NomeAtom, MovesUnicos) :-
    format(atom(Url), 'https://pokeapi.co/api/v2/pokemon/~w', [Id]),
    http_get(Url, Data, [json_object(dict)]),

    Nome = Data.name,
    to_prolog_atom(Nome, NomeAtom),

    Tipos = Data.types,
    length(Tipos, NumTipos),
    nth0(0, Tipos, Tipo1Dict),
    Tipo1Nome = Tipo1Dict.type.name,
    to_prolog_atom(Tipo1Nome, Tipo1),

    ( NumTipos > 1
    -> nth0(1, Tipos, Tipo2Dict),
       Tipo2Nome = Tipo2Dict.type.name,
       to_prolog_atom(Tipo2Nome, Tipo2)
    ;  Tipo2 = none
    ),

    Stats = Data.stats,
    pega_stat(Stats, "hp", HP),
    pega_stat(Stats, "attack", Atk),
    pega_stat(Stats, "defense", Def),
    pega_stat(Stats, "special-attack", SpA),
    pega_stat(Stats, "special-defense", SpD),
    pega_stat(Stats, "speed", Spe),

    format(atom(Fato),
        'pokemon(~w, ~w, ~w, ~w, ~w, ~w, ~w, ~w, ~w, ~w).',
        [Id, NomeAtom, Tipo1, Tipo2, HP, Atk, Def, SpA, SpD, Spe]),

    % extrai os moves desse pokemon, sem duplicata
    Moves = Data.moves,
    findall(MoveAtom,
        ( member(MDict, Moves),
          MoveNome = MDict.move.name,
          to_prolog_atom(MoveNome, MoveAtom)
        ),
        MovesTodos),
    sort(MovesTodos, MovesUnicos),  % sort/2 remove duplicatas e ordena

    % registra cada move no conjunto global
    forall(member(M, MovesUnicos), registra_move(M)).

% busca detalhes de um move pelo nome (atom com underline)
gera_fato_move(MoveAtom, Fato) :-
    to_url_atom(MoveAtom, UrlNome),
    format(atom(Url), 'https://pokeapi.co/api/v2/move/~w', [UrlNome]),
    http_get(Url, Data, [json_object(dict)]),

    Tipo0 = Data.type.name,
    to_prolog_atom(Tipo0, Tipo),

    ( Data.damage_class == null
    -> Categoria = status
    ;  DamageClassNome = Data.damage_class.name,
       to_prolog_atom(DamageClassNome, Categoria)
    ),

    ( Data.power == null -> Poder = 0 ; Poder = Data.power ),
    ( Data.accuracy == null -> Precisao = 0 ; Precisao = Data.accuracy ),
    PP = Data.pp,

    format(atom(Fato),
        'movimento(~w, ~w, ~w, ~w, ~w, ~w).',
        [MoveAtom, Tipo, Categoria, Poder, Precisao, PP]).

% gera os 3 arquivos
gera_todos :-
    % --- 1o: pokemon.pl e aprende.pl juntos ---
    open('pokemon_gen5.pl', write, PStream),
    format(PStream, '% pokemon(ID, Nome, Tipo1, Tipo2, HP, Attack, Defense, SpAtk, SpDef, Speed).~n~n', []),

    open('aprende.pl', write, AStream),
    format(AStream, '% aprende(Pokemon, Movimento).~n~n', []),

    forall(
        between(494, 649, Id),
        ( gera_fato_pokemon(Id, Fato, NomeAtom, MovesUnicos),
          format(PStream, '~w~n', [Fato]),
          forall(
              member(M, MovesUnicos),
              format(AStream, 'aprende(~w, ~w).~n', [NomeAtom, M])
          ),
          format('Pokemon processado: ~w~n', [NomeAtom]),
          sleep(0.1)
        )
    ),
    close(PStream),
    close(AStream),

    % --- 2o: moves.pl, so com os moves realmente vistos ---
    findall(M, visto_move(M), MovesVistosList),
    sort(MovesVistosList, MovesOrdenados),

    open('moves.pl', write, MStream),
    format(MStream, '% movimento(Nome, Tipo, Categoria, Poder, Precisao, PP).~n~n', []),

    forall(
        member(MoveAtom, MovesOrdenados),
        ( ( gera_fato_move(MoveAtom, FatoMove)
          -> format(MStream, '~w~n', [FatoMove])
          ;  format('Falhou: ~w~n', [MoveAtom])
          ),
          sleep(0.1)
        )
    ),
    close(MStream).

:- initialization(gera_todos).
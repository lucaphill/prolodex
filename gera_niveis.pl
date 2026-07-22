% gera_niveis.pl
%
% Script auxiliar (roda 1 vez, PRECISA DE INTERNET) que busca na PokeAPI o
% NIVEL e o METODO (level-up, machine/TM, egg, tutor...) em que cada pokemon
% aprende cada movimento.
%
% Como o banco agora cobre TODAS as geracoes (Nacional Dex #1-#1025, ate as
% DLCs de Scarlet/Violet), nao da mais pra usar uma unica version-group fixa
% ("black-white") como antes: pokemon antigos (ex.: Gen 1) podem nao existir
% em jogos recentes, e pokemon novos (Gen 9) nao existiam em jogos antigos.
%
% Por isso, para CADA pokemon, o script:
%   1. coleta todas as version-groups em que aquele pokemon aparece;
%   2. escolhe a MAIS RECENTE delas, segundo version_group_preferida/1
%      (lista de todas as version groups, da mais nova pra mais antiga);
%   3. usa so essa version-group escolhida pra decidir metodo/nivel de
%      TODOS os golpes daquele pokemon (assim o moveset gerado fica
%      consistente, como aconteceria dentro de um unico jogo).
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

% ---------- Ordem de preferencia das version groups ----------
% Da mais recente para a mais antiga (nomes ja no formato "com underline",
% como saem de to_prolog_atom/2). Cobre todos os jogos principais ate as
% DLCs de Scarlet/Violet (Pecharunt, #1025).
version_group_preferida(scarlet_violet).
version_group_preferida(legends_arceus).
version_group_preferida(brilliant_diamond_and_shining_pearl).
version_group_preferida(sword_shield).
version_group_preferida(lets_go_pikachu_lets_go_eevee).
version_group_preferida(ultra_sun_ultra_moon).
version_group_preferida(sun_moon).
version_group_preferida(omega_ruby_alpha_sapphire).
version_group_preferida(x_y).
version_group_preferida(black_2_white_2).
version_group_preferida(black_white).
version_group_preferida(heartgold_soulsilver).
version_group_preferida(platinum).
version_group_preferida(diamond_pearl).
version_group_preferida(firered_leafgreen).
version_group_preferida(emerald).
version_group_preferida(ruby_sapphire).
version_group_preferida(crystal).
version_group_preferida(gold_silver).
version_group_preferida(yellow).
version_group_preferida(red_blue).

% Coleta (sem duplicar) todas as version groups em que o pokemon aparece,
% olhando os version_group_details de todos os seus movimentos.
version_groups_do_pokemon(Moves, VGs) :-
    findall(VG,
        ( member(MDict, Moves),
          Detalhes = MDict.version_group_details,
          member(D, Detalhes),
          VGNome = D.version_group.name,
          to_prolog_atom(VGNome, VG)
        ),
        VGsTodos),
    sort(VGsTodos, VGs).

% Escolhe a version group mais recente dentre as disponiveis, segundo
% version_group_preferida/1. Se nenhuma da lista bater (nao deveria
% acontecer, mas por seguranca), usa a primeira disponivel.
escolhe_version_group(VGsDisponiveis, Escolhido) :-
    findall(VG,
        ( version_group_preferida(VG),
          member(VG, VGsDisponiveis)
        ),
        Candidatos),
    ( Candidatos = [Escolhido|_]
    -> true
    ;  VGsDisponiveis = [Escolhido|_]
    ).

% Pega, dentre os detalhes de um movimento, o(s) metodo(s)/nivel(is) em
% que ele eh aprendido especificamente na version-group escolhida para
% aquele pokemon.
extrai_detalhes_vg(MDict, VGEscolhido, Metodo, Nivel) :-
    Detalhes = MDict.version_group_details,
    member(D, Detalhes),
    VGNome = D.version_group.name,
    to_prolog_atom(VGNome, VG),
    VG == VGEscolhido,
    MetodoNome = D.move_learn_method.name,
    to_prolog_atom(MetodoNome, Metodo),
    ( Metodo == level_up -> Nivel = D.level_learned_at ; Nivel = 0 ).

gera_fatos_niveis_pokemon(Id, NomeAtom, VGEscolhido, Fatos) :-
    format(atom(Url), 'https://pokeapi.co/api/v2/pokemon/~w', [Id]),
    http_get(Url, Data, [json_object(dict)]),
    Nome = Data.name,
    to_prolog_atom(Nome, NomeAtom),
    Moves = Data.moves,
    version_groups_do_pokemon(Moves, VGsDisponiveis),
    ( VGsDisponiveis == []
    -> VGEscolhido = nenhuma, Fatos = []
    ;  escolhe_version_group(VGsDisponiveis, VGEscolhido),
       findall(Fato,
           ( member(MDict, Moves),
             MoveNome = MDict.move.name,
             to_prolog_atom(MoveNome, MoveAtom),
             extrai_detalhes_vg(MDict, VGEscolhido, Metodo, Nivel),
             format(atom(Fato), 'aprende_nv(~w, ~w, ~w, ~w).', [NomeAtom, MoveAtom, Metodo, Nivel])
           ),
           Fatos)
    ).

gera_niveis :-
    open('aprende_niveis.pl', write, Stream),
    format(Stream,
        '% aprende_nv(Pokemon, Movimento, Metodo, NivelAprendido).~n', []),
    format(Stream,
        '% Metodo: level_up, machine, egg, tutor... (baseado na version-group~n', []),
    format(Stream,
        '% mais recente em que o pokemon aparece - ver version_group_preferida/1).~n', []),
    format(Stream,
        '% NivelAprendido = 0 quando o metodo NAO for level_up.~n~n', []),
    forall(
        between(1, 1025, Id),
        ( catch(
              ( gera_fatos_niveis_pokemon(Id, NomeAtom, VGEscolhido, Fatos),
                forall(member(F, Fatos), format(Stream, '~w~n', [F])),
                flush_output(Stream),
                format('Processado: ~w (~w) [moveset: ~w]~n', [Id, NomeAtom, VGEscolhido])
              ),
              Erro,
              format('Falhou id ~w: ~w~n', [Id, Erro])
          ),
          sleep(0.1)
        )
    ),
    close(Stream).

:- initialization(gera_niveis).
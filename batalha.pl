% batalha.pl
% Simulador de chance de vitoria entre dois pokemon, considerando:
%   - status base (Attack/Defense/SpAtk/SpDef), escalados pelo NIVEL de cada um
%   - tipagem do pokemon (STAB) e tipagem do ataque vs tipagem do oponente (efetividade)
%   - categoria do ataque (fisico usa Attack/Defense, especial usa SpAtk/SpDef)
%   - velocidade (quem ataca primeiro ganha uma pequena vantagem)
%   - nivel de cada pokemon (1 a 100, escolhido pelo usuario) tanto para os
%     status quanto (se os dados estiverem disponiveis) para decidir quais
%     golpes o pokemon realmente teria naquele nivel
%
% EV, IV e habilidades NAO sao considerados (assume-se IV=31, EV=0, natureza neutra).

:- ensure_loaded(tipos).

% Carrega os dados de nivel/metodo dos movimentos (aprende_nv/4), SE o
% arquivo ja tiver sido gerado (veja gera_niveis.pl). Se nao existir ainda,
% o programa continua funcionando normalmente, so sem o filtro por nivel.
:- ( exists_file('aprende_niveis.pl')
   -> ensure_loaded(aprende_niveis)
   ;  true
   ).

tem_dados_nivel :- current_predicate(aprende_nv/4).

% ---------- Acesso aos fatos do banco de dados ----------

pokemon_tipos(Nome, T1, T2) :-
    pokemon(_, Nome, T1, T2, _, _, _, _, _, _).

pokemon_base(Nome, HP, Atk, Def, SpA, SpD, Spe) :-
    pokemon(_, Nome, _, _, HP, Atk, Def, SpA, SpD, Spe).

% ---------- Formulas de status "reais" (aplicando o nivel) ----------
% Formula oficial dos jogos, assumindo IV = 31 e EV = 0 para todos os status.

status_real_hp(BaseHP, Nivel, HPReal) :-
    HPReal is ((2 * BaseHP + 31) * Nivel) // 100 + Nivel + 10.

status_real(Base, Nivel, StatReal) :-
    StatReal is ((2 * Base + 31) * Nivel) // 100 + 5.

% Agora recebe o Nivel como argumento (cada pokemon pode ter o seu).
pokemon_status_real(Nome, Nivel, HP, Atk, Def, SpA, SpD, Spe) :-
    pokemon_base(Nome, BaseHP, BaseAtk, BaseDef, BaseSpA, BaseSpD, BaseSpe),
    status_real_hp(BaseHP, Nivel, HP),
    status_real(BaseAtk, Nivel, Atk),
    status_real(BaseDef, Nivel, Def),
    status_real(BaseSpA, Nivel, SpA),
    status_real(BaseSpD, Nivel, SpD),
    status_real(BaseSpe, Nivel, Spe).

% ---------- Moveset "atual" de um pokemon em um dado nivel ----------
% Pega os golpes aprendidos por level-up com Nivel_do_golpe =< Nivel,
% ordena do mais recente pro mais antigo e fica so com os ultimos 4
% (igual ao jogo: um pokemon so guarda 4 golpes por vez).
% So funciona se aprende_niveis.pl ja tiver sido gerado (gera_niveis.pl).

moveset_no_nivel(Pokemon, Nivel, Moves) :-
    tem_dados_nivel,
    !,
    findall(Lvl-Move,
        ( aprende_nv(Pokemon, Move, level_up, Lvl),
          Lvl > 0,
          Lvl =< Nivel
        ),
        Pares0),
    sort(0, @>=, Pares0, ParesOrdenados),
    primeiros_n(4, ParesOrdenados, Selecionados),
    findall(M, member(_-M, Selecionados), Moves).
moveset_no_nivel(_, _, indisponivel).

primeiros_n(N, Lista, Prefixo) :-
    length(Lista, Len),
    ( Len =< N
    -> Prefixo = Lista
    ;  length(Prefixo, N),
       append(Prefixo, _, Lista)
    ).

% ---------- Escolha do melhor ataque disponivel ----------
% So considera golpes que causam dano (Poder > 0), com a formula simplificada:
%   Dano = Poder * (AtkStat / DefStat) * STAB * Efetividade * Precisao
% Obs.: no banco de dados, Precisao = 0 significa "sempre acerta"
% (era 'null' na PokeAPI, ex.: aerial_ace, aura_sphere, etc).

% Melhor golpe entre TODOS que o pokemon pode aprender (sem filtro de nivel).
melhor_ataque(Atacante, NivelAtk, Defensor, NivelDef, MelhorMove, MelhorDano) :-
    findall(Move, aprende(Atacante, Move), Moves),
    melhor_ataque_lista(Atacante, NivelAtk, Defensor, NivelDef, Moves, MelhorMove, MelhorDano).

% Melhor golpe dentre uma lista especifica de movimentos (escolhidos pelo
% usuario, ou o moveset filtrado por nivel). Entradas 'none' sao ignoradas.
melhor_ataque_lista(Atacante, NivelAtk, Defensor, NivelDef, Moves, MelhorMove, MelhorDano) :-
    pokemon_tipos(Atacante, ATipo1, ATipo2),
    pokemon_status_real(Atacante, NivelAtk, _, RAtk, _, RSpA, _, _),
    pokemon_tipos(Defensor, DTipo1, DTipo2),
    pokemon_status_real(Defensor, NivelDef, _, _, RDef, _, RSpD, _),
    findall(Dano-Move,
        ( member(Move, Moves),
          Move \== none,
          movimento(Move, TipoMove, Categoria, Poder, Precisao, _PP),
          Poder > 0,
          categoria_stats(Categoria, RAtk, RSpA, RDef, RSpD, AtkStat, DefStat),
          multiplicador_total(TipoMove, DTipo1, DTipo2, Efetividade),
          stab(TipoMove, ATipo1, ATipo2, Stab),
          precisao_fracao(Precisao, PrecFrac),
          Dano is Poder * (AtkStat / DefStat) * Stab * Efetividade * PrecFrac
        ),
        Lista),
    ( Lista == []
    -> MelhorMove = nenhum, MelhorDano = 0
    ;  max_member(MelhorDano-MelhorMove, Lista)
    ).

% Decide quais golpes considerar, dependendo da "Escolha":
%   automatico       -> se houver dados de nivel, usa so o moveset real
%                        daquele nivel (ultimos 4 golpes de level-up);
%                        senao, usa TODOS os golpes que o pokemon aprende.
%   escolhido(Moves) -> usa exatamente os golpes informados pelo usuario.
melhor_ataque_geral(Atacante, NivelAtk, Defensor, NivelDef, automatico, Move, Dano) :-
    !,
    moveset_no_nivel(Atacante, NivelAtk, Moves),
    ( Moves == indisponivel
    -> melhor_ataque(Atacante, NivelAtk, Defensor, NivelDef, Move, Dano)
    ;  Moves == []
    -> melhor_ataque(Atacante, NivelAtk, Defensor, NivelDef, Move, Dano)
    ;  melhor_ataque_lista(Atacante, NivelAtk, Defensor, NivelDef, Moves, Move, Dano)
    ).
melhor_ataque_geral(Atacante, NivelAtk, Defensor, NivelDef, escolhido(Moves), Move, Dano) :-
    melhor_ataque_lista(Atacante, NivelAtk, Defensor, NivelDef, Moves, Move, Dano).

categoria_stats(physical, RAtk, _, RDef, _, RAtk, RDef).
categoria_stats(special, _, RSpA, _, RSpD, RSpA, RSpD).

stab(TipoMove, Tipo1, Tipo2, 1.5) :- (TipoMove == Tipo1 ; TipoMove == Tipo2), !.
stab(_, _, _, 1.0).

precisao_fracao(0, 1.0) :- !.
precisao_fracao(P, Frac) :- Frac is P / 100.

% Vantagem de velocidade: quem for mais rapido ataca primeiro, o que da uma
% pequena vantagem extra no calculo (+10% no "score" ofensivo).
bonus_velocidade(VelA, VelB, 1.1, 1.0) :- VelA > VelB, !.
bonus_velocidade(VelA, VelB, 1.0, 1.1) :- VelB > VelA, !.
bonus_velocidade(_, _, 1.0, 1.0).

% ---------- Descricao do moveset usado (so para exibir ao usuario) ----------

descrever_moveset(_Pokemon, _Nivel, escolhido(Moves), Texto) :-
    !,
    exclude(==(none), Moves, MovesValidos),
    ( MovesValidos == []
    -> Texto = 'nenhum movimento valido informado'
    ;  atomic_list_concat(MovesValidos, ', ', Texto)
    ).
descrever_moveset(Pokemon, Nivel, automatico, Texto) :-
    ( tem_dados_nivel
    -> moveset_no_nivel(Pokemon, Nivel, Moves),
       ( Moves == []
       -> Texto = 'nenhum golpe de nivel encontrado ate esse nivel (usando o moveset completo)'
       ;  atomic_list_concat(Moves, ', ', Texto)
       )
    ;  Texto = 'dados de nivel indisponiveis - considerando TODOS os golpes que o pokemon pode aprender'
    ).

% ---------- Calculo da probabilidade de vitoria ----------
%
% Para cada pokemon calculamos uma "taxa de dano por turno" relativa ao HP
% real do oponente (ou seja, aproximadamente 1/numero de turnos para nocautear).
% A chance de vitoria eh a proporcao entre essas taxas (com o bonus de
% velocidade aplicado), transformada em porcentagem.

calcular_batalha(PokA, NivelA, EscolhaA, PokB, NivelB, EscolhaB) :-
    ( \+ pokemon(_, PokA, _, _, _, _, _, _, _, _)
    -> format('Pokemon nao encontrado: ~w~n', [PokA]), fail
    ;  true
    ),
    ( \+ pokemon(_, PokB, _, _, _, _, _, _, _, _)
    -> format('Pokemon nao encontrado: ~w~n', [PokB]), fail
    ;  true
    ),

    melhor_ataque_geral(PokA, NivelA, PokB, NivelB, EscolhaA, MoveA, DanoA),
    melhor_ataque_geral(PokB, NivelB, PokA, NivelA, EscolhaB, MoveB, DanoB),

    pokemon_status_real(PokA, NivelA, HPA, _, _, _, _, VelA),
    pokemon_status_real(PokB, NivelB, HPB, _, _, _, _, VelB),

    ( HPB > 0 -> TaxaA is DanoA / HPB ; TaxaA = 0 ),
    ( HPA > 0 -> TaxaB is DanoB / HPA ; TaxaB = 0 ),

    bonus_velocidade(VelA, VelB, BonusA, BonusB),

    ScoreA is TaxaA * BonusA,
    ScoreB is TaxaB * BonusB,
    Total is ScoreA + ScoreB,

    ( Total =< 0
    -> ProbA = 50.0, ProbB = 50.0
    ;  ProbA is (ScoreA / Total) * 100,
       ProbB is (ScoreB / Total) * 100
    ),

    rotulo_origem(EscolhaA, RotuloA),
    rotulo_origem(EscolhaB, RotuloB),
    descrever_moveset(PokA, NivelA, EscolhaA, DescA),
    descrever_moveset(PokB, NivelB, EscolhaB, DescB),

    format('~n=== ~w (nivel ~w) vs ~w (nivel ~w) ===~n', [PokA, NivelA, PokB, NivelB]),
    format('Golpes considerados de ~w: ~w~n', [PokA, DescA]),
    format('Golpes considerados de ~w: ~w~n', [PokB, DescB]),
    format('~w de ~w: ~w  (dano estimado: ~2f)~n', [RotuloA, PokA, MoveA, DanoA]),
    format('~w de ~w: ~w  (dano estimado: ~2f)~n', [RotuloB, PokB, MoveB, DanoB]),
    ( VelA > VelB -> format('~w e mais rapido e ataca primeiro.~n', [PokA])
    ; VelB > VelA -> format('~w e mais rapido e ataca primeiro.~n', [PokB])
    ; format('Os dois pokemon tem a mesma velocidade.~n', [])
    ),
    format('Chance de vitoria: ~w ~1f% / ~w ~1f%~n~n', [PokA, ProbA, PokB, ProbB]).

rotulo_origem(automatico, 'Melhor ataque (escolha automatica)').
rotulo_origem(escolhido(_), 'Melhor entre os movimentos informados').

% Atalhos para uso direto na consulta (sem passar pelo menu), sempre nivel 50:
%   batalha(emboar, petilil).
%   batalha(emboar, [flare_blitz,none,none,none], petilil, automatico).
% Ou com nivel explicito por pokemon:
%   batalha(emboar, 45, automatico, petilil, 50, [giga_drain,none,none,none]).
batalha(PokA, PokB) :-
    calcular_batalha(PokA, 50, automatico, PokB, 50, automatico).

batalha(PokA, MovesA, PokB, MovesB) :-
    ( MovesA == automatico -> EscolhaA = automatico ; EscolhaA = escolhido(MovesA) ),
    ( MovesB == automatico -> EscolhaB = automatico ; EscolhaB = escolhido(MovesB) ),
    calcular_batalha(PokA, 50, EscolhaA, PokB, 50, EscolhaB).

batalha(PokA, NivelA, MovesA, PokB, NivelB, MovesB) :-
    ( MovesA == automatico -> EscolhaA = automatico ; EscolhaA = escolhido(MovesA) ),
    ( MovesB == automatico -> EscolhaB = automatico ; EscolhaB = escolhido(MovesB) ),
    calcular_batalha(PokA, NivelA, EscolhaA, PokB, NivelB, EscolhaB).

% ---------- Menu interativo ----------

menu :-
    nl,
    write('=========================================='), nl,
    write('   SIMULADOR DE BATALHA POKEMON (Gen 5)'), nl,
    write('=========================================='), nl,
    ( tem_dados_nivel
    -> true
    ;  nl,
       write('(aviso: aprende_niveis.pl nao encontrado - a escolha automatica de'), nl,
       write(' golpes vai considerar TODOS os golpes que o pokemon aprende, sem'), nl,
       write(' filtrar por nivel. Rode gera_niveis.pl para habilitar o filtro.)'), nl
    ),
    nl,
    ler_nome('Digite o nome do primeiro Pokemon: ', PokA),
    ler_nivel(PokA, NivelA),
    escolher_movimentos(PokA, EscolhaA),
    nl,
    ler_nome('Digite o nome do segundo Pokemon: ', PokB),
    ler_nivel(PokB, NivelB),
    escolher_movimentos(PokB, EscolhaB),
    ( calcular_batalha(PokA, NivelA, EscolhaA, PokB, NivelB, EscolhaB)
    -> true
    ;  format('Nao foi possivel calcular essa batalha.~n', [])
    ),
    perguntar_continuar.

% Le uma linha do teclado e normaliza (minusculo, espacos viram underscore)
% para bater com o formato dos atomos usados no banco de dados
% (ex.: "Basculin Red Striped" -> basculin_red_striped).
ler_nome(Prompt, NomeAtom) :-
    write(Prompt),
    flush_output(user_output),
    read_line_to_string(user_input, Str),
    normalize_space(atom(Trim), Str),
    downcase_atom(Trim, Lower),
    atomic_list_concat(Partes, ' ', Lower),
    atomic_list_concat(Partes, '_', NomeAtom).

% Le o nivel (1 a 100) de um pokemon. Se digitar algo invalido, usa 50.
ler_nivel(Pokemon, Nivel) :-
    format('Nivel de ~w (1-100): ', [Pokemon]),
    flush_output(user_output),
    read_line_to_string(user_input, Str),
    ( number_string(N, Str), integer(N), N >= 1, N =< 100
    -> Nivel = N
    ;  format('  Nivel invalido, usando 50 como padrao.~n', []),
       Nivel = 50
    ).

% Pergunta se o usuario quer informar os movimentos do pokemon (ex.: um
% moveset especifico de uma batalha do jogo, tipo o Metro de Unova) ou se
% prefere deixar o sistema escolher automaticamente o melhor golpe
% disponivel (considerando o nivel informado, se os dados existirem).
escolher_movimentos(Pokemon, Escolha) :-
    format('Voce sabe/quer escolher os 4 movimentos de ~w? (s/n): ', [Pokemon]),
    flush_output(user_output),
    read_line_to_string(user_input, Resp),
    string_lower(Resp, RespLower),
    ( sub_string(RespLower, 0, 1, _, "s")
    -> ler_quatro_movimentos(Pokemon, Moves),
       Escolha = escolhido(Moves)
    ;  Escolha = automatico
    ).

ler_quatro_movimentos(Pokemon, [M1, M2, M3, M4]) :-
    format('Digite os movimentos de ~w (digite "none" se nao quiser usar aquele slot):~n', [Pokemon]),
    ler_um_movimento(1, M1),
    ler_um_movimento(2, M2),
    ler_um_movimento(3, M3),
    ler_um_movimento(4, M4).

ler_um_movimento(N, MoveAtom) :-
    format('  Movimento ~w (nome com espaco ou underline, ex.: flare blitz): ', [N]),
    flush_output(user_output),
    read_line_to_string(user_input, Str),
    normalize_space(atom(Trim), Str),
    downcase_atom(Trim, Lower),
    atomic_list_concat(Partes, ' ', Lower),
    atomic_list_concat(Partes, '_', MoveBruto),
    ( (MoveBruto == none ; MoveBruto == nenhum ; MoveBruto == '')
    -> MoveAtom = none
    ;  ( movimento(MoveBruto, _, _, _, _, _)
       -> MoveAtom = MoveBruto
       ;  format('    (obs.: movimento "~w" nao encontrado no banco de dados, sera ignorado)~n', [MoveBruto]),
          MoveAtom = none
       )
    ).

perguntar_continuar :-
    nl,
    write('Deseja simular outra batalha? (s/n): '),
    flush_output(user_output),
    read_line_to_string(user_input, Resp),
    string_lower(Resp, RespLower),
    ( sub_string(RespLower, 0, 1, _, "s")
    -> menu
    ;  write('Ate a proxima, treinador!'), nl
    ).

:- initialization(menu).
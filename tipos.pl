% tipos.pl
% efetividade(TipoAtaque, TipoDefesa, Multiplicador).
% Tabela de tipos moderna (Gen 6+, ja incluindo Fairy, que eh o que o
% banco de dados de gen5.pl usa em alguns pokemon como cottonee/whimsicott).
% So estao listadas as excecoes (multiplicador diferente de 1).
% Se o par (Ataque, Defesa) nao estiver aqui, o multiplicador eh neutro (1).

efetividade(normal, rock, 0.5).
efetividade(normal, ghost, 0).
efetividade(normal, steel, 0.5).

efetividade(fire, fire, 0.5).
efetividade(fire, water, 0.5).
efetividade(fire, grass, 2).
efetividade(fire, ice, 2).
efetividade(fire, bug, 2).
efetividade(fire, rock, 0.5).
efetividade(fire, dragon, 0.5).
efetividade(fire, steel, 2).

efetividade(water, fire, 2).
efetividade(water, water, 0.5).
efetividade(water, grass, 0.5).
efetividade(water, ground, 2).
efetividade(water, rock, 2).
efetividade(water, dragon, 0.5).

efetividade(electric, water, 2).
efetividade(electric, electric, 0.5).
efetividade(electric, grass, 0.5).
efetividade(electric, ground, 0).
efetividade(electric, flying, 2).
efetividade(electric, dragon, 0.5).

efetividade(grass, fire, 0.5).
efetividade(grass, water, 2).
efetividade(grass, grass, 0.5).
efetividade(grass, poison, 0.5).
efetividade(grass, ground, 2).
efetividade(grass, flying, 0.5).
efetividade(grass, bug, 0.5).
efetividade(grass, rock, 2).
efetividade(grass, dragon, 0.5).
efetividade(grass, steel, 0.5).

efetividade(ice, fire, 0.5).
efetividade(ice, water, 0.5).
efetividade(ice, grass, 2).
efetividade(ice, ice, 0.5).
efetividade(ice, ground, 2).
efetividade(ice, flying, 2).
efetividade(ice, dragon, 2).
efetividade(ice, steel, 0.5).

efetividade(fighting, normal, 2).
efetividade(fighting, ice, 2).
efetividade(fighting, poison, 0.5).
efetividade(fighting, flying, 0.5).
efetividade(fighting, psychic, 0.5).
efetividade(fighting, bug, 0.5).
efetividade(fighting, rock, 2).
efetividade(fighting, ghost, 0).
efetividade(fighting, dark, 2).
efetividade(fighting, steel, 2).
efetividade(fighting, fairy, 0.5).

efetividade(poison, grass, 2).
efetividade(poison, poison, 0.5).
efetividade(poison, ground, 0.5).
efetividade(poison, rock, 0.5).
efetividade(poison, ghost, 0.5).
efetividade(poison, steel, 0).
efetividade(poison, fairy, 2).

efetividade(ground, fire, 2).
efetividade(ground, electric, 2).
efetividade(ground, grass, 0.5).
efetividade(ground, poison, 2).
efetividade(ground, flying, 0).
efetividade(ground, bug, 0.5).
efetividade(ground, rock, 2).
efetividade(ground, steel, 2).

efetividade(flying, electric, 0.5).
efetividade(flying, grass, 2).
efetividade(flying, fighting, 2).
efetividade(flying, bug, 2).
efetividade(flying, rock, 0.5).
efetividade(flying, steel, 0.5).

efetividade(psychic, fighting, 2).
efetividade(psychic, poison, 2).
efetividade(psychic, psychic, 0.5).
efetividade(psychic, dark, 0).
efetividade(psychic, steel, 0.5).

efetividade(bug, fire, 0.5).
efetividade(bug, grass, 2).
efetividade(bug, fighting, 0.5).
efetividade(bug, poison, 0.5).
efetividade(bug, flying, 0.5).
efetividade(bug, psychic, 2).
efetividade(bug, ghost, 0.5).
efetividade(bug, dark, 2).
efetividade(bug, steel, 0.5).
efetividade(bug, fairy, 0.5).

efetividade(rock, fire, 2).
efetividade(rock, ice, 2).
efetividade(rock, fighting, 0.5).
efetividade(rock, ground, 0.5).
efetividade(rock, flying, 2).
efetividade(rock, bug, 2).
efetividade(rock, steel, 0.5).

efetividade(ghost, normal, 0).
efetividade(ghost, psychic, 2).
efetividade(ghost, ghost, 2).
efetividade(ghost, dark, 0.5).

efetividade(dragon, dragon, 2).
efetividade(dragon, steel, 0.5).
efetividade(dragon, fairy, 0).

efetividade(dark, fighting, 0.5).
efetividade(dark, psychic, 2).
efetividade(dark, ghost, 2).
efetividade(dark, dark, 0.5).
efetividade(dark, fairy, 0.5).

efetividade(steel, fire, 0.5).
efetividade(steel, water, 0.5).
efetividade(steel, electric, 0.5).
efetividade(steel, ice, 2).
efetividade(steel, rock, 2).
efetividade(steel, steel, 0.5).
efetividade(steel, fairy, 2).

efetividade(fairy, fire, 0.5).
efetividade(fairy, fighting, 2).
efetividade(fairy, poison, 0.5).
efetividade(fairy, dragon, 2).
efetividade(fairy, dark, 2).
efetividade(fairy, steel, 0.5).

% multiplicador_tipo/3: retorna 1 (neutro) se nao houver excecao cadastrada.
multiplicador_tipo(TipoAtq, TipoDef, Mult) :-
    efetividade(TipoAtq, TipoDef, Mult), !.
multiplicador_tipo(_, _, 1).

% multiplicador_total/4: combina os dois tipos do defensor (Tipo2 pode ser 'none').
multiplicador_total(TipoAtq, TipoDef1, none, Mult) :-
    !,
    multiplicador_tipo(TipoAtq, TipoDef1, Mult).
multiplicador_total(TipoAtq, TipoDef1, TipoDef2, Mult) :-
    multiplicador_tipo(TipoAtq, TipoDef1, M1),
    multiplicador_tipo(TipoAtq, TipoDef2, M2),
    Mult is M1 * M2.
